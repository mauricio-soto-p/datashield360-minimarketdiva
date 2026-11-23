/* =====================================================================
   SCRIPT 05 : Seguridad - logins, usuarios, roles, privilegios y DDM
   ---------------------------------------------------------------------
   Principio de mínimo privilegio (ISO/IEC 27001:2022 control 5.15 y 8.2)
     rol_administrador : control total de la base (dueño: Fernando Ríos)
     rol_cajero        : solo EJECUTA los procedimientos de venta/pedido
     rol_analista      : solo lee vistas analíticas SIN datos personales
     rol_auditor       : solo lee el esquema auditoria
   Dynamic Data Masking (Ley 29733): celular de clientes; DNI, celular y
   sueldo de empleados. Contraseñas de laboratorio: cámbielas.
   ===================================================================== */
USE master;
GO

-- CREDENCIALES DE LABORATORIO:
-- Valores ficticios para fines académicos.
-- No utilizar en entornos de producción.
IF SUSER_ID(N'lg_admin_diva')   IS NULL CREATE LOGIN lg_admin_diva   WITH PASSWORD = N'Adm!nDiva2026#', CHECK_POLICY = ON, CHECK_EXPIRATION = ON, DEFAULT_DATABASE = MinimarketDiva;
IF SUSER_ID(N'lg_cajero_diva')  IS NULL CREATE LOGIN lg_cajero_diva  WITH PASSWORD = N'CajeroDiva2026#', CHECK_POLICY = ON, CHECK_EXPIRATION = ON, DEFAULT_DATABASE = MinimarketDiva;
IF SUSER_ID(N'lg_analista_bi')  IS NULL CREATE LOGIN lg_analista_bi  WITH PASSWORD = N'Anal1staBI2026#', CHECK_POLICY = ON, CHECK_EXPIRATION = ON, DEFAULT_DATABASE = MinimarketDiva;
IF SUSER_ID(N'lg_auditor_diva') IS NULL CREATE LOGIN lg_auditor_diva WITH PASSWORD = N'Aud1torDiva2026#', CHECK_POLICY = ON, CHECK_EXPIRATION = ON, DEFAULT_DATABASE = MinimarketDiva;
GO

USE MinimarketDiva;
GO
   
/* ---------- Vista analítica sin datos personales (para el analista) ---------- */
CREATE OR ALTER VIEW dbo.vw_VentasAnaliticas
AS
SELECT v.id_venta, CAST(v.fecha_venta AS DATE) AS fecha, DATEPART(HOUR, v.fecha_venta) AS hora,
       e.turno_empleado AS turno, mp.tipo_metodoPago AS metodo_pago,
       c.nombre_categoria AS categoria, p.nombre_producto AS producto,
       d.cantidad_detalleVenta AS cantidad, d.cantidad_detalleVenta * d.precio_unit_detalleVenta AS importe,
       CASE WHEN v.id_cliente = 13 THEN 'NO IDENTIFICADO' ELSE 'FRECUENTE' END AS tipo_cliente,  -- sin nombre ni celular
       v.estado_venta
FROM dbo.Venta v
JOIN dbo.DetalleVenta d ON d.id_venta = v.id_venta
JOIN dbo.Producto p     ON p.id_producto = d.id_producto
JOIN dbo.Categoria c    ON c.id_categoria = p.id_categoria
JOIN dbo.Empleado e     ON e.id_empleado = v.id_empleado
JOIN dbo.MetodoPago mp  ON mp.id_metodoPago = v.id_metodoPago;
GO

/* ---------- Roles ---------- */
IF DATABASE_PRINCIPAL_ID(N'rol_administrador') IS NULL CREATE ROLE rol_administrador AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_cajero')        IS NULL CREATE ROLE rol_cajero        AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_analista')      IS NULL CREATE ROLE rol_analista      AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_auditor')       IS NULL CREATE ROLE rol_auditor       AUTHORIZATION dbo;
GO

/* ---------- Privilegios por objeto ---------- */
-- Administrador
GRANT CONTROL ON DATABASE::MinimarketDiva TO rol_administrador;
GRANT UNMASK TO rol_administrador;                                  -- ve datos personales sin máscara

-- Cajero: toda escritura pasa por los procedimientos (encadenamiento de propiedad)
GRANT EXECUTE ON dbo.usp_RegistrarVenta  TO rol_cajero;
GRANT EXECUTE ON dbo.usp_RegistrarPedido TO rol_cajero;
GRANT EXECUTE ON TYPE::dbo.TipoDetalleVenta  TO rol_cajero;
GRANT EXECUTE ON TYPE::dbo.TipoDetallePedido TO rol_cajero;
GRANT SELECT  ON dbo.Producto   TO rol_cajero;                      -- consulta precios
GRANT SELECT  ON dbo.Inventario TO rol_cajero;                      -- consulta stock
GRANT SELECT  ON dbo.MetodoPago TO rol_cajero;
DENY  EXECUTE ON dbo.usp_AnularVenta TO rol_cajero;                 -- anular es potestad del supervisor
DENY  INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_cajero;
DENY  SELECT ON dbo.Empleado TO rol_cajero;                         -- sueldos y DNI de compañeros
DENY  SELECT ON SCHEMA::auditoria TO rol_cajero;

-- Analista: lectura de la vista anonimizada y catálogos
GRANT SELECT ON dbo.vw_VentasAnaliticas TO rol_analista;
GRANT SELECT ON dbo.Producto   TO rol_analista;
GRANT SELECT ON dbo.Categoria  TO rol_analista;
GRANT SELECT ON dbo.Inventario TO rol_analista;
GRANT SELECT ON dbo.fn_VentasPorPeriodo TO rol_analista;
DENY  SELECT ON dbo.Cliente  TO rol_analista;
DENY  SELECT ON dbo.Empleado TO rol_analista;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_analista;
DENY  SELECT ON SCHEMA::auditoria TO rol_analista;

-- Auditor: solo lectura de la bitácora (inalterable)
GRANT SELECT ON SCHEMA::auditoria TO rol_auditor;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::auditoria TO rol_auditor;
GO

/* ---------- Usuarios y pertenencia a roles ---------- */
IF DATABASE_PRINCIPAL_ID(N'us_admin')    IS NULL CREATE USER us_admin    FOR LOGIN lg_admin_diva;
IF DATABASE_PRINCIPAL_ID(N'us_cajero')   IS NULL CREATE USER us_cajero   FOR LOGIN lg_cajero_diva;
IF DATABASE_PRINCIPAL_ID(N'us_analista') IS NULL CREATE USER us_analista FOR LOGIN lg_analista_bi;
IF DATABASE_PRINCIPAL_ID(N'us_auditor')  IS NULL CREATE USER us_auditor  FOR LOGIN lg_auditor_diva;
GO
ALTER ROLE rol_administrador ADD MEMBER us_admin;
ALTER ROLE rol_cajero        ADD MEMBER us_cajero;
ALTER ROLE rol_analista      ADD MEMBER us_analista;
ALTER ROLE rol_auditor       ADD MEMBER us_auditor;
GO

/* ---------- Dynamic Data Masking ---------- */
ALTER TABLE dbo.Cliente  ALTER COLUMN celular_cliente  ADD MASKED WITH (FUNCTION = 'partial(0,"XXXXXX",3)');
ALTER TABLE dbo.Empleado ALTER COLUMN dni_empleado     ADD MASKED WITH (FUNCTION = 'partial(0,"*****",3)');
ALTER TABLE dbo.Empleado ALTER COLUMN celular_empleado ADD MASKED WITH (FUNCTION = 'partial(0,"XXXXXX",3)');
ALTER TABLE dbo.Empleado ALTER COLUMN sueldo_empleado  ADD MASKED WITH (FUNCTION = 'default()');   -- se muestra 0.00
GO

/* ---------- Matriz de permisos efectiva (evidencia) ---------- */
SELECT pr.name AS rol, pe.state_desc AS estado, pe.permission_name AS permiso,
       CASE pe.class WHEN 0 THEN 'DATABASE::' + DB_NAME()
                     WHEN 1 THEN OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id)
                     WHEN 3 THEN 'SCHEMA::' + SCHEMA_NAME(pe.major_id)
                     WHEN 6 THEN 'TYPE::' + TYPE_NAME(pe.major_id) END AS objeto
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name LIKE 'rol[_]%'
ORDER BY pr.name, pe.state_desc, pe.permission_name;
GO
-- Las pruebas de privilegios (EXECUTE AS) están en el script 10 (T-07 a T-10).
