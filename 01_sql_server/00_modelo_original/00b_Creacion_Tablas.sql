Create Table Cliente (
	id_cliente INT Primary Key Identity(1,1),
	nombre_cliente VARCHAR(30) Not Null,
	ape_pat_cliente VARCHAR(30) Not Null,
	ape_mat_cliente VARCHAR(30) Not Null,
	celular_cliente VARCHAR(9) Not Null
);

Create Table Categoria (
	id_categoria INT Primary Key Identity (1,1),
	nombre_categoria VARCHAR(50) Not Null	
);

Create Table Producto (
	id_producto INT Primary Key Identity(1,1),
	nombre_producto VARCHAR(80) Not Null,	
	pVenta_producto DECIMAL(10,2) Not Null,
	pCompra_producto DECIMAL(10,2) Not Null,

	id_categoria INT Not Null
	Constraint FK_Producto_Categoria
	Foreign Key (id_categoria)
	References Categoria(id_categoria)
);


Create Table MetodoPago (
	id_metodoPago INT Primary Key Identity (1,1),
	tipo_metodoPago VARCHAR(30) Not Null
);

Create Table Empleado (
	id_empleado INT Primary Key Identity (1,1),
	nombre_empleado VARCHAR(30) Not Null,
	ape_pat_empleado VARCHAR(30) Not Null,
	ape_mat_empleado VARCHAR(30) Not Null,
	turno_empleado VARCHAR(10) Not Null,
	sueldo_empleado DECIMAL(10,2) Not Null,
	dni_empleado VARCHAR(8) UNIQUE Not Null,
	celular_empleado VARCHAR(9) Not Null,
	cargo_empleado VARCHAR(30) Not Null
);

Create Table Venta (
	id_venta INT Primary Key Identity(1,1),
	monto_venta DECIMAL(10,2) Not Null,
	fecha_venta DATETIME Not Null,

	id_cliente INT Not Null,
	id_metodoPago INT Not Null,
	id_empleado INT Not Null,

	Constraint FK_Venta_Cliente
	Foreign Key (id_cliente)
	References Cliente(id_cliente),

	
	Constraint FK_Venta_MetodoPago
	Foreign Key (id_metodoPago)
	References MetodoPago(id_metodoPago),

	Constraint FK_Venta_Empleado
	Foreign Key (id_empleado)
	References Empleado(id_empleado)
);

Create Table DetalleVenta(
	id_detalleVenta INT Primary Key Identity(1,1),
	cantidad_detalleVenta INT Not Null,
	precio_unit_detalleVenta DECIMAL(10,2) Not Null,
	
	id_venta INT Not Null,
	id_producto INT Not Null,

	Constraint FK_DetalleVenta_Venta
	Foreign Key (id_venta)
	References Venta(id_venta),

	Constraint FK_DetalleVenta_Producto
	Foreign Key (id_producto)
	References Producto(id_producto)
);

Create Table Proveedor (
	id_proveedor INT Primary Key Identity (1,1),
	nombre_proveedor VARCHAR(30) Not Null,
	celular_proveedor VARCHAR(9) Not Null,
	correo_proveedor VARCHAR(50) UNIQUE Not Null
);

Create Table Pedido (
	id_pedido INT Primary Key Identity (1,1),
	monto_pedido DECIMAL(10,2) Not Null,
	fecha_pedido DATETIME Not Null,

	id_proveedor INT Not Null,
	Constraint FK_Pedido_Proveedor
	Foreign Key (id_proveedor)
	References Proveedor(id_proveedor)
);


Create Table DetallePedido(
	id_detallePedido INT Primary KEy Identity (1,1),
	cantidad_detallePedido INT Not Null,
	precio_unit_detallePedido DECIMAL (10,2) Not Null,
	
	id_pedido INT Not Null,
	id_producto INT Not Null,

	Constraint FK_DetallePedido_Pedido
	Foreign Key (id_pedido)
	References Pedido(id_pedido),

	Constraint FK_DetallePedido_Producto
	Foreign Key (id_producto)
	References Producto(id_producto)
);

Create Table Inventario (
	id_inventario INT Primary Key Identity (1,1),
	stock_actual_inventario INT Not Null,
	stock_minimo_inventario INT Not Null,
	stock_maximo_inventario INT Not Null,
	fecha_inventario DATE Not Null,

	id_producto INT UNIQUE Not Null,

	Constraint FK_Inventario_Producto
	Foreign Key (id_producto)
	References Producto(id_producto)	
);