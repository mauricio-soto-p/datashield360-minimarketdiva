/* =====================================================================
   SCRIPT 02 : Carga del histórico simulado 2024-01-01 a 2026-10-31
   ---------------------------------------------------------------------
   Fuente  : carpeta 05_datos\oltp del entregable (CSV UTF-8, generados por
             05_datos\generador\generar_datos.py con semilla fija 2026).
   Volumen : +31 productos, +588 clientes, +75,028 ventas,
             +150,777 líneas de venta, +354 pedidos, +1,054 líneas de pedido
   Los ID continúan después de los datos originales del grupo
   (KEEPIDENTITY), por eso deben ejecutarse antes 00c y 01.
   Ajuste @Ruta (terminada en '\'); el servicio de SQL Server debe poder
   leer esa carpeta (p. ej. C:\DataShield360\05_datos\oltp\).
   BULK INSERT no dispara triggers por defecto: la carga histórica no
   llena la bitácora de auditoría.
   ===================================================================== */
USE MinimarketDiva;
GO

DECLARE @Ruta NVARCHAR(260) = N'C:\DataShield360\05_datos\oltp\';     -- <<< AJUSTAR
DECLARE @sql NVARCHAR(MAX), @tabla SYSNAME, @archivo NVARCHAR(100), @filas INT, @t0 DATETIME2 = SYSDATETIME();

-- Orden según dependencias de claves foráneas (padres antes que hijos)
DECLARE @cargas TABLE (orden INT, tabla SYSNAME, archivo NVARCHAR(100));
INSERT INTO @cargas VALUES
 (1, N'dbo.Producto',      N'producto_nuevos.csv'),
 (2, N'dbo.Inventario',    N'inventario_nuevos.csv'),
 (3, N'dbo.Cliente',       N'cliente_nuevos.csv'),
 (4, N'dbo.Pedido',        N'pedido_historico.csv'),
 (5, N'dbo.DetallePedido', N'detallepedido_historico.csv'),
 (6, N'dbo.Venta',         N'venta_historico.csv'),
 (7, N'dbo.DetalleVenta',  N'detalleventa_historico.csv');

BEGIN TRY
    BEGIN TRANSACTION;          -- carga atómica: entra todo o no entra nada

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT tabla, archivo FROM @cargas ORDER BY orden;
    OPEN cur;
    FETCH NEXT FROM cur INTO @tabla, @archivo;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- La ruta no puede ir como variable en BULK INSERT: se arma SQL dinámico
        SET @sql = N'BULK INSERT ' + @tabla + N' FROM ''' + @Ruta + @archivo + N''' WITH ('
                 + N'FORMAT = ''CSV'', FIRSTROW = 2, CODEPAGE = ''65001'', FIELDTERMINATOR = '','', '
                 + N'KEEPIDENTITY, TABLOCK, CHECK_CONSTRAINTS); SET @n = @@ROWCOUNT;';  -- respeta los CHECK
        EXEC sys.sp_executesql @sql, N'@n INT OUTPUT', @n = @filas OUTPUT;
        PRINT CONCAT(@tabla, ' <- ', @archivo, ': ', @filas, ' filas');
        FETCH NEXT FROM cur INTO @tabla, @archivo;
    END
    CLOSE cur; DEALLOCATE cur;

    COMMIT TRANSACTION;
    PRINT CONCAT('Carga confirmada en ', DATEDIFF(MILLISECOND, @t0, SYSDATETIME()), ' ms.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;       -- deshace la carga parcial
    PRINT CONCAT('ERROR en ', @tabla, ': ', ERROR_MESSAGE());
    THROW;
END CATCH;
GO

/* ---------- Verificación de volúmenes (evidencia E-01) ---------- */
SELECT 'Categoria' AS tabla, COUNT(*) AS filas FROM dbo.Categoria UNION ALL
SELECT 'Producto', COUNT(*) FROM dbo.Producto UNION ALL
SELECT 'Inventario', COUNT(*) FROM dbo.Inventario UNION ALL
SELECT 'Cliente', COUNT(*) FROM dbo.Cliente UNION ALL
SELECT 'Empleado', COUNT(*) FROM dbo.Empleado UNION ALL
SELECT 'MetodoPago', COUNT(*) FROM dbo.MetodoPago UNION ALL
SELECT 'Proveedor', COUNT(*) FROM dbo.Proveedor UNION ALL
SELECT 'Pedido', COUNT(*) FROM dbo.Pedido UNION ALL
SELECT 'DetallePedido', COUNT(*) FROM dbo.DetallePedido UNION ALL
SELECT 'Venta', COUNT(*) FROM dbo.Venta UNION ALL
SELECT 'DetalleVenta', COUNT(*) FROM dbo.DetalleVenta;
-- Esperado: 9 / 45 / 45 / 600 / 6 / 5 / 8 / 364 / 1086 / 75043 / 150816
GO

/* ---------- Perfilado de calidad del dato original (evidencia E-02) ----------
   Hallazgo: en los datos originales del curso Base de Datos el campo
   monto_venta se digitó a mano y no siempre coincide con la suma del detalle. */
SELECT v.id_venta, v.monto_venta AS monto_registrado,
       SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta) AS monto_segun_detalle,
       v.monto_venta - SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta) AS diferencia
FROM dbo.Venta v
JOIN dbo.DetalleVenta d ON d.id_venta = v.id_venta
GROUP BY v.id_venta, v.monto_venta
HAVING v.monto_venta <> SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta)
ORDER BY v.id_venta;
-- Esperado: 9 ventas (1, 4, 6, 7, 9, 10, 11, 12, 15) -> se corrigen con dbo.usp_RecalcularMontosVenta (script 03)
GO
