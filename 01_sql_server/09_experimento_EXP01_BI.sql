/* =====================================================================
   SCRIPT 09 : EXPERIMENTO EXP-01 (Solución BI) - Capítulo IV del informe
   ---------------------------------------------------------------------
   Pregunta : ¿Cuánto reduce el modelo dimensional (y el índice columnar)
              el tiempo de respuesta de la consulta típica del dashboard
              frente a consultar directamente la base transaccional?
   Consulta : ventas y margen mensual por categoría del año 2025
              (misma respuesta en las 4 configuraciones -> se valida).
   Variable independiente: configuración del almacenamiento
     C1 OLTP normalizada, sin índice por fecha
     C2 OLTP + índice no agrupado IX_Venta_Fecha
     C3 DW estrella (rowstore)
     C4 DW estrella + índice COLUMNSTORE no agrupado
   Variable dependiente : tiempo transcurrido (ms) por ejecución
   Controles : mismo equipo, misma consulta lógica, caché caliente
               (1 ejecución de calentamiento descartada), 10 repeticiones,
               sin otras sesiones activas.
   Salida    : exp.ResultadoEXP01 (detalle) + resumen media/desv. estándar
   Ejecutar DESPUÉS de los scripts 07 y 08 (DW cargado).
   ===================================================================== */
USE MinimarketDiva_DW;
GO
IF OBJECT_ID(N'exp.ResultadoEXP01') IS NULL
    CREATE TABLE exp.ResultadoEXP01 (
        id INT IDENTITY(1,1) PRIMARY KEY, corrida VARCHAR(20) NOT NULL, configuracion VARCHAR(40) NOT NULL,
        repeticion INT NOT NULL, ms INT NOT NULL, filas INT NOT NULL, total_ventas DECIMAL(14,2) NULL,
        fecha DATETIME2(0) NOT NULL DEFAULT (SYSDATETIME()), equipo NVARCHAR(128) DEFAULT (HOST_NAME()));
GO

CREATE OR ALTER PROCEDURE exp.usp_MedirConsulta
    @corrida VARCHAR(20), @config VARCHAR(40), @sql NVARCHAR(MAX), @repeticiones INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @i INT = 0, @t0 DATETIME2(7), @ms INT, @filas INT, @total DECIMAL(14,2);
    CREATE TABLE #r (Anio INT, Mes INT, Categoria VARCHAR(50), Ventas DECIMAL(14,2), Margen DECIMAL(14,2));

    INSERT INTO #r EXEC sys.sp_executesql @sql;          -- calentamiento (no se registra)
    WHILE @i < @repeticiones
    BEGIN
        TRUNCATE TABLE #r;
        SET @t0 = SYSDATETIME();
        INSERT INTO #r EXEC sys.sp_executesql @sql;
        SET @ms = DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000;
        SELECT @filas = COUNT(*), @total = SUM(Ventas) FROM #r;
        SET @i += 1;
        INSERT INTO exp.ResultadoEXP01 (corrida, configuracion, repeticion, ms, filas, total_ventas)
        VALUES (@corrida, @config, @i, @ms, @filas, @total);
    END
END;
GO

DECLARE @corrida VARCHAR(20) = CONCAT('RUN-01-', FORMAT(SYSDATETIME(), 'yyyyMMddHHmm'));

-- Consulta sobre la OLTP (4 JOIN + cálculo de margen fila a fila)
DECLARE @q_oltp NVARCHAR(MAX) = N'
SELECT YEAR(v.fecha_venta), MONTH(v.fecha_venta), c.nombre_categoria,
       SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta),
       SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta * (1 - p.pCompra_producto / p.pVenta_producto))
FROM MinimarketDiva.dbo.Venta v
JOIN MinimarketDiva.dbo.DetalleVenta d ON d.id_venta = v.id_venta
JOIN MinimarketDiva.dbo.Producto p     ON p.id_producto = d.id_producto
JOIN MinimarketDiva.dbo.Categoria c    ON c.id_categoria = p.id_categoria
WHERE v.fecha_venta >= ''2025-01-01'' AND v.fecha_venta < ''2026-01-01'' AND v.estado_venta = ''REGISTRADA''
GROUP BY YEAR(v.fecha_venta), MONTH(v.fecha_venta), c.nombre_categoria;';

-- Consulta sobre la estrella (medidas precalculadas)
DECLARE @q_dw NVARCHAR(MAX) = N'
SELECT t.Anio, t.Mes, p.Categoria, SUM(f.Importe), SUM(f.Margen)
FROM dw.FactVentas f
JOIN dw.DimTiempo t   ON t.SK_Tiempo = f.SK_Tiempo
JOIN dw.DimProducto p ON p.SK_Producto = f.SK_Producto
WHERE t.Anio = 2025
GROUP BY t.Anio, t.Mes, p.Categoria;';

-- C1: OLTP sin índice por fecha
EXEC (N'USE MinimarketDiva; DROP INDEX IF EXISTS IX_Venta_Fecha ON dbo.Venta;');
EXEC exp.usp_MedirConsulta @corrida, 'C1 OLTP sin indice', @q_oltp;

-- C2: OLTP con índice cubriente por fecha
EXEC (N'USE MinimarketDiva; CREATE NONCLUSTERED INDEX IX_Venta_Fecha ON dbo.Venta(fecha_venta) INCLUDE (estado_venta);');
EXEC exp.usp_MedirConsulta @corrida, 'C2 OLTP con IX_Venta_Fecha', @q_oltp;

-- C3: DW estrella rowstore
DROP INDEX IF EXISTS NCCI_FactVentas ON dw.FactVentas;
EXEC exp.usp_MedirConsulta @corrida, 'C3 DW estrella rowstore', @q_dw;

-- C4: DW estrella + columnstore
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_FactVentas
    ON dw.FactVentas (SK_Tiempo, SK_Producto, SK_Cliente, SK_Hora, SK_MetodoPago, Cantidad, Importe, Margen);
EXEC exp.usp_MedirConsulta @corrida, 'C4 DW estrella + columnstore', @q_dw;

/* ---------- Resumen (copiar a la tabla 6.3 del informe) ---------- */
SELECT configuracion, COUNT(*) AS n, AVG(CAST(ms AS FLOAT)) AS media_ms, STDEV(ms) AS desv_ms,
       MIN(ms) AS min_ms, MAX(ms) AS max_ms, MAX(filas) AS filas, MAX(total_ventas) AS total_ventas_2025
FROM exp.ResultadoEXP01 WHERE corrida = @corrida
GROUP BY configuracion ORDER BY configuracion;
-- Validación: total_ventas_2025 debe ser IGUAL en las 4 configuraciones (misma respuesta)
GO

/* ---------- Lecturas lógicas (una ejecución por configuración, pestaña Mensajes) ---------- */
SET STATISTICS IO ON;
SELECT t.Anio, t.Mes, p.Categoria, SUM(f.Importe) FROM dw.FactVentas f
JOIN dw.DimTiempo t ON t.SK_Tiempo = f.SK_Tiempo JOIN dw.DimProducto p ON p.SK_Producto = f.SK_Producto
WHERE t.Anio = 2025 GROUP BY t.Anio, t.Mes, p.Categoria;
SET STATISTICS IO OFF;
GO
