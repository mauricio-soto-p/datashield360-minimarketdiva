Select * From Cliente

Select * From DetalleVenta

-- Consulta básica SELECT
SELECT * FROM Producto

-- Consulta básica WHERE
SELECT P.nombre_producto, P.pVenta_producto FROM Producto P 
INNER JOIN Categoria C 
ON P.id_categoria = C.id_categoria 
WHERE C.nombre_categoria = 'Cerveza';

-- Consulta básica ORDER BY
SELECT nombre_producto, pVenta_producto FROM Producto 
ORDER BY pVenta_producto DESC;

-- Consulta intermedia JOIN
SELECT
    V.id_venta,
    C.nombre_cliente + ' ' + c.ape_pat_cliente AS cliente,
    E.nombre_empleado AS atendido_por,
    P.nombre_producto,
    DV.cantidad_detalleVenta,
    DV.precio_unit_detalleVenta
FROM Venta V
INNER JOIN Cliente C
ON V.id_cliente = C.id_cliente
INNER JOIN Empleado E
ON V.id_empleado = E.id_empleado
INNER JOIN DetalleVenta DV
ON V.id_venta = DV.id_venta
INNER JOIN Producto P
ON DV.id_producto = P.id_producto
ORDER BY V.id_venta;

-- Consulta intermedia GROUP BY
SELECT C.nombre_categoria, COUNT(*) AS total_productos FROM Producto P 
INNER JOIN Categoria C 
ON P.id_categoria = C.id_categoria 
GROUP BY C.nombre_categoria 
ORDER BY total_productos DESC;

-- Consulta intermedia HAVING
SELECT C.nombre_categoria, COUNT(*) AS total_productos FROM Producto P
INNER JOIN Categoria C 
ON P.id_categoria = C.id_categoria 
GROUP BY C.nombre_categoria 
HAVING COUNT(*) > 1;

-- Consulta avanzada con subconsulta
SELECT nombre_producto, pVenta_producto FROM Producto 
WHERE pVenta_producto > (SELECT AVG(pVenta_producto) FROM Producto) 
ORDER BY pVenta_producto DESC;

-- Consulta avanzada para crear una Vista
CREATE VIEW vista_ventas_cliente AS
SELECT C.id_cliente, C.nombre_cliente + ' ' + C.ape_pat_cliente AS cliente, 
SUM(DV.cantidad_detalleVenta * DV.precio_unit_detalleVenta) AS total_comprado 
FROM Cliente C 
INNER JOIN Venta V 
ON C.id_cliente = V.id_cliente 
INNER JOIN DetalleVenta DV 
ON V.id_venta = DV.id_venta 
GROUP BY C.id_cliente, C.nombre_cliente, C.ape_pat_cliente; 

SELECT * FROM vista_ventas_cliente ORDER BY total_comprado DESC;

-- Consulta avanzada para funciones agregadas
SELECT C.nombre_categoria, 
COUNT(P.id_producto) AS num_productos, 
AVG(P.pVenta_producto) AS precio_promedio, 
MIN(P.pVenta_producto) AS precio_minimo, 
MAX(P.pVenta_producto) AS precio_maximo 
FROM Producto P 
INNER JOIN Categoria C 
ON P.id_categoria = C.id_categoria 
GROUP BY C.nombre_categoria;

-- Consulta para toma de decisiones 1
SELECT TOP 5 C.nombre_cliente + ' ' + C.ape_pat_cliente AS cliente, 
SUM(V.monto_venta) AS total_gastado 
FROM Cliente C
INNER JOIN Venta V 
ON C.id_cliente = V.id_cliente
GROUP BY C.id_cliente, C.nombre_cliente, C.ape_pat_cliente 
ORDER BY total_gastado DESC;


-- Consulta para toma de decisiones 2
SELECT P.nombre_producto, I.stock_actual_inventario, I.stock_minimo_inventario FROM Inventario I 
INNER JOIN Producto P 
ON I.id_producto = P.id_producto 
WHERE I.stock_actual_inventario <= I.stock_minimo_inventario;

-- Consulta para toma de decisiones 3
SELECT C.nombre_categoria, SUM(DV.cantidad_detalleVenta * DV.precio_unit_detalleVenta) AS ingresos FROM DetalleVenta DV
INNER JOIN Producto P 
ON DV.id_producto = P.id_producto 
INNER JOIN Categoria C 
ON P.id_categoria = C.id_categoria 
GROUP BY C.nombre_categoria 
ORDER BY ingresos DESC;


-- Consulta para toma de decisiones 4
SELECT PV.nombre_proveedor, SUM(PE.monto_pedido) AS total_pedido FROM Pedido PE
INNER JOIN Proveedor PV
ON PE.id_proveedor = PV.id_proveedor 
GROUP BY PV.nombre_proveedor 
ORDER BY total_pedido DESC;

-- Consulta para toma de decisiones 5
SELECT E.nombre_empleado + ' ' + E.ape_pat_empleado AS empleado, 
COUNT(V.id_venta) AS ventas_atendidas, 
SUM(V.monto_venta) AS monto_total 
FROM Empleado E
INNER JOIN Venta V
ON E.id_empleado = V.id_empleado 
GROUP BY E.id_empleado, E.nombre_empleado, E.ape_pat_empleado 
ORDER BY monto_total DESC;

-- Procedimiento almacenado 1
CREATE PROCEDURE RegistrarVenta 
    @id_cliente INT, 
    @id_metodoPago INT, 
    @id_empleado INT, 
    @id_producto INT, 
    @cantidad INT 
AS 
    BEGIN 
        SET NOCOUNT ON; 
        DECLARE @precio DECIMAL(10,2); 
        DECLARE @id_venta INT; 
        
        SELECT @precio = pVenta_producto 
        FROM Producto 
        WHERE id_producto = @id_producto; 
        
        INSERT INTO Venta (monto_venta, fecha_venta, id_cliente, id_metodoPago, id_empleado) 
        VALUES (@precio * @cantidad, GETDATE(), @id_cliente, @id_metodoPago, @id_empleado); 
        
        SET @id_venta = SCOPE_IDENTITY(); 
        
        INSERT INTO DetalleVenta (cantidad_detalleVenta, precio_unit_detalleVenta, id_venta, id_producto) 
        VALUES (@cantidad, @precio, @id_venta, @id_producto); 
        
        UPDATE Inventario 
        SET stock_actual_inventario = stock_actual_inventario - @cantidad 
        WHERE id_producto = @id_producto; 
        
        SELECT @id_venta AS id_venta_generada; 
    END; 
GO 

-- Ejemplo de ejecución: 
EXECUTE RegistrarVenta 
    @id_cliente = 1, 
    @id_metodoPago = 1,  
    @id_empleado = 1, 
    @id_producto = 1, 
    @cantidad = 3;

Select * From Venta
Where id_venta = 16


-- Procedimiento almacenado 2
CREATE PROCEDURE RegistrarPedido 
    @id_proveedor INT, 
    @id_producto INT, 
    @cantidad INT, 
    @precio_unit DECIMAL(10,2) 
    
AS 
    BEGIN 
        SET NOCOUNT ON; 
        DECLARE @id_pedido INT; 
        
        INSERT INTO Pedido (monto_pedido, fecha_pedido, id_proveedor) 
        VALUES (@precio_unit * @cantidad, GETDATE(), @id_proveedor); 
        
        SET @id_pedido = SCOPE_IDENTITY(); 
        
        INSERT INTO DetallePedido (cantidad_detallePedido, precio_unit_detallePedido, id_pedido, id_producto) 
        VALUES (@cantidad, @precio_unit, @id_pedido, @id_producto); 
        
        SELECT @id_pedido AS id_pedido_generado; 
        
    END; 
GO 

-- Ejemplo de ejecución: 
EXECUTE RegistrarPedido 
    @id_proveedor = 1, 
    @id_producto = 1, 
    @cantidad = 20, 
    @precio_unit = 6.20;

Select * From Pedido
Where id_pedido = 11


-- Función 1
CREATE FUNCTION CalcularTotalVenta (@id_venta INT) 
RETURNS DECIMAL(10,2) 
AS 
    BEGIN 
        DECLARE @total DECIMAL(10,2); 
        
        SELECT @total = SUM(cantidad_detalleVenta * precio_unit_detalleVenta) 
        FROM DetalleVenta 
        WHERE id_venta = @id_venta; 
        
        RETURN ISNULL(@total,0); 
    END; 
GO 

-- Ejemplo de ejecución: 
SELECT dbo.CalcularTotalVenta(1);
SELECT * FROM DetalleVenta
WHERE id_venta = 1;

-- Función 2
CREATE FUNCTION ClasificarStock (@id_producto INT) 
RETURNS VARCHAR(20) 
AS 
    BEGIN 
        DECLARE @stock INT; 
        DECLARE @stock_min INT; 
        DECLARE @resultado VARCHAR(20); 
        
        SELECT @stock = stock_actual_inventario, @stock_min = stock_minimo_inventario FROM Inventario 
        WHERE id_producto = @id_producto; 
        IF @stock IS NULL SET @resultado = 'Sin inventario'; 
        ELSE IF @stock = 0 SET @resultado = 'Agotado'; 
        ELSE IF @stock <= @stock_min SET @resultado = 'Stock bajo'; 
        ELSE SET @resultado = 'Stock normal'; 
        RETURN @resultado; 
    END; 
GO 

-- Ejemplo de ejecución:  
SELECT nombre_producto, 
    dbo.ClasificarStock(id_producto) AS estado_stock
FROM Producto;

-- Establecer respaldo
BACKUP DATABASE MinimarketDiva
TO DISK = 'C:\Backup\MinimarketDiva.bak';

-- Restaurar base de datos
RESTORE DATABASE MinimarketDiva
FROM DISK = 'C:\Backup\MinimarketDiva.bak';