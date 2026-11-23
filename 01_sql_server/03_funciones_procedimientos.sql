/* =====================================================================
   SCRIPT 03 : Funciones y procedimientos almacenados (automatización)
   ---------------------------------------------------------------------
   FUNCIONES
     F1 dbo.fn_MargenProducto(@id)          escalar : margen % de un producto
     F2 dbo.fn_EsVentaRestringida(@fecha)    escalar : 1 si rige ley seca
     F3 dbo.fn_VentasPorPeriodo(@d, @h)      de tabla: ventas por categoría
   PROCEDIMIENTOS (todos con TRY-CATCH + BEGIN TRAN / COMMIT / ROLLBACK)
     P1 dbo.usp_RegistrarVenta        venta + detalle + stock + kardex (TVP)
     P2 dbo.usp_RegistrarPedido       abastecimiento: aumenta stock y cierra alertas
     P3 dbo.usp_GenerarAlertasStock   recorre inventario con CURSOR
     P4 dbo.usp_AnularVenta           anula y repone stock (SAVEPOINT)
     P5 dbo.usp_RecalcularMontosVenta corrige montos mal digitados (CURSOR + SAVEPOINT)
   ===================================================================== */
USE MinimarketDiva;
GO

/* ---------- Tipo tabla: todas las líneas de una venta en una sola llamada ---------- */
IF TYPE_ID(N'dbo.TipoDetalleVenta') IS NULL
    CREATE TYPE dbo.TipoDetalleVenta AS TABLE (
        id_producto INT NOT NULL PRIMARY KEY,           -- un producto una sola vez por venta
        cantidad    INT NOT NULL CHECK (cantidad > 0)
    );
GO
IF TYPE_ID(N'dbo.TipoDetallePedido') IS NULL
    CREATE TYPE dbo.TipoDetallePedido AS TABLE (
        id_producto INT           NOT NULL PRIMARY KEY,
        cantidad    INT           NOT NULL CHECK (cantidad > 0),
        precio_unit DECIMAL(10,2) NOT NULL CHECK (precio_unit > 0)
    );
GO

/* ---------- Apoyo: registra la excepción en la bitácora (llamar DESPUÉS del ROLLBACK) ---------- */
CREATE OR ALTER PROCEDURE auditoria.usp_RegistrarError
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO auditoria.LogErrores (procedimiento, numero_error, mensaje, linea)
    VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE());
END;
GO

/* =====================================================================
   F1. Margen porcentual de un producto = (venta - compra) / venta
   ===================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_MargenProducto (@id_producto INT)
RETURNS DECIMAL(6,2)
AS
BEGIN
    DECLARE @margen DECIMAL(6,2);
    SELECT @margen = CAST(100.0 * (pVenta_producto - pCompra_producto) / NULLIF(pVenta_producto, 0) AS DECIMAL(6,2))
    FROM dbo.Producto WHERE id_producto = @id_producto;
    RETURN @margen;
END;
GO

/* =====================================================================
   F2. ¿La fecha cae en un periodo de ley seca? (1 = sí)
   ===================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_EsVentaRestringida (@fecha DATETIME2(0))
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM dbo.RestriccionVenta
                             WHERE @fecha >= fecha_inicio AND @fecha < fecha_fin) THEN 1 ELSE 0 END;
END;
GO

/* =====================================================================
   F3. Función de tabla: ventas, unidades y margen por categoría en un periodo
   ===================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_VentasPorPeriodo (@desde DATE, @hasta DATE)
RETURNS TABLE
AS
RETURN
    SELECT c.nombre_categoria,
           SUM(d.cantidad_detalleVenta)                                              AS unidades,
           SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta)                 AS ventas,
           SUM(d.cantidad_detalleVenta * (d.precio_unit_detalleVenta - p.pCompra_producto)) AS margen_aprox
    FROM dbo.Venta v
    JOIN dbo.DetalleVenta d ON d.id_venta = v.id_venta
    JOIN dbo.Producto p     ON p.id_producto = d.id_producto
    JOIN dbo.Categoria c    ON c.id_categoria = p.id_categoria
    WHERE v.fecha_venta >= @desde AND v.fecha_venta < DATEADD(DAY, 1, @hasta)
      AND v.estado_venta = 'REGISTRADA'
    GROUP BY c.nombre_categoria;
GO

/* =====================================================================
   P1. usp_RegistrarVenta
   Reglas: (1) cliente, empleado y método de pago existen; (2) no se vende
   alcohol en ley seca; (3) hay stock suficiente (con bloqueo UPDLOCK para
   evitar vender dos veces la última unidad); (4) el precio sale del
   catálogo, no de la caja; (5) monto_venta = suma del detalle.
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarVenta
    @id_cliente    INT,
    @id_metodoPago INT,
    @id_empleado   INT,
    @detalle       dbo.TipoDetalleVenta READONLY,
    @id_venta      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;     -- ante error grave SQL Server revierte toda la transacción
    DECLARE @ahora DATETIME2(0) = SYSDATETIME();

    BEGIN TRY
        -- Validaciones de entrada (antes de abrir la transacción: no bloquean)
        IF NOT EXISTS (SELECT 1 FROM @detalle)
            THROW 50001, 'La venta debe tener al menos un producto.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE id_cliente = @id_cliente)
            THROW 50002, 'El cliente no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE id_empleado = @id_empleado)
            THROW 50003, 'El empleado no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE id_metodoPago = @id_metodoPago)
            THROW 50004, 'El método de pago no existe.', 1;
        IF dbo.fn_EsVentaRestringida(@ahora) = 1
           AND EXISTS (SELECT 1 FROM @detalle d JOIN dbo.Producto p ON p.id_producto = d.id_producto
                       WHERE p.id_categoria IN (1, 2, 3, 4, 6, 7))          -- categorías con alcohol
            THROW 50005, 'Ley seca vigente: no se puede vender bebidas alcohólicas.', 1;

        BEGIN TRANSACTION;

        -- Control de stock con bloqueo de filas
        IF EXISTS (SELECT 1 FROM @detalle d
                   LEFT JOIN dbo.Inventario i WITH (UPDLOCK, HOLDLOCK) ON i.id_producto = d.id_producto
                   WHERE i.id_producto IS NULL OR i.stock_actual_inventario < d.cantidad)
            THROW 50006, 'Stock insuficiente para uno o más productos.', 1;

        -- Cabecera (el monto se calcula después a partir del detalle)
        INSERT INTO dbo.Venta (monto_venta, fecha_venta, id_cliente, id_metodoPago, id_empleado)
        VALUES (0, @ahora, @id_cliente, @id_metodoPago, @id_empleado);
        SET @id_venta = SCOPE_IDENTITY();

        -- Detalle con precio de catálogo
        INSERT INTO dbo.DetalleVenta (cantidad_detalleVenta, precio_unit_detalleVenta, id_venta, id_producto)
        SELECT d.cantidad, p.pVenta_producto, @id_venta, d.id_producto
        FROM @detalle d JOIN dbo.Producto p ON p.id_producto = d.id_producto;

        UPDATE dbo.Venta
           SET monto_venta = (SELECT SUM(cantidad_detalleVenta * precio_unit_detalleVenta)
                              FROM dbo.DetalleVenta WHERE id_venta = @id_venta)
         WHERE id_venta = @id_venta;

        -- Descuento de stock (el trigger trg_Inventario_Alerta genera la alerta si baja del mínimo)
        UPDATE i SET i.stock_actual_inventario = i.stock_actual_inventario - d.cantidad,
                     i.fecha_inventario = CAST(@ahora AS DATE)
        FROM dbo.Inventario i JOIN @detalle d ON d.id_producto = i.id_producto;

        INSERT INTO dbo.MovimientoInventario (id_producto, tipo_movimiento, cantidad, stock_resultante, referencia)
        SELECT d.id_producto, 'SALIDA', d.cantidad, i.stock_actual_inventario, CONCAT('VENTA ', @id_venta)
        FROM @detalle d JOIN dbo.Inventario i ON i.id_producto = d.id_producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;    -- se revierte cabecera, detalle y stock
        EXEC auditoria.usp_RegistrarError;
        THROW;                                     -- se informa el error original a la aplicación
    END CATCH
END;
GO

/* =====================================================================
   P2. usp_RegistrarPedido : compra a proveedor -> aumenta stock
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPedido
    @id_proveedor INT,
    @detalle      dbo.TipoDetallePedido READONLY,
    @id_pedido    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE id_proveedor = @id_proveedor)
            THROW 50010, 'El proveedor no existe.', 1;
        IF EXISTS (SELECT 1 FROM @detalle d JOIN dbo.Inventario i ON i.id_producto = d.id_producto
                   WHERE i.stock_actual_inventario + d.cantidad > i.stock_maximo_inventario * 1.5)
            THROW 50011, 'El pedido supera en más de 50 % el stock máximo permitido.', 1;

        BEGIN TRANSACTION;
            INSERT INTO dbo.Pedido (monto_pedido, fecha_pedido, id_proveedor)
            SELECT SUM(cantidad * precio_unit), SYSDATETIME(), @id_proveedor FROM @detalle;
            SET @id_pedido = SCOPE_IDENTITY();

            INSERT INTO dbo.DetallePedido (cantidad_detallePedido, precio_unit_detallePedido, id_pedido, id_producto)
            SELECT cantidad, precio_unit, @id_pedido, id_producto FROM @detalle;

            UPDATE i SET i.stock_actual_inventario = i.stock_actual_inventario + d.cantidad,
                         i.fecha_inventario = CAST(SYSDATETIME() AS DATE)
            FROM dbo.Inventario i JOIN @detalle d ON d.id_producto = i.id_producto;

            INSERT INTO dbo.MovimientoInventario (id_producto, tipo_movimiento, cantidad, stock_resultante, referencia)
            SELECT d.id_producto, 'INGRESO', d.cantidad, i.stock_actual_inventario, CONCAT('PEDIDO ', @id_pedido)
            FROM @detalle d JOIN dbo.Inventario i ON i.id_producto = d.id_producto;

            -- Se cierran las alertas de los productos que ya superan el mínimo
            UPDATE a SET a.estado_alerta = 'ATENDIDA'
            FROM dbo.AlertaStock a JOIN dbo.Inventario i ON i.id_producto = a.id_producto
            WHERE a.estado_alerta = 'PENDIENTE' AND i.stock_actual_inventario >= i.stock_minimo_inventario
              AND a.id_producto IN (SELECT id_producto FROM @detalle);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC auditoria.usp_RegistrarError;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   P3. usp_GenerarAlertasStock : recorre con CURSOR el inventario bajo el
   mínimo y crea una alerta por producto si no hay una PENDIENTE.
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_GenerarAlertasStock
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @prod INT, @stock INT, @minimo INT, @generadas INT = 0;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE curAlertas CURSOR LOCAL FAST_FORWARD FOR
            SELECT id_producto, stock_actual_inventario, stock_minimo_inventario
            FROM dbo.Inventario WHERE stock_actual_inventario < stock_minimo_inventario;
        OPEN curAlertas;
        FETCH NEXT FROM curAlertas INTO @prod, @stock, @minimo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.AlertaStock WHERE id_producto = @prod AND estado_alerta = 'PENDIENTE')
            BEGIN
                INSERT INTO dbo.AlertaStock (id_producto, stock_actual, stock_minimo) VALUES (@prod, @stock, @minimo);
                SET @generadas += 1;
            END
            FETCH NEXT FROM curAlertas INTO @prod, @stock, @minimo;
        END
        CLOSE curAlertas; DEALLOCATE curAlertas;
        COMMIT TRANSACTION;
        SELECT @generadas AS alertas_generadas;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'curAlertas') >= 0 CLOSE curAlertas;
        IF CURSOR_STATUS('local', 'curAlertas') >= -1 DEALLOCATE curAlertas;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC auditoria.usp_RegistrarError;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   P4. usp_AnularVenta : anula (no borra) y devuelve el stock.
   SAVEPOINT: si falla el registro del motivo, se conserva la anulación.
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_AnularVenta
    @id_venta INT,
    @motivo   NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Venta WHERE id_venta = @id_venta AND estado_venta = 'REGISTRADA')
            THROW 50020, 'La venta no existe o ya está anulada.', 1;

        BEGIN TRANSACTION;
            UPDATE i SET i.stock_actual_inventario = i.stock_actual_inventario + d.cantidad_detalleVenta
            FROM dbo.Inventario i JOIN dbo.DetalleVenta d ON d.id_producto = i.id_producto
            WHERE d.id_venta = @id_venta;

            INSERT INTO dbo.MovimientoInventario (id_producto, tipo_movimiento, cantidad, stock_resultante, referencia)
            SELECT d.id_producto, 'INGRESO', d.cantidad_detalleVenta, i.stock_actual_inventario, CONCAT('ANULA VENTA ', @id_venta)
            FROM dbo.DetalleVenta d JOIN dbo.Inventario i ON i.id_producto = d.id_producto
            WHERE d.id_venta = @id_venta;

            UPDATE dbo.Venta SET estado_venta = 'ANULADA' WHERE id_venta = @id_venta;   -- auditado por trigger

            SAVE TRANSACTION PuntoAnulacion;           -- lo esencial ya está hecho

            BEGIN TRY                                  -- paso secundario: guardar el motivo
                INSERT INTO auditoria.RegistroAuditoria (tabla, operacion, clave_registro, datos_nuevos)
                VALUES (N'dbo.Venta', 'UPDATE', CAST(@id_venta AS VARCHAR(50)),
                        (SELECT @motivo AS motivo_anulacion FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
            END TRY
            BEGIN CATCH
                IF XACT_STATE() = 1 ROLLBACK TRANSACTION PuntoAnulacion;   -- rollback PARCIAL
                EXEC auditoria.usp_RegistrarError;
            END CATCH
        COMMIT TRANSACTION;
        PRINT CONCAT('Venta ', @id_venta, ' anulada y stock repuesto.');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC auditoria.usp_RegistrarError;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   P5. usp_RecalcularMontosVenta : corrige monto_venta cuando no coincide
   con la suma del detalle (hallazgo de calidad en los datos originales).
   CURSOR fila por fila + SAVEPOINT por venta: si una corrección falla,
   solo esa se revierte y el proceso continúa con las demás.
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_RecalcularMontosVenta
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @correcto DECIMAL(10,2), @corregidas INT = 0, @fallidas INT = 0;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE curMontos CURSOR LOCAL FAST_FORWARD FOR
            SELECT v.id_venta, SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta)
            FROM dbo.Venta v JOIN dbo.DetalleVenta d ON d.id_venta = v.id_venta
            GROUP BY v.id_venta, v.monto_venta
            HAVING v.monto_venta <> SUM(d.cantidad_detalleVenta * d.precio_unit_detalleVenta);
        OPEN curMontos;
        FETCH NEXT FROM curMontos INTO @id, @correcto;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SAVE TRANSACTION AntesDeCorregir;
            BEGIN TRY
                UPDATE dbo.Venta SET monto_venta = @correcto WHERE id_venta = @id;   -- trigger audita antes/después
                SET @corregidas += 1;
            END TRY
            BEGIN CATCH
                IF XACT_STATE() = 1 ROLLBACK TRANSACTION AntesDeCorregir;
                SET @fallidas += 1;
                EXEC auditoria.usp_RegistrarError;
            END CATCH
            FETCH NEXT FROM curMontos INTO @id, @correcto;
        END
        CLOSE curMontos; DEALLOCATE curMontos;
        COMMIT TRANSACTION;
        SELECT @corregidas AS ventas_corregidas, @fallidas AS ventas_con_error;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'curMontos') >= 0 CLOSE curMontos;
        IF CURSOR_STATUS('local', 'curMontos') >= -1 DEALLOCATE curMontos;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC auditoria.usp_RegistrarError;
        THROW;
    END CATCH
END;
GO

PRINT 'Script 03 completado: 3 funciones y 5 procedimientos. Ejecute el script 04 (triggers) y luego las pruebas del script 10.';
