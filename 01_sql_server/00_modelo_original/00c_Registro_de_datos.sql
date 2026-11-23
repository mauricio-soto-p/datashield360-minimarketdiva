INSERT INTO Categoria (nombre_categoria)
VALUES	('Cerveza'),
		('Ron'), 
		('Pisco'), 
		('Whiskey'),
		('Gaseosa'),
		('Vino'),
		('Champán'),
		('Hielo'),
		('Cigarrillos')

INSERT INTO Producto (nombre_producto, pVenta_producto, pCompra_producto, id_categoria)
VALUES	('Cristal 620 ml', 8.50, 6.20, 1),
		('Pilsen Trujillo', 9.00, 6.50, 1),
		('Ron Cartavio Black', 45.00, 35.00, 2),
		('Ron Bacardí Blanco', 58.00, 46.00, 2),
		('Pisco Queirolo', 42.00, 33.00, 3),
		('Pisco Tabernero', 39.00, 31.00, 3),
		('Johnnie Walker Red', 95.00, 78.00, 4),
		('Jack Daniels', 145.00, 120.00, 4),
		('Coca-Cola 3 L', 12.50, 9.80, 5),
		('Guaraná 3 L', 8.50, 5.70, 5),
		('Vino Tabernero Borgoña', 28.00, 22.00, 6),
		('Champán Ricadonna', 75.00, 60.00, 7),
		('Bolsa de hielo 5 kg', 7.00, 4.50, 8),
		('Lucky Strike', 22.00, 17.50, 9);

INSERT INTO Inventario (stock_actual_inventario, stock_minimo_inventario, stock_maximo_inventario, fecha_inventario, id_producto)
VALUES	(80, 20, 120, '2026-06-28', 1),
		(70, 20, 120, '2026-06-28', 2),
		(35, 10, 60, '2026-06-28', 3),
		(25, 10, 50, '2026-06-28', 4),
		(30, 10, 50, '2026-06-28', 5),
		(28, 10, 50, '2026-06-28', 6),
		(15, 5, 30, '2026-06-28', 7),
		(12, 5, 25, '2026-06-28', 8),
		(50, 15, 80, '2026-06-28', 9),
		(45, 15, 80, '2026-06-28', 10),
		(18, 5, 40, '2026-06-28', 11),
		(10, 3, 20, '2026-06-28', 12),
		(100, 30, 150, '2026-06-28', 13),
		(40, 10, 70, '2026-06-28', 14);

INSERT INTO Proveedor (nombre_proveedor, celular_proveedor, correo_proveedor)
VALUES	('Backus', '987654321', 'ventas@backus.com'),
		('Diageo Perú', '986543210', 'contacto@diageo.pe'),
		('Bodega San Isidro', '985432109', 'ventas@bodegasanisidro.com'),
		('Distribuidora El Trigal', '984321098', 'pedidos@eltrigal.com'),
		('Tabernero', '983210987', 'ventas@tabernero.com'),
		('La Ibérica Distribuciones', '982109876', 'contacto@laiberica.com'),
		('Importadora Los Andes', '981098765', 'pedidos@losandes.com'),
		('Comercial Santa Rosa', '980987654', 'ventas@santarosa.com');

INSERT INTO Pedido
(monto_pedido, fecha_pedido, id_proveedor)
VALUES	(584.00, '2026-01-10', 1),   -- 20*6.20 + 10*35 + 5*22
		(1004.00,'2026-01-18', 2),   -- 5×120 + 4*46 + 10*22
		(1039.50,'2026-02-05', 3),   -- 8×78 + 10×33 + 15×5.70
		(925.00, '2026-02-20', 4),   -- 15×35 + 10×31 + 20×4.50
		(786.00, '2026-03-08', 5),   -- 6×60 + 5×46 + 20×9.80
		(1087.00,'2026-03-22', 6),   -- 5×120 + 4×78 + 10×17.50
		(795.00, '2026-04-06', 7),   -- 10×33 + 15×22 + 30×4.50
		(802.50, '2026-04-27', 8),   -- 25×6.50 + 15×31 + 10×17.50
		(755.00, '2026-05-10', 2),   -- 8×46 + 5×35 + 20×5.70 + 10×9.80
		(1068.00,'2026-05-25', 1);   -- 6×78 + 5×60 + 8×22 + 20×6.20

INSERT INTO DetallePedido(cantidad_detallePedido, precio_unit_detallePedido, id_pedido, id_producto)
VALUES
-- Pedido 1
(20, 6.20, 1, 1),
(10, 35.00, 1, 3),
(5, 22.00, 1, 11),

-- Pedido 2
(5, 120.00, 2, 8),
(4, 46.00, 2, 4),
(10, 22.00, 2, 11),

-- Pedido 3
(8, 78.00, 3, 7),
(10, 33.00, 3, 5),
(15, 5.70, 3, 10),

-- Pedido 4
(15, 35.00, 4, 3),
(10, 31.00, 4, 6),
(20, 4.50, 4, 13),

-- Pedido 5
(6, 60.00, 5, 12),
(5, 46.00, 5, 4),
(20, 9.80, 5, 9),

-- Pedido 6
(5, 120.00, 6, 8),
(4, 78.00, 6, 7),
(10, 17.50, 6, 14),

-- Pedido 7
(10, 33.00, 7, 5),
(15, 22.00, 7, 11),
(30, 4.50, 7, 13),

-- Pedido 8
(25, 6.50, 8, 2),
(15, 31.00, 8, 6),
(10, 17.50, 8, 14),

-- Pedido 9
(8, 46.00, 9, 4),
(5, 35.00, 9, 3),
(20, 5.70, 9, 10),
(10, 9.80, 9, 9),

-- Pedido 10
(6, 78.00, 10, 7),
(5, 60.00, 10, 12),
(8, 22.00, 10, 11),
(20, 6.20, 10, 1);


INSERT INTO Cliente(nombre_cliente, ape_pat_cliente, ape_mat_cliente, celular_cliente)
VALUES	('Juan', 'Pérez', 'García', '987654321'),
		('María', 'López', 'Torres', '986543210'),
		('Carlos', 'Ramírez', 'Vega', '985432109'),
		('Ana', 'Flores', 'Rojas', '984321098'),
		('Luis', 'Castillo', 'Sánchez', '983210987'),
		('Rosa', 'Mendoza', 'Quispe', '982109876'),
		('Jorge', 'Salazar', 'Morales', '981098765'),
		('Patricia', 'Navarro', 'Cruz', '980987654'),
		('Miguel', 'Herrera', 'Silva', '979876543'),
		('Carmen', 'Gutiérrez', 'Reyes', '978765432'),
		('Diego', 'Vásquez', 'Campos', '977654321'),
		('Lucía', 'Espinoza', 'Paredes', '976543210');

INSERT INTO Empleado(nombre_empleado,ape_pat_empleado,ape_mat_empleado,turno_empleado,sueldo_empleado,dni_empleado,celular_empleado,cargo_empleado)
VALUES	('José', 'Fernández', 'Ruiz', 'Mañana', 1800.00, '73456128', '965432187', 'Vendedor'),
		('Andrea', 'Cárdenas', 'León', 'Noche', 1800.00, '74561239', '964321876', 'Vendedor'),
		('Ricardo', 'Suárez', 'Ponce', 'Noche', 2000.00, '75612340', '963210765', 'Supervisor'),
		('Katherine', 'Medina', 'Salas', 'Mañana', 1700.00, '76723451', '962109654', 'Cajero'),
		('Fernando', 'Ríos', 'Ortega', 'Mañana', 2200.00, '77834562', '961098543', 'Administrador'),
		('Paola', 'Delgado', 'Fuentes', 'Noche', 1700.00, '78945673', '960987432', 'Cajero');

INSERT INTO MetodoPago(tipo_metodoPago)
VALUES	('Efectivo'),
		('Tarjeta'),
		('Yape'),
		('Plin'),
		('Transferencia');

INSERT INTO Venta(monto_venta, fecha_venta, id_cliente, id_metodoPago, id_empleado)
VALUES	(129.00, '2026-06-01 10:15:00', 1, 1, 1), -- (6×8.50) + (2×12.50) + (2×7.00)
		(118.00, '2026-06-02 11:00:00', 2, 2, 2), -- (2×45.00) + (1×28.00)
		(220.00, '2026-06-03 12:00:00', 3, 3, 3), -- (1×145.00) + (1×75.00)
		(193.50, '2026-06-04 13:00:00', 4, 1, 1), -- (2×58.00) + (1×42.00) + (3×8.50)
		(139.00, '2026-06-05 14:00:00', 5, 2, 2), -- (1×95.00) + (2×22.00)
		(178.50, '2026-06-06 15:00:00', 6, 3, 4), -- (2×39.00) + (1×33.00) + (3×12.50)
		(55.50, '2026-06-07 16:00:00', 7, 1, 5), -- (3×9.00) + (2×8.50)
		(155.00, '2026-06-08 17:00:00', 8, 2, 1), -- (2×45.00) + (1×58.00) + (1×7.00)
		(253.50, '2026-06-09 18:00:00', 9, 3, 2), -- (1×120.00) + (1×78.00) + (2×17.50)
		(98.00, '2026-06-10 19:00:00', 10, 1, 3), -- (3×8.50) + (2×12.50) + (1×22.00)
		(254.00, '2026-06-11 20:00:00', 11, 2, 4), -- (2×75.00) + (2×28.00) + (2×9.00)
		(178.50, '2026-06-12 21:00:00', 12, 3, 1), -- (1×95.00) + (1×42.00) + (3×8.50)
		(155.00, '2026-06-13 10:30:00', 1, 1, 2), -- (2×58.00) + (1×39.00)
		(190.00, '2026-06-14 11:30:00', 2, 2, 3), -- (1×145.00) + (1×45.00)
		(99.50, '2026-06-15 12:30:00', 3, 3, 4); -- (2×22.00) + (3×8.50) + (1×12.50)

INSERT INTO DetalleVenta(cantidad_detalleVenta, precio_unit_detalleVenta, id_venta, id_producto)
VALUES
-- VENTA 1
(6, 8.50, 1, 1),
(2, 12.50, 1, 9),
(2, 7.00, 1, 13),

-- VENTA 2
(2, 45.00, 2, 3),
(1, 28.00, 2, 11),

-- VENTA 3
(1, 145.00, 3, 8),
(1, 75.00, 3, 12),

-- VENTA 4
(2, 58.00, 4, 4),
(1, 42.00, 4, 5),
(3, 8.50, 4, 10),

-- VENTA 5
(1, 95.00, 5, 7),
(2, 22.00, 5, 14),

-- VENTA 6
(2, 39.00, 6, 6),
(1, 33.00, 6, 5),
(3, 12.50, 6, 9),

-- VENTA 7
(3, 9.00, 7, 2),
(2, 8.50, 7, 1),

-- VENTA 8
(2, 45.00, 8, 3),
(1, 58.00, 8, 4),
(1, 7.00, 8, 13),

-- VENTA 9
(1, 120.00, 9, 8),
(1, 78.00, 9, 7),
(2, 17.50, 9, 14),

-- VENTA 10
(3, 8.50, 10, 1),
(2, 12.50, 10, 9),
(1, 22.00, 10, 14),

-- VENTA 11
(2, 75.00, 11, 12),
(2, 28.00, 11, 11),
(2, 9.00, 11, 2),

-- VENTA 12
(1, 95.00, 12, 7),
(1, 42.00, 12, 5),
(3, 8.50, 12, 10),

-- VENTA 13
(2, 58.00, 13, 4),
(1, 39.00, 13, 6),

-- VENTA 14
(1, 145.00, 14, 8),
(1, 45.00, 14, 3),

-- VENTA 15
(2, 22.00, 15, 14),
(3, 8.50, 15, 1),
(1, 12.50, 15, 9);









