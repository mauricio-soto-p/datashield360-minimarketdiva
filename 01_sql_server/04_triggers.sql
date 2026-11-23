/* =====================================================================
   SCRIPT 04 : Triggers de auditoría y automatización
   ---------------------------------------------------------------------
   T1 trg_Auditoria_Cliente      AFTER INSERT/UPDATE/DELETE  (datos personales - Ley 29733)
   T2 trg_Auditoria_Producto     AFTER INSERT/UPDATE/DELETE  (precios de venta y compra)
   T3 trg_Auditoria_Venta        AFTER UPDATE                (monto y estado de la venta)
   T4 trg_Venta_ProtegerBorrado  INSTEAD OF DELETE           (las ventas no se borran)
   T5 trg_Inventario_Alerta      AFTER UPDATE                (alerta automática de reposición)
   Las filas afectadas se guardan en JSON en auditoria.RegistroAuditoria.
   ===================================================================== */
USE MinimarketDiva;
GO

/* ---------- T1. CLIENTE ---------- */
CREATE OR ALTER TRIGGER dbo.trg_Auditoria_Cliente
ON dbo.Cliente
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    BEGIN TRY
        -- La operación se deduce de las tablas virtuales inserted / deleted
        DECLARE @op CHAR(6) = CASE WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
                                   WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT' ELSE 'DELETE' END;
        INSERT INTO auditoria.RegistroAuditoria (tabla, operacion, clave_registro, datos_anteriores, datos_nuevos)
        SELECT N'dbo.Cliente', @op, CAST(COALESCE(i.id_cliente, d.id_cliente) AS VARCHAR(50)),
               (SELECT d.id_cliente, d.nombre_cliente, d.ape_pat_cliente, d.ape_mat_cliente, d.celular_cliente
                  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.id_cliente, i.nombre_cliente, i.ape_pat_cliente, i.ape_mat_cliente, i.celular_cliente
                  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i FULL OUTER JOIN deleted d ON d.id_cliente = i.id_cliente;   -- una fila por cliente afectado
    END TRY
    BEGIN CATCH
        -- Sin rastro de auditoría no se permite la operación
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50100, 'No se pudo auditar el cambio en Cliente. Operación revertida.', 1;
    END CATCH
END;
GO

/* ---------- T2. PRODUCTO (solo cambios de nombre o precios) ---------- */
CREATE OR ALTER TRIGGER dbo.trg_Auditoria_Producto
ON dbo.Producto
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    BEGIN TRY
        DECLARE @op CHAR(6) = CASE WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
                                   WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT' ELSE 'DELETE' END;
        IF @op = 'UPDATE' AND NOT (UPDATE(pVenta_producto) OR UPDATE(pCompra_producto) OR UPDATE(nombre_producto)) RETURN;

        INSERT INTO auditoria.RegistroAuditoria (tabla, operacion, clave_registro, datos_anteriores, datos_nuevos)
        SELECT N'dbo.Producto', @op, CAST(COALESCE(i.id_producto, d.id_producto) AS VARCHAR(50)),
               (SELECT d.id_producto, d.nombre_producto, d.pVenta_producto, d.pCompra_producto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.id_producto, i.nombre_producto, i.pVenta_producto, i.pCompra_producto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i FULL OUTER JOIN deleted d ON d.id_producto = i.id_producto
        WHERE @op <> 'UPDATE' OR i.pVenta_producto <> d.pVenta_producto
           OR i.pCompra_producto <> d.pCompra_producto OR i.nombre_producto <> d.nombre_producto;

        -- Control: rebaja de precio de venta > 20 % en un solo cambio
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.id_producto = i.id_producto
                   WHERE i.pVenta_producto < d.pVenta_producto * 0.80)
            PRINT 'ADVERTENCIA: rebaja de precio mayor al 20 %. Requiere visto bueno del Administrador.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50101, 'No se pudo auditar el cambio en Producto. Operación revertida.', 1;
    END CATCH
END;
GO

/* ---------- T3. VENTA: cambios de monto o estado ---------- */
CREATE OR ALTER TRIGGER dbo.trg_Auditoria_Venta
ON dbo.Venta
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(monto_venta) OR UPDATE(estado_venta)) RETURN;
    -- No se audita el ajuste interno 0 -> monto que hace usp_RegistrarVenta al crear la venta
    INSERT INTO auditoria.RegistroAuditoria (tabla, operacion, clave_registro, datos_anteriores, datos_nuevos)
    SELECT N'dbo.Venta', 'UPDATE', CAST(i.id_venta AS VARCHAR(50)),
           (SELECT d.monto_venta, d.estado_venta FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT i.monto_venta, i.estado_venta FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i JOIN deleted d ON d.id_venta = i.id_venta
    WHERE (i.monto_venta <> d.monto_venta AND d.monto_venta <> 0) OR i.estado_venta <> d.estado_venta;
END;
GO

/* ---------- T4. VENTA: bloqueo del borrado físico (comprobante tributario) ---------- */
CREATE OR ALTER TRIGGER dbo.trg_Venta_ProtegerBorrado
ON dbo.Venta
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO auditoria.RegistroAuditoria (tabla, operacion, clave_registro, datos_anteriores, datos_nuevos)
    SELECT N'dbo.Venta', 'DELETE', CAST(d.id_venta AS VARCHAR(50)),
           (SELECT d.id_venta, d.fecha_venta, d.monto_venta, d.estado_venta FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           N'{"resultado":"BLOQUEADO - use dbo.usp_AnularVenta"}'
    FROM deleted d;
    PRINT 'Las ventas no se eliminan: use dbo.usp_AnularVenta. El intento quedó auditado.';
    -- No se ejecuta ningún DELETE real
END;
GO

/* ---------- T5. INVENTARIO: alerta automática cuando el stock cae bajo el mínimo ---------- */
CREATE OR ALTER TRIGGER dbo.trg_Inventario_Alerta
ON dbo.Inventario
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(stock_actual_inventario) RETURN;
    INSERT INTO dbo.AlertaStock (id_producto, stock_actual, stock_minimo)
    SELECT i.id_producto, i.stock_actual_inventario, i.stock_minimo_inventario
    FROM inserted i
    JOIN deleted d ON d.id_inventario = i.id_inventario
    WHERE i.stock_actual_inventario < i.stock_minimo_inventario      -- quedó bajo el mínimo
      AND d.stock_actual_inventario >= d.stock_minimo_inventario     -- y antes no lo estaba (evita duplicar)
      AND NOT EXISTS (SELECT 1 FROM dbo.AlertaStock a
                      WHERE a.id_producto = i.id_producto AND a.estado_alerta = 'PENDIENTE');
END;
GO

PRINT 'Script 04 completado: 5 triggers creados.';
SELECT t.name AS trigger_name, OBJECT_NAME(t.parent_id) AS tabla, t.is_instead_of_trigger
FROM sys.triggers t WHERE t.parent_class = 1 ORDER BY tabla;
