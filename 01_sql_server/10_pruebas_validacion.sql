/* =====================================================================
   SCRIPT 10 : Casos de prueba automatizados T-01 a T-14 (tabla 5.4)
   ---------------------------------------------------------------------
   Cada prueba compara el resultado ESPERADO con el OBTENIDO y lo guarda
   en qa.ResultadoPrueba (PASA / FALLA). Al final se lista el resumen:
   esa consulta es la evidencia E-10 para el informe.
   Orden de ejecución sugerido: 01-08, luego este script, luego el 09.
   ===================================================================== */
USE MinimarketDiva;
GO
IF SCHEMA_ID(N'qa') IS NULL EXEC (N'CREATE SCHEMA qa');
GO
DROP TABLE IF EXISTS qa.ResultadoPrueba;
CREATE TABLE qa.ResultadoPrueba (
    id_prueba VARCHAR(5) PRIMARY KEY, requisito VARCHAR(10), descripcion NVARCHAR(150),
    esperado NVARCHAR(150), obtenido NVARCHAR(150), estado AS (CASE WHEN esperado = obtenido THEN 'PASA' ELSE 'FALLA' END),
    fecha DATETIME2(0) DEFAULT (SYSDATETIME()), usuario SYSNAME DEFAULT (SUSER_SNAME()));
GO
CREATE OR ALTER PROCEDURE qa.usp_Registrar @id VARCHAR(5), @req VARCHAR(10), @desc NVARCHAR(150), @esp NVARCHAR(150), @obt NVARCHAR(150)
AS INSERT INTO qa.ResultadoPrueba (id_prueba, requisito, descripcion, esperado, obtenido) VALUES (@id, @req, @desc, @esp, ISNULL(@obt, N'NULL'));
GO

/* T-01 RF-01: venta válida -> se crea la venta, baja el stock y se registra el kardex */
DECLARE @det dbo.TipoDetalleVenta, @id INT, @s0 INT, @s1 INT;
SELECT @s0 = stock_actual_inventario FROM dbo.Inventario WHERE id_producto = 1;
INSERT INTO @det VALUES (1, 6), (13, 1);                         -- 6 Cristal + 1 bolsa de hielo
EXEC dbo.usp_RegistrarVenta @id_cliente = 25, @id_metodoPago = 3, @id_empleado = 2, @detalle = @det, @id_venta = @id OUTPUT;
SELECT @s1 = stock_actual_inventario FROM dbo.Inventario WHERE id_producto = 1;
DECLARE @obt NVARCHAR(150) = CONCAT('monto=', (SELECT monto_venta FROM dbo.Venta WHERE id_venta = @id),
        ';stock=-', @s0 - @s1, ';kardex=', (SELECT COUNT(*) FROM dbo.MovimientoInventario WHERE referencia = CONCAT('VENTA ', @id)));
EXEC qa.usp_Registrar 'T-01', 'RF-01', N'Registrar venta válida con usp_RegistrarVenta', N'monto=58.00;stock=-6;kardex=2', @obt;
GO

/* T-02 RF-01: stock insuficiente -> error 50006 y ROLLBACK (no queda venta) */
DECLARE @det dbo.TipoDetalleVenta, @id INT, @n0 INT = (SELECT COUNT(*) FROM dbo.Venta), @err INT;
INSERT INTO @det VALUES (8, 9999);
BEGIN TRY EXEC dbo.usp_RegistrarVenta 25, 1, 2, @det, @id OUTPUT; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
DECLARE @obt NVARCHAR(150) = CONCAT('error=', @err, ';ventas_nuevas=', (SELECT COUNT(*) FROM dbo.Venta) - @n0);
EXEC qa.usp_Registrar 'T-02', 'RF-01', N'Venta con stock insuficiente se revierte', N'error=50006;ventas_nuevas=0', @obt;
GO

/* T-03 RF-02: ley seca -> la función detecta el periodo restringido */
DECLARE @obt NVARCHAR(150) = CONCAT(dbo.fn_EsVentaRestringida('2026-04-12T15:00:00'), '/', dbo.fn_EsVentaRestringida('2026-04-14T15:00:00'));
EXEC qa.usp_Registrar 'T-03', 'RF-02', N'Detección de ley seca (12-abr sí / 14-abr no)', N'1/0', @obt;
GO

/* T-04 RF-03: el trigger genera alerta cuando el stock cae bajo el mínimo */
DECLARE @det dbo.TipoDetalleVenta, @id INT;
INSERT INTO @det VALUES (12, 8);                                  -- Champán: stock 10, mínimo 3 -> queda 2
EXEC dbo.usp_RegistrarVenta 40, 2, 3, @det, @id OUTPUT;
DECLARE @obt NVARCHAR(150) = CONCAT('alertas_pendientes=', (SELECT COUNT(*) FROM dbo.AlertaStock WHERE id_producto = 12 AND estado_alerta = 'PENDIENTE'));
EXEC qa.usp_Registrar 'T-04', 'RF-03', N'Alerta automática de reposición (trigger)', N'alertas_pendientes=1', @obt;
GO

/* T-05 RF-03: el pedido al proveedor repone stock y cierra la alerta */
DECLARE @dp dbo.TipoDetallePedido, @id INT;
INSERT INTO @dp VALUES (12, 15, 60.00);
EXEC dbo.usp_RegistrarPedido @id_proveedor = 3, @detalle = @dp, @id_pedido = @id OUTPUT;
DECLARE @obt NVARCHAR(150) = CONCAT('stock=', (SELECT stock_actual_inventario FROM dbo.Inventario WHERE id_producto = 12),
        ';pendientes=', (SELECT COUNT(*) FROM dbo.AlertaStock WHERE id_producto = 12 AND estado_alerta = 'PENDIENTE'));
EXEC qa.usp_Registrar 'T-05', 'RF-03', N'Pedido repone stock y atiende alerta', N'stock=17;pendientes=0', @obt;
GO

/* T-06 RF-04: anular venta -> estado ANULADA y stock repuesto (SAVEPOINT) */
DECLARE @v INT = (SELECT MAX(id_venta) FROM dbo.Venta WHERE id_cliente = 25 AND estado_venta = 'REGISTRADA');
DECLARE @s0 INT = (SELECT stock_actual_inventario FROM dbo.Inventario WHERE id_producto = 1);
EXEC dbo.usp_AnularVenta @id_venta = @v, @motivo = N'Prueba T-06: cliente devolvió el pedido';
DECLARE @obt NVARCHAR(150) = CONCAT((SELECT estado_venta FROM dbo.Venta WHERE id_venta = @v), ';stock=+',
        (SELECT stock_actual_inventario FROM dbo.Inventario WHERE id_producto = 1) - @s0);
EXEC qa.usp_Registrar 'T-06', 'RF-04', N'Anulación de venta con reposición de stock', N'ANULADA;stock=+6', @obt;
GO

/* T-07 RF-05: DELETE de una venta queda bloqueado y auditado */
DELETE FROM dbo.Venta WHERE id_venta = 100;
DECLARE @obt NVARCHAR(150) = CONCAT('existe=', (SELECT COUNT(*) FROM dbo.Venta WHERE id_venta = 100), ';auditado=',
        (SELECT COUNT(*) FROM auditoria.RegistroAuditoria WHERE tabla = N'dbo.Venta' AND operacion = 'DELETE' AND clave_registro = '100'));
EXEC qa.usp_Registrar 'T-07', 'RF-05', N'Borrado físico de venta bloqueado (INSTEAD OF)', N'existe=1;auditado=1', @obt;
GO

/* T-08 RF-06: corrección automática de montos mal digitados (cursor) */
DECLARE @r TABLE (corregidas INT, errores INT);
INSERT INTO @r EXEC dbo.usp_RecalcularMontosVenta;
DECLARE @obt NVARCHAR(150) = (SELECT CONCAT('corregidas=', corregidas, ';errores=', errores) FROM @r);
EXEC qa.usp_Registrar 'T-08', 'RF-06', N'Recalcular montos inconsistentes (9 originales)', N'corregidas=9;errores=0', @obt;
GO

/* T-09 RF-07: auditoría de cliente guarda antes/después en JSON */
UPDATE dbo.Cliente SET celular_cliente = '911222333' WHERE id_cliente = 10;
DECLARE @obt NVARCHAR(150) = (SELECT TOP (1) CONCAT(JSON_VALUE(datos_anteriores, '$.celular_cliente'), '->', JSON_VALUE(datos_nuevos, '$.celular_cliente'))
                              FROM auditoria.RegistroAuditoria WHERE tabla = N'dbo.Cliente' AND clave_registro = '10' ORDER BY id_auditoria DESC);
EXEC qa.usp_Registrar 'T-09', 'RF-07', N'Trigger de auditoría en Cliente (JSON)', N'978765432->911222333', @obt;
GO

/* T-10 RNF-04: el cajero NO puede modificar el inventario directamente */
DECLARE @err INT;
EXECUTE AS USER = 'us_cajero';
BEGIN TRY UPDATE dbo.Inventario SET stock_actual_inventario = 999 WHERE id_producto = 1; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
REVERT;
DECLARE @obt NVARCHAR(150) = CONCAT('error=', @err);
EXEC qa.usp_Registrar 'T-10', 'RNF-04', N'Cajero sin UPDATE directo (permiso denegado)', N'error=229', @obt;
GO

/* T-11 RNF-04: el cajero SÍ registra ventas a través del procedimiento */
DECLARE @det dbo.TipoDetalleVenta, @id INT;
INSERT INTO @det VALUES (9, 1);
EXECUTE AS USER = 'us_cajero';
EXEC dbo.usp_RegistrarVenta 13, 1, 4, @det, @id OUTPUT;
REVERT;
DECLARE @obt NVARCHAR(150) = CASE WHEN @id IS NOT NULL THEN 'venta_creada' ELSE 'sin_venta' END;
EXEC qa.usp_Registrar 'T-11', 'RNF-04', N'Cajero vende solo mediante usp_RegistrarVenta', N'venta_creada', @obt;
GO

/* T-12 RNF-05: el analista no puede leer datos personales de Cliente */
DECLARE @err INT;
EXECUTE AS USER = 'us_analista';
BEGIN TRY DECLARE @x INT = (SELECT COUNT(*) FROM dbo.Cliente); END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
REVERT;
DECLARE @obt NVARCHAR(150) = CONCAT('error=', @err);
EXEC qa.usp_Registrar 'T-12', 'RNF-05', N'Analista sin acceso a Cliente', N'error=229', @obt;
GO

/* T-13 RNF-05: enmascaramiento dinámico del celular */
CREATE USER us_demo_mascara WITHOUT LOGIN;
GRANT SELECT ON dbo.Cliente TO us_demo_mascara;
DECLARE @cel VARCHAR(9);
EXECUTE AS USER = 'us_demo_mascara';
SELECT @cel = celular_cliente FROM dbo.Cliente WHERE id_cliente = 1;
REVERT;
DROP USER us_demo_mascara;
EXEC qa.usp_Registrar 'T-13', 'RNF-05', N'Dynamic Data Masking del celular', N'XXXXXX321', @cel;
GO

/* T-14 RNF-02: reconciliación OLTP = DW después de la carga incremental */
EXEC MinimarketDiva_DW.etl.usp_EjecutarETL;
DECLARE @oltp DECIMAL(14,2) = (SELECT SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta) FROM dbo.DetalleVenta d
                               JOIN dbo.Venta v ON v.id_venta = d.id_venta WHERE v.estado_venta = 'REGISTRADA');
DECLARE @dw DECIMAL(14,2) = (SELECT SUM(Importe) FROM MinimarketDiva_DW.dw.FactVentas);
DECLARE @obt NVARCHAR(150) = CASE WHEN @oltp = @dw THEN 'diferencia=0' ELSE CONCAT('diferencia=', @oltp - @dw) END;
EXEC qa.usp_Registrar 'T-14', 'RNF-02', N'Reconciliación de importes OLTP vs DW', N'diferencia=0', @obt;
GO

/* ---------- RESUMEN (evidencia E-10) ---------- */
SELECT id_prueba, requisito, descripcion, esperado, obtenido, estado FROM qa.ResultadoPrueba ORDER BY id_prueba;
SELECT estado, COUNT(*) AS pruebas FROM qa.ResultadoPrueba GROUP BY estado;
GO
