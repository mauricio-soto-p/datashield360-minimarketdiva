# Guía opcional — Replicar el ETL en SSIS (como en el Laboratorio 5)

El ETL oficial del proyecto es `01_sql_server/08_proceso_etl.sql`: está automatizado en T-SQL y lo ejecuta un job del Agente. Si el docente pide evidenciar el flujo en **Visual Studio + SSIS**, este paquete hace lo mismo para la tabla de hechos. Las dimensiones se cargan antes con `EXEC etl.usp_CargarDimensiones`.

## 1. Proyecto
Visual Studio → *Nuevo proyecto → Integration Services Project* → nombre `DataShield360_ETL`.

## 2. Conexiones (Administradores de conexión → Nueva conexión OLE DB)
- `OLTP` → servidor local, base `MinimarketDiva`
- `DW` → servidor local, base `MinimarketDiva_DW`

## 3. Control Flow
1. **Execute SQL Task** "Calendario y dimensiones" (conexión DW):
   `EXEC etl.usp_CargarCalendario; EXEC etl.usp_CargarDimensiones;`
2. **Data Flow Task** "Cargar FactVentas" (se conecta con la flecha verde desde el paso 1).
3. **Execute SQL Task** "Bitácora" (conexión DW):
   `INSERT INTO etl.LogCarga (Proceso, Inicio, Fin, Estado) VALUES ('SSIS FactVentas', SYSDATETIME(), SYSDATETIME(), 'OK');`

## 4. Data Flow "Cargar FactVentas"
| # | Componente | Configuración | Regla |
|---|---|---|---|
| 1 | **OLE DB Source** (OLTP) | Comando SQL: `SELECT d.id_detalleVenta, d.cantidad_detalleVenta, d.precio_unit_detalleVenta, d.id_producto, v.id_venta, v.fecha_venta, v.id_cliente, v.id_empleado, v.id_metodoPago FROM dbo.DetalleVenta d JOIN dbo.Venta v ON v.id_venta = d.id_venta WHERE v.estado_venta = 'REGISTRADA' AND d.cantidad_detalleVenta > 0` | R3, R4 |
| 2 | **Derived Column** | `SK_Tiempo = (DT_I4)(YEAR(fecha_venta)*10000 + MONTH(fecha_venta)*100 + DAY(fecha_venta))`  ·  `SK_Hora = (DT_UI1)DATEPART("hh", fecha_venta)`  ·  `Importe = (DT_NUMERIC,12,2)(cantidad_detalleVenta * precio_unit_detalleVenta)` | R5, R6 |
| 3 | **Lookup** DimProducto | Une `id_producto` con `IdProducto` → devuelve `SK_Producto`, `PrecioVenta` y `PrecioCompra`. Filas sin coincidencia → *Redirect to no match output* | R4 |
| 4 | **Lookup** DimCliente / DimEmpleado / DimMetodoPago | Uno por dimensión, devuelven `SK_*` | — |
| 5 | **Derived Column** | `Costo = (DT_NUMERIC,12,2)(Importe * PrecioCompra / PrecioVenta)`  ·  `Margen = Importe - Costo` | R5 |
| 6 | **Lookup** FactVentas | Une `id_detalleVenta` con `IdDetalle`. Solo pasa la salida *No Match* (carga incremental) | R8 |
| 7 | **OLE DB Destination** | `dw.FactVentas`, *fast load* | — |
| 8 | **OLE DB Destination** (salida No Match del paso 3) | `etl.Rechazos` | R4 |

## 5. Evidencia
Ejecuta el paquete con **F5** y toma la captura del Data Flow con **todas las flechas en verde** y el conteo de filas sobre cada flecha. Va como evidencia E-07 en la sección 5.2 del informe.
