/* =====================================================================
   SCRIPT 07 : Data Mart de Ventas - modelo ESTRELLA (Kimball, bottom-up)
   ---------------------------------------------------------------------
   Base      : MinimarketDiva_DW (separada de la OLTP: no compite con la caja)
   Grano     : 1 fila de hecho = 1 línea de producto en una venta REGISTRADA
   Hechos    : dw.FactVentas  (Cantidad, Importe, Costo, Margen)
   Dimensiones (6): DimTiempo, DimHora, DimProducto, DimCliente,
                    DimEmpleado, DimMetodoPago
   Privacidad: DimCliente y DimEmpleado NO guardan celular, DNI ni sueldo.
   ===================================================================== */
USE master;
GO
IF DB_ID(N'MinimarketDiva_DW') IS NULL CREATE DATABASE MinimarketDiva_DW;
GO
ALTER DATABASE MinimarketDiva_DW SET RECOVERY SIMPLE;   -- se recarga desde la OLTP; no requiere backup de log
GO
USE MinimarketDiva_DW;
GO
IF SCHEMA_ID(N'dw')  IS NULL EXEC (N'CREATE SCHEMA dw');    -- modelo dimensional
IF SCHEMA_ID(N'stg') IS NULL EXEC (N'CREATE SCHEMA stg');   -- staging del ETL
IF SCHEMA_ID(N'etl') IS NULL EXEC (N'CREATE SCHEMA etl');   -- control, bitácora y rechazos
IF SCHEMA_ID(N'exp') IS NULL EXEC (N'CREATE SCHEMA exp');   -- resultados del experimento EXP-01
GO
DROP TABLE IF EXISTS dw.FactVentas, dw.DimTiempo, dw.DimHora, dw.DimProducto, dw.DimCliente, dw.DimEmpleado, dw.DimMetodoPago;
GO

CREATE TABLE dw.DimTiempo (
    SK_Tiempo     INT          NOT NULL CONSTRAINT PK_DimTiempo PRIMARY KEY,    -- AAAAMMDD
    Fecha         DATE         NOT NULL UNIQUE,
    Anio          SMALLINT     NOT NULL,
    Trimestre     TINYINT      NOT NULL,
    Mes           TINYINT      NOT NULL,
    NombreMes     NVARCHAR(12) NOT NULL,
    Dia           TINYINT      NOT NULL,
    NombreDia     NVARCHAR(10) NOT NULL,
    EsFinDeSemana BIT          NOT NULL,      -- viernes, sábado y domingo (comportamiento de licorería)
    EsFeriado     BIT          NOT NULL,
    Temporada     NVARCHAR(10) NOT NULL       -- Verano (ene-mar), Campaña (jul, dic), Regular
);
CREATE TABLE dw.DimHora (
    SK_Hora TINYINT     NOT NULL CONSTRAINT PK_DimHora PRIMARY KEY,           -- 0..23
    Hora    TINYINT     NOT NULL,
    Franja  VARCHAR(10) NOT NULL,                                             -- Madrugada/Mañana/Tarde/Noche
    Turno   VARCHAR(10) NOT NULL                                              -- MAÑANA (<17h) / NOCHE
);
CREATE TABLE dw.DimProducto (
    SK_Producto  INT IDENTITY(1,1) CONSTRAINT PK_DimProducto PRIMARY KEY,
    IdProducto   INT           NOT NULL UNIQUE,          -- clave natural (OLTP)
    Producto     VARCHAR(80)   NOT NULL,
    Categoria    VARCHAR(50)   NOT NULL,                 -- desnormalizada: estrella, no copo de nieve
    EsAlcoholico CHAR(2)       NOT NULL,
    PrecioVenta  DECIMAL(10,2) NOT NULL,
    PrecioCompra DECIMAL(10,2) NOT NULL,
    FechaCarga   DATETIME2(0)  NOT NULL DEFAULT (SYSDATETIME())
);
CREATE TABLE dw.DimCliente (
    SK_Cliente     INT IDENTITY(1,1) CONSTRAINT PK_DimCliente PRIMARY KEY,
    IdCliente      INT          NOT NULL UNIQUE,
    ClienteAnonimo VARCHAR(20)  NOT NULL,                 -- CLI-00025 (seudónimo, sin nombre ni celular)
    TipoCliente    VARCHAR(20)  NOT NULL                  -- FRECUENTE / NO IDENTIFICADO
);
CREATE TABLE dw.DimEmpleado (
    SK_Empleado INT IDENTITY(1,1) CONSTRAINT PK_DimEmpleado PRIMARY KEY,
    IdEmpleado  INT          NOT NULL UNIQUE,
    Empleado    VARCHAR(70)  NOT NULL,                    -- nombre + apellido paterno (sin DNI ni sueldo)
    Cargo       VARCHAR(30)  NOT NULL,
    Turno       VARCHAR(10)  NOT NULL
);
CREATE TABLE dw.DimMetodoPago (
    SK_MetodoPago INT IDENTITY(1,1) CONSTRAINT PK_DimMetodoPago PRIMARY KEY,
    IdMetodoPago  INT         NOT NULL UNIQUE,
    MetodoPago    VARCHAR(30) NOT NULL,
    EsDigital     CHAR(2)     NOT NULL                    -- Yape, Plin, Tarjeta, Transferencia = SI
);
CREATE TABLE dw.FactVentas (
    IdDetalle     INT           NOT NULL CONSTRAINT PK_FactVentas PRIMARY KEY,   -- dimensión degenerada (línea)
    SK_Tiempo     INT           NOT NULL CONSTRAINT FK_Fact_Tiempo     REFERENCES dw.DimTiempo(SK_Tiempo),
    SK_Hora       TINYINT       NOT NULL CONSTRAINT FK_Fact_Hora       REFERENCES dw.DimHora(SK_Hora),
    SK_Producto   INT           NOT NULL CONSTRAINT FK_Fact_Producto   REFERENCES dw.DimProducto(SK_Producto),
    SK_Cliente    INT           NOT NULL CONSTRAINT FK_Fact_Cliente    REFERENCES dw.DimCliente(SK_Cliente),
    SK_Empleado   INT           NOT NULL CONSTRAINT FK_Fact_Empleado   REFERENCES dw.DimEmpleado(SK_Empleado),
    SK_MetodoPago INT           NOT NULL CONSTRAINT FK_Fact_MetodoPago REFERENCES dw.DimMetodoPago(SK_MetodoPago),
    NroVenta      INT           NOT NULL,                 -- dimensión degenerada (ticket)
    Cantidad      INT           NOT NULL,
    Importe       DECIMAL(12,2) NOT NULL,                 -- precio de venta (incluye IGV)
    Costo         DECIMAL(12,2) NOT NULL,                 -- cantidad * precio de compra
    Margen        DECIMAL(12,2) NOT NULL                  -- Importe - Costo
);
GO
-- (El índice COLUMNSTORE se crea en el script 09 como variable del experimento EXP-01)

/* ---------- Staging ---------- */
DROP TABLE IF EXISTS stg.Venta, stg.DetalleVenta;
CREATE TABLE stg.Venta (id_venta INT, monto_venta DECIMAL(10,2), fecha_venta DATETIME, id_cliente INT,
                        id_metodoPago INT, id_empleado INT, estado_venta VARCHAR(12));
CREATE TABLE stg.DetalleVenta (id_detalleVenta INT, cantidad INT, precio_unit DECIMAL(10,2), id_venta INT, id_producto INT);
GO

/* ---------- Control del ETL ---------- */
IF OBJECT_ID(N'etl.LogCarga') IS NULL
    CREATE TABLE etl.LogCarga (
        IdCarga INT IDENTITY(1,1) PRIMARY KEY, Proceso NVARCHAR(60) NOT NULL,
        Inicio DATETIME2(3) NOT NULL, Fin DATETIME2(3) NULL, DuracionMs AS DATEDIFF(MILLISECOND, Inicio, Fin),
        FilasLeidas INT NULL, FilasCargadas INT NULL, FilasRechazadas INT NULL, FilasExcluidas INT NULL,
        Estado VARCHAR(10) NOT NULL, Mensaje NVARCHAR(4000) NULL);
IF OBJECT_ID(N'etl.Rechazos') IS NULL
    CREATE TABLE etl.Rechazos (IdRechazo INT IDENTITY(1,1) PRIMARY KEY, IdCarga INT, Tabla SYSNAME,
                               Clave VARCHAR(50), Motivo NVARCHAR(200), Fecha DATETIME2(0) DEFAULT (SYSDATETIME()));
IF OBJECT_ID(N'etl.ControlIncremental') IS NULL
BEGIN
    CREATE TABLE etl.ControlIncremental (Proceso NVARCHAR(60) PRIMARY KEY, UltimoId INT NOT NULL);
    INSERT INTO etl.ControlIncremental VALUES (N'FactVentas', 0);
END
UPDATE etl.ControlIncremental SET UltimoId = 0 WHERE Proceso = N'FactVentas';   -- hechos recreados vacíos
GO
PRINT 'Script 07 completado: MinimarketDiva_DW con 1 tabla de hechos y 6 dimensiones.';
