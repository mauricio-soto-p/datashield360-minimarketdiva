/* =====================================================================
   SCRIPT 08 : ETL automatizado MinimarketDiva (OLTP) -> MinimarketDiva_DW
   ---------------------------------------------------------------------
   E  etl.usp_Extraer             incremental por marca de agua (id_detalleVenta)
   T  reglas de calidad / negocio  (R1-R8)
   L  etl.usp_CargarDimensiones   MERGE = SCD tipo 1
      etl.usp_CargarHechos        solo líneas nuevas y válidas
   Orquestador etl.usp_EjecutarETL (transacción + bitácora + reconciliación)
   REGLAS
     R1 Estandarización : TRIM + MAYÚSCULAS en textos
     R2 Nulos           : texto vacío -> 'SIN DATO'
     R3 Filtro negocio  : se excluyen ventas ANULADAS
     R4 Validez         : cantidad <= 0, precio <= 0 o producto inexistente -> etl.Rechazos
     R5 Derivación      : Importe = cantidad * precio_unit ; Costo = Importe * (pCompra/pVenta)
                          ; Margen = Importe - Costo  (no se usa monto_venta: ver hallazgo
                          de calidad del script 02)
     R6 Claves          : fecha -> SK_Tiempo AAAAMMDD ; hora -> SK_Hora
     R7 Privacidad      : cliente -> seudónimo CLI-00000 ; sin celular, DNI ni sueldo
     R8 Deduplicación   : ROW_NUMBER() por id_detalleVenta
   Automatización: un job del Agente (al final) ejecuta el ETL a diario 05:30.
   ===================================================================== */
USE MinimarketDiva_DW;
GO

/* ---------- DimTiempo y DimHora (se generan) ---------- */
CREATE OR ALTER PROCEDURE etl.usp_CargarCalendario
    @desde DATE = '2024-01-01', @hasta DATE = '2027-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    SET LANGUAGE Spanish;                               -- meses/días en español y semana desde el lunes
    ;WITH f AS (SELECT @desde AS Fecha UNION ALL SELECT DATEADD(DAY, 1, Fecha) FROM f WHERE Fecha < @hasta)
    INSERT INTO dw.DimTiempo
    SELECT CONVERT(INT, FORMAT(Fecha, 'yyyyMMdd')), Fecha, YEAR(Fecha), DATEPART(QUARTER, Fecha), MONTH(Fecha),
           UPPER(LEFT(DATENAME(MONTH, Fecha), 1)) + SUBSTRING(DATENAME(MONTH, Fecha), 2, 20), DAY(Fecha),
           UPPER(LEFT(DATENAME(WEEKDAY, Fecha), 1)) + SUBSTRING(DATENAME(WEEKDAY, Fecha), 2, 20),
           CASE WHEN DATEPART(WEEKDAY, Fecha) >= 5 THEN 1 ELSE 0 END,                  -- vie, sáb, dom
           CASE WHEN FORMAT(Fecha, 'MMdd') IN ('0101','0501','0629','0728','0729','0830','1008','1101','1208','1225') THEN 1 ELSE 0 END,
           CASE WHEN MONTH(Fecha) IN (1,2,3) THEN N'Verano' WHEN MONTH(Fecha) IN (7,12) THEN N'Campaña' ELSE N'Regular' END
    FROM f WHERE NOT EXISTS (SELECT 1 FROM dw.DimTiempo t WHERE t.Fecha = f.Fecha)
    OPTION (MAXRECURSION 0);

    ;WITH h AS (SELECT 0 AS Hora UNION ALL SELECT Hora + 1 FROM h WHERE Hora < 23)
    INSERT INTO dw.DimHora
    SELECT Hora, Hora,
           CASE WHEN Hora < 6 THEN 'Madrugada' WHEN Hora < 12 THEN 'Mañana' WHEN Hora < 18 THEN 'Tarde' ELSE 'Noche' END,
           CASE WHEN Hora < 17 THEN 'MAÑANA' ELSE 'NOCHE' END
    FROM h WHERE NOT EXISTS (SELECT 1 FROM dw.DimHora x WHERE x.SK_Hora = h.Hora);
END;
GO

/* ---------- E: extracción incremental ---------- */
CREATE OR ALTER PROCEDURE etl.usp_Extraer
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE stg.Venta; TRUNCATE TABLE stg.DetalleVenta;
    DECLARE @ultimo INT = (SELECT UltimoId FROM etl.ControlIncremental WHERE Proceso = N'FactVentas');

    INSERT INTO stg.DetalleVenta
    SELECT id_detalleVenta, cantidad_detalleVenta, precio_unit_detalleVenta, id_venta, id_producto
    FROM MinimarketDiva.dbo.DetalleVenta WHERE id_detalleVenta > @ultimo;

    INSERT INTO stg.Venta
    SELECT v.id_venta, v.monto_venta, v.fecha_venta, v.id_cliente, v.id_metodoPago, v.id_empleado, v.estado_venta
    FROM MinimarketDiva.dbo.Venta v
    WHERE EXISTS (SELECT 1 FROM stg.DetalleVenta d WHERE d.id_venta = v.id_venta);
END;
GO

/* ---------- T + L: dimensiones (SCD tipo 1) ---------- */
CREATE OR ALTER PROCEDURE etl.usp_CargarDimensiones
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dw.DimProducto AS t
    USING (SELECT p.id_producto,
                  COALESCE(NULLIF(UPPER(TRIM(p.nombre_producto)), ''), 'SIN DATO')  AS Producto,      -- R1, R2
                  COALESCE(NULLIF(UPPER(TRIM(c.nombre_categoria)), ''), 'SIN DATO') AS Categoria,
                  CASE WHEN p.id_categoria IN (1,2,3,4,6,7) THEN 'SI' ELSE 'NO' END AS EsAlcoholico,
                  p.pVenta_producto, p.pCompra_producto
           FROM MinimarketDiva.dbo.Producto p JOIN MinimarketDiva.dbo.Categoria c ON c.id_categoria = p.id_categoria) AS s
       ON t.IdProducto = s.id_producto
    WHEN MATCHED AND (t.Producto <> s.Producto OR t.Categoria <> s.Categoria
                      OR t.PrecioVenta <> s.pVenta_producto OR t.PrecioCompra <> s.pCompra_producto) THEN
        UPDATE SET Producto = s.Producto, Categoria = s.Categoria, PrecioVenta = s.pVenta_producto,
                   PrecioCompra = s.pCompra_producto, FechaCarga = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (IdProducto, Producto, Categoria, EsAlcoholico, PrecioVenta, PrecioCompra)
        VALUES (s.id_producto, s.Producto, s.Categoria, s.EsAlcoholico, s.pVenta_producto, s.pCompra_producto);

    MERGE dw.DimCliente AS t                                                        -- R7 seudonimización
    USING (SELECT id_cliente,
                  CASE WHEN id_cliente = 13 THEN 'CLIENTE VARIOS' ELSE 'CLI-' + RIGHT('00000' + CAST(id_cliente AS VARCHAR(5)), 5) END AS ClienteAnonimo,
                  CASE WHEN id_cliente = 13 THEN 'NO IDENTIFICADO' ELSE 'FRECUENTE' END AS TipoCliente
           FROM MinimarketDiva.dbo.Cliente) AS s
       ON t.IdCliente = s.id_cliente
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (IdCliente, ClienteAnonimo, TipoCliente) VALUES (s.id_cliente, s.ClienteAnonimo, s.TipoCliente);

    MERGE dw.DimEmpleado AS t
    USING (SELECT id_empleado, UPPER(TRIM(nombre_empleado) + ' ' + TRIM(ape_pat_empleado)) AS Empleado,
                  UPPER(TRIM(cargo_empleado)) AS Cargo, UPPER(TRIM(turno_empleado)) AS Turno
           FROM MinimarketDiva.dbo.Empleado) AS s
       ON t.IdEmpleado = s.id_empleado
    WHEN MATCHED AND (t.Cargo <> s.Cargo OR t.Turno <> s.Turno OR t.Empleado <> s.Empleado) THEN
        UPDATE SET Empleado = s.Empleado, Cargo = s.Cargo, Turno = s.Turno
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (IdEmpleado, Empleado, Cargo, Turno) VALUES (s.id_empleado, s.Empleado, s.Cargo, s.Turno);

    MERGE dw.DimMetodoPago AS t
    USING (SELECT id_metodoPago, UPPER(TRIM(tipo_metodoPago)) AS MetodoPago,
                  CASE WHEN tipo_metodoPago = 'Efectivo' THEN 'NO' ELSE 'SI' END AS EsDigital
           FROM MinimarketDiva.dbo.MetodoPago) AS s
       ON t.IdMetodoPago = s.id_metodoPago
    WHEN MATCHED AND t.MetodoPago <> s.MetodoPago THEN UPDATE SET MetodoPago = s.MetodoPago, EsDigital = s.EsDigital
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (IdMetodoPago, MetodoPago, EsDigital) VALUES (s.id_metodoPago, s.MetodoPago, s.EsDigital);
END;
GO

/* ---------- T + L: hechos ---------- */
CREATE OR ALTER PROCEDURE etl.usp_CargarHechos
    @IdCarga INT, @Leidas INT OUTPUT, @Cargadas INT OUTPUT, @Rechazadas INT OUTPUT, @Excluidas INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Leidas = COUNT(*) FROM stg.DetalleVenta;

    INSERT INTO etl.Rechazos (IdCarga, Tabla, Clave, Motivo)                                       -- R4
    SELECT @IdCarga, N'DetalleVenta', CAST(d.id_detalleVenta AS VARCHAR(50)),
           CASE WHEN d.cantidad <= 0 THEN N'Cantidad no válida' WHEN d.precio_unit <= 0 THEN N'Precio no válido'
                ELSE N'Producto inexistente en DimProducto' END
    FROM stg.DetalleVenta d LEFT JOIN dw.DimProducto p ON p.IdProducto = d.id_producto
    WHERE d.cantidad <= 0 OR d.precio_unit <= 0 OR p.SK_Producto IS NULL;
    SET @Rechazadas = @@ROWCOUNT;

    SELECT @Excluidas = COUNT(*) FROM stg.DetalleVenta d JOIN stg.Venta v ON v.id_venta = d.id_venta
    WHERE v.estado_venta = 'ANULADA';                                                               -- R3

    ;WITH l AS (SELECT d.*, ROW_NUMBER() OVER (PARTITION BY d.id_detalleVenta ORDER BY d.id_detalleVenta) AS rn
                FROM stg.DetalleVenta d)                                                            -- R8
    INSERT INTO dw.FactVentas (IdDetalle, SK_Tiempo, SK_Hora, SK_Producto, SK_Cliente, SK_Empleado, SK_MetodoPago,
                               NroVenta, Cantidad, Importe, Costo, Margen)
    SELECT l.id_detalleVenta,
           CONVERT(INT, FORMAT(v.fecha_venta, 'yyyyMMdd')), DATEPART(HOUR, v.fecha_venta),            -- R6
           p.SK_Producto, c.SK_Cliente, e.SK_Empleado, m.SK_MetodoPago, v.id_venta, l.cantidad,
           ROUND(l.cantidad * l.precio_unit, 2),                                                    -- R5
           ROUND(l.cantidad * l.precio_unit * p.PrecioCompra / p.PrecioVenta, 2),
           ROUND(l.cantidad * l.precio_unit, 2) - ROUND(l.cantidad * l.precio_unit * p.PrecioCompra / p.PrecioVenta, 2)
    FROM l
    JOIN stg.Venta v        ON v.id_venta = l.id_venta
    JOIN dw.DimProducto p   ON p.IdProducto = l.id_producto
    JOIN dw.DimCliente c    ON c.IdCliente = v.id_cliente
    JOIN dw.DimEmpleado e   ON e.IdEmpleado = v.id_empleado
    JOIN dw.DimMetodoPago m ON m.IdMetodoPago = v.id_metodoPago
    WHERE l.rn = 1 AND v.estado_venta = 'REGISTRADA' AND l.cantidad > 0 AND l.precio_unit > 0
      AND NOT EXISTS (SELECT 1 FROM dw.FactVentas f WHERE f.IdDetalle = l.id_detalleVenta);
    SET @Cargadas = @@ROWCOUNT;

    UPDATE etl.ControlIncremental
       SET UltimoId = COALESCE((SELECT MAX(id_detalleVenta) FROM stg.DetalleVenta), UltimoId)
     WHERE Proceso = N'FactVentas';
END;
GO

/* ---------- Orquestador ---------- */
CREATE OR ALTER PROCEDURE etl.usp_EjecutarETL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @IdCarga INT, @l INT, @c INT, @r INT, @x INT;
    INSERT INTO etl.LogCarga (Proceso, Inicio, Estado) VALUES (N'ETL Ventas', SYSDATETIME(), 'EN CURSO');
    SET @IdCarga = SCOPE_IDENTITY();
    BEGIN TRY
        EXEC etl.usp_CargarCalendario;
        EXEC etl.usp_Extraer;
        BEGIN TRANSACTION;                                   -- T + L atómicos
            EXEC etl.usp_CargarDimensiones;
            EXEC etl.usp_CargarHechos @IdCarga, @l OUTPUT, @c OUTPUT, @r OUTPUT, @x OUTPUT;
        COMMIT TRANSACTION;
        UPDATE etl.LogCarga SET Fin = SYSDATETIME(), FilasLeidas = @l, FilasCargadas = @c, FilasRechazadas = @r,
                                FilasExcluidas = @x, Estado = 'OK'
         WHERE IdCarga = @IdCarga;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;             -- el DW queda como antes de la carga
        UPDATE etl.LogCarga SET Fin = SYSDATETIME(), Estado = 'ERROR', Mensaje = ERROR_MESSAGE() WHERE IdCarga = @IdCarga;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   EJECUCIÓN Y CONTROL DE CALIDAD (evidencias E-02 / E-07)
   ===================================================================== */
EXEC etl.usp_EjecutarETL;                                    -- carga inicial completa
SELECT * FROM etl.LogCarga ORDER BY IdCarga DESC;            -- esperado: leídas 150,816 | cargadas 148,959 | excluidas 1,857

SELECT 'DimTiempo' AS tabla, COUNT(*) AS filas FROM dw.DimTiempo UNION ALL
SELECT 'DimHora', COUNT(*) FROM dw.DimHora UNION ALL
SELECT 'DimProducto', COUNT(*) FROM dw.DimProducto UNION ALL
SELECT 'DimCliente', COUNT(*) FROM dw.DimCliente UNION ALL
SELECT 'DimEmpleado', COUNT(*) FROM dw.DimEmpleado UNION ALL
SELECT 'DimMetodoPago', COUNT(*) FROM dw.DimMetodoPago UNION ALL
SELECT 'FactVentas', COUNT(*) FROM dw.FactVentas;

-- Reconciliación OLTP vs DW (deben ser iguales)
SELECT (SELECT SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta)
        FROM MinimarketDiva.dbo.DetalleVenta d JOIN MinimarketDiva.dbo.Venta v ON v.id_venta = d.id_venta
        WHERE v.estado_venta = 'REGISTRADA') AS total_oltp,
       (SELECT SUM(Importe) FROM dw.FactVentas) AS total_dw;

-- Segunda ejecución: carga INCREMENTAL (solo líneas nuevas; debe leer 0 si no hubo ventas)
EXEC etl.usp_EjecutarETL;
SELECT TOP (2) * FROM etl.LogCarga ORDER BY IdCarga DESC;
GO

/* =====================================================================
   CONSULTAS OLAP de referencia (las mismas preguntas del dashboard)
   ===================================================================== */
-- Roll-up: Año > Trimestre
SELECT t.Anio, t.Trimestre, SUM(f.Importe) AS Ventas, SUM(f.Margen) AS Margen
FROM dw.FactVentas f JOIN dw.DimTiempo t ON t.SK_Tiempo = f.SK_Tiempo
GROUP BY ROLLUP (t.Anio, t.Trimestre) ORDER BY t.Anio, t.Trimestre;

-- Slice & dice: categoría x turno (2025)
SELECT p.Categoria, h.Turno, SUM(f.Importe) AS Ventas
FROM dw.FactVentas f JOIN dw.DimProducto p ON p.SK_Producto = f.SK_Producto
JOIN dw.DimHora h ON h.SK_Hora = f.SK_Hora JOIN dw.DimTiempo t ON t.SK_Tiempo = f.SK_Tiempo
WHERE t.Anio = 2025 GROUP BY CUBE (p.Categoria, h.Turno);

-- Pivot: ventas por día de la semana y franja
SELECT * FROM (SELECT t.NombreDia, h.Franja, f.Importe FROM dw.FactVentas f
               JOIN dw.DimTiempo t ON t.SK_Tiempo = f.SK_Tiempo JOIN dw.DimHora h ON h.SK_Hora = f.SK_Hora) s
PIVOT (SUM(Importe) FOR Franja IN ([Mañana], [Tarde], [Noche])) pv;
GO

/* ---------- Automatización: job diario del ETL (SQL Server Agent) ---------- */
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Diva - ETL diario DW') EXEC msdb.dbo.sp_delete_job @job_name = N'Diva - ETL diario DW';
EXEC msdb.dbo.sp_add_job         @job_name = N'Diva - ETL diario DW', @description = N'Carga incremental OLTP -> DW (DataShield 360)';
EXEC msdb.dbo.sp_add_jobstep     @job_name = N'Diva - ETL diario DW', @step_name = N'Ejecutar ETL', @subsystem = N'TSQL',
                                 @database_name = N'MinimarketDiva_DW', @command = N'EXEC etl.usp_EjecutarETL;', @retry_attempts = 2, @retry_interval = 10;
EXEC msdb.dbo.sp_add_jobschedule @job_name = N'Diva - ETL diario DW', @name = N'Diario 05:30', @freq_type = 4, @freq_interval = 1,
                                 @active_start_time = 53000;      -- antes del FULL/DIFF de 06:00 y de la apertura (09:00)
EXEC msdb.dbo.sp_add_jobserver   @job_name = N'Diva - ETL diario DW', @server_name = N'(local)';
GO
