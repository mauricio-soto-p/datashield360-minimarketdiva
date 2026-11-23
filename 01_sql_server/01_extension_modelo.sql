/* =====================================================================
   PROYECTO  : DataShield 360 - Minimarket Diva (licorería)
   CURSO     : Base de Datos Avanzadas y Big Data (CIIN1487R) - UPN
   SCRIPT 01 : Extensión del modelo original MinimarketDiva
   MOTOR     : SQL Server 2019+ (SSMS)          VERSIÓN: v1.0
   ---------------------------------------------------------------------
   PRERREQUISITO: ejecutar antes, en este orden, los scripts originales
   del curso Base de Datos (carpeta 00_modelo_original):
       00a_Creacion_Base_de_Datos.sql  (crea MinimarketDiva en D:\ )
       00b_Creacion_Tablas.sql         (11 tablas)
       00c_Registro_de_datos.sql       (datos de prueba originales)
   Si su PC no tiene unidad D:, cambie las rutas FILENAME del 00a.
   ---------------------------------------------------------------------
   Este script NO altera las 11 tablas originales salvo para:
     - agregar restricciones CHECK que faltaban (integridad)
     - agregar dbo.Venta.estado_venta (para anular sin borrar)
   y crea 5 tablas nuevas de automatización / auditoría.
   ===================================================================== */
USE master;
GO

/* ---------- 1. Capacidad: el histórico 2024-2026 (150 mil líneas) supera los
   límites originales (MAXSIZE 100 MB datos / 25 MB log). Se amplían. ---------- */
ALTER DATABASE MinimarketDiva MODIFY FILE (NAME = MinimarketDiva_Data, MAXSIZE = 2GB,  FILEGROWTH = 64MB);
ALTER DATABASE MinimarketDiva MODIFY FILE (NAME = MinimarketDiva_Log,  MAXSIZE = 1GB,  FILEGROWTH = 64MB);
-- Modelo FULL: requisito para respaldos de log y recuperación a un punto en el tiempo (script 06)
ALTER DATABASE MinimarketDiva SET RECOVERY FULL;
GO

USE MinimarketDiva;
GO

/* ---------- 2. Restricciones de integridad que el modelo original no tenía ---------- */
ALTER TABLE dbo.Producto      ADD CONSTRAINT CK_Producto_Precios  CHECK (pVenta_producto > 0 AND pCompra_producto > 0 AND pVenta_producto >= pCompra_producto);
ALTER TABLE dbo.DetalleVenta  ADD CONSTRAINT CK_DetVenta_Cantidad CHECK (cantidad_detalleVenta > 0);
ALTER TABLE dbo.DetalleVenta  ADD CONSTRAINT CK_DetVenta_Precio   CHECK (precio_unit_detalleVenta > 0);
ALTER TABLE dbo.DetallePedido ADD CONSTRAINT CK_DetPedido_Cantidad CHECK (cantidad_detallePedido > 0);
ALTER TABLE dbo.Inventario    ADD CONSTRAINT CK_Inventario_Stock  CHECK (stock_actual_inventario >= 0
                                                                          AND stock_minimo_inventario <= stock_maximo_inventario);
ALTER TABLE dbo.Cliente       ADD CONSTRAINT CK_Cliente_Celular   CHECK (LEN(celular_cliente) = 9);
ALTER TABLE dbo.Empleado      ADD CONSTRAINT CK_Empleado_Turno    CHECK (turno_empleado IN ('Mañana','Noche'));
GO

/* ---------- 3. Estado de la venta: una venta NUNCA se borra, se ANULA ---------- */
ALTER TABLE dbo.Venta ADD estado_venta VARCHAR(12) NOT NULL
      CONSTRAINT DF_Venta_Estado DEFAULT ('REGISTRADA')
      CONSTRAINT CK_Venta_Estado CHECK (estado_venta IN ('REGISTRADA','ANULADA'));
GO

/* ---------- 4. Tablas nuevas de automatización ---------- */
-- 4.1 Kardex: cada entrada/salida de stock queda registrada (trazabilidad del inventario)
CREATE TABLE dbo.MovimientoInventario (
    id_movimiento    BIGINT IDENTITY(1,1) CONSTRAINT PK_MovimientoInventario PRIMARY KEY,
    id_producto      INT          NOT NULL CONSTRAINT FK_Mov_Producto REFERENCES dbo.Producto(id_producto),
    tipo_movimiento  VARCHAR(10)  NOT NULL CONSTRAINT CK_Mov_Tipo CHECK (tipo_movimiento IN ('INGRESO','SALIDA','AJUSTE')),
    cantidad         INT          NOT NULL,
    stock_resultante INT          NOT NULL,
    referencia       VARCHAR(60)  NULL,            -- 'VENTA 75044', 'PEDIDO 365', 'ANULA VENTA 120'
    fecha_movimiento DATETIME2(0) NOT NULL CONSTRAINT DF_Mov_Fecha DEFAULT (SYSDATETIME()),
    usuario          SYSNAME      NOT NULL CONSTRAINT DF_Mov_Usuario DEFAULT (SUSER_SNAME())
);

-- 4.2 Alertas automáticas de reposición (las genera un trigger y un procedimiento)
CREATE TABLE dbo.AlertaStock (
    id_alerta     INT IDENTITY(1,1) CONSTRAINT PK_AlertaStock PRIMARY KEY,
    id_producto   INT          NOT NULL CONSTRAINT FK_Alerta_Producto REFERENCES dbo.Producto(id_producto),
    stock_actual  INT          NOT NULL,
    stock_minimo  INT          NOT NULL,
    fecha_alerta  DATETIME2(0) NOT NULL CONSTRAINT DF_Alerta_Fecha DEFAULT (SYSDATETIME()),
    estado_alerta VARCHAR(10)  NOT NULL CONSTRAINT DF_Alerta_Estado DEFAULT ('PENDIENTE')
                  CONSTRAINT CK_Alerta_Estado CHECK (estado_alerta IN ('PENDIENTE','ATENDIDA'))
);

-- 4.3 Restricciones legales de venta de alcohol (Ley Seca electoral - Ley N.° 26859, art. 351)
CREATE TABLE dbo.RestriccionVenta (
    id_restriccion INT IDENTITY(1,1) CONSTRAINT PK_RestriccionVenta PRIMARY KEY,
    fecha_inicio   DATETIME2(0) NOT NULL,
    fecha_fin      DATETIME2(0) NOT NULL,
    motivo         VARCHAR(100) NOT NULL,
    CONSTRAINT CK_Restriccion_Fechas CHECK (fecha_fin > fecha_inicio)
);
INSERT INTO dbo.RestriccionVenta (fecha_inicio, fecha_fin, motivo) VALUES
 ('2026-04-11T08:00:00', '2026-04-13T08:00:00', 'Ley seca - Elecciones Generales 2026'),
 ('2026-06-06T08:00:00', '2026-06-08T08:00:00', 'Ley seca - Segunda vuelta 2026');
GO

-- 4.4 Esquema de auditoría separado: permite negarlo a perfiles no autorizados
CREATE SCHEMA auditoria AUTHORIZATION dbo;
GO
CREATE TABLE auditoria.RegistroAuditoria (
    id_auditoria     BIGINT IDENTITY(1,1) CONSTRAINT PK_RegistroAuditoria PRIMARY KEY,
    tabla            SYSNAME       NOT NULL,
    operacion        CHAR(6)       NOT NULL CONSTRAINT CK_Aud_Operacion CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    clave_registro   VARCHAR(50)   NULL,
    datos_anteriores NVARCHAR(MAX) NULL,      -- fila previa en JSON (tabla virtual deleted)
    datos_nuevos     NVARCHAR(MAX) NULL,      -- fila nueva en JSON (tabla virtual inserted)
    usuario          SYSNAME       NOT NULL CONSTRAINT DF_Aud_Usuario DEFAULT (SUSER_SNAME()),
    host             NVARCHAR(128) NULL     CONSTRAINT DF_Aud_Host    DEFAULT (HOST_NAME()),
    aplicacion       NVARCHAR(128) NULL     CONSTRAINT DF_Aud_App     DEFAULT (APP_NAME()),
    fecha_hora       DATETIME2(3)  NOT NULL CONSTRAINT DF_Aud_Fecha   DEFAULT (SYSDATETIME())
);
-- 4.5 Bitácora central de errores capturados por TRY-CATCH
CREATE TABLE auditoria.LogErrores (
    id_error      INT IDENTITY(1,1) CONSTRAINT PK_LogErrores PRIMARY KEY,
    procedimiento SYSNAME        NULL,
    numero_error  INT            NULL,
    mensaje       NVARCHAR(4000) NULL,
    linea         INT            NULL,
    usuario       SYSNAME        NOT NULL CONSTRAINT DF_LogErr_Usuario DEFAULT (SUSER_SNAME()),
    fecha_hora    DATETIME2(3)   NOT NULL CONSTRAINT DF_LogErr_Fecha DEFAULT (SYSDATETIME())
);
GO

/* ---------- 5. Índices de apoyo (las FK no crean índices automáticamente) ---------- */
CREATE NONCLUSTERED INDEX IX_DetalleVenta_Venta    ON dbo.DetalleVenta(id_venta)    INCLUDE (id_producto, cantidad_detalleVenta, precio_unit_detalleVenta);
CREATE NONCLUSTERED INDEX IX_DetalleVenta_Producto ON dbo.DetalleVenta(id_producto) INCLUDE (cantidad_detalleVenta, precio_unit_detalleVenta);
CREATE NONCLUSTERED INDEX IX_Venta_Cliente         ON dbo.Venta(id_cliente);
CREATE NONCLUSTERED INDEX IX_Auditoria_Tabla_Fecha ON auditoria.RegistroAuditoria(tabla, fecha_hora);
-- IX_Venta_Fecha se crea en el script 09 para medir su impacto (EXP-01)
GO

PRINT 'Script 01 completado: modelo MinimarketDiva extendido a 16 tablas.';
SELECT s.name AS esquema, t.name AS tabla FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id ORDER BY 1, 2;
