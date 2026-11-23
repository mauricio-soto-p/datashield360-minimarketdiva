# Minimarket Diva — paquete inicial para Power BI

## Alcance acordado
Se preparan cuatro páginas desde ahora. Las páginas 1–3 son las destinadas al avance (hasta el Tema 05); la página 4 se conserva para la entrega final y no debe presentarse como parte del avance.

1. Resumen ejecutivo
2. Análisis OLAP por producto y tiempo
3. Operación: turnos, horas y pagos
4. Big Data (Spark) — RESERVADA PARA LA ENTREGA FINAL

## Carga de datos
En Power BI Desktop: Inicio > Obtener datos > Texto/CSV. Importar los siete CSV de dimensiones y hechos incluidos. Promover encabezados y comprobar tipos de datos:
- `DimTiempo[Fecha]`: Fecha
- claves y años: entero
- `FactVentas[Importe]`, `[Costo]`, `[Margen]`: decimal
- `FactVentas[Cantidad]`: entero

## Modelo estrella
Crear relaciones 1:* desde cada dimensión hacia FactVentas, filtro en una dirección:
- DimTiempo[SK_Tiempo] -> FactVentas[SK_Tiempo]
- DimHora[SK_Hora] -> FactVentas[SK_Hora]
- DimProducto[SK_Producto] -> FactVentas[SK_Producto]
- DimCliente[SK_Cliente] -> FactVentas[SK_Cliente]
- DimEmpleado[SK_Empleado] -> FactVentas[SK_Empleado]
- DimMetodoPago[SK_MetodoPago] -> FactVentas[SK_MetodoPago]

Marcar DimTiempo como tabla de fechas usando `Fecha`. Ordenar `NombreMes` por `Mes`. Para `NombreDia`, crear/usar un índice lunes=1…domingo=7 y ordenar por él.

## Medidas
Copiar las medidas de `Medidas_DAX.txt` en una tabla `_Medidas`. Aplicar formato moneda S/ a Ventas, Margen y Ticket Promedio; porcentaje a las medidas porcentuales.

## Diseño de páginas
### 1 — Resumen ejecutivo (avance)
- Tarjetas: Ventas, Margen %, Tickets, Ticket Promedio.
- Línea: ventas por mes, leyenda Año.
- Segmentadores: Año y Categoría.
- Pregunta directiva: ¿Cómo evolucionan las ventas y el margen del negocio?

### 2 — Análisis OLAP por producto y tiempo (avance)
- Matriz: Categoría > Producto en filas; Año > Trimestre en columnas; Ventas y Margen % en valores.
- Barras Top 10 productos por Ventas.
- Dispersión: Ventas vs Margen %, tamaño Unidades, detalle Producto.
- Habilitar drill-down y roll-up.

### 3 — Operación: turnos, horas y pagos (avance)
- Matriz de calor: NombreDia x Hora; valor Tickets.
- Columnas apiladas 100%: Año por MétodoPago; valor Tickets.
- Tarjetas: % Pagos Digitales y Ventas Fin de Semana %.
- Pregunta directiva: ¿En qué horarios se concentra la demanda y cómo pagan los clientes?

### 4 — Big Data (reservada para entrega final)
- Tabla de resultados de `R5_canasta.csv` (regla, soporte, confianza, lift).
- Visual de `powerbi_resumen_spark.csv` por turno/categoría/importe, según columnas reales del archivo.
- No incluir esta página en el PPT del avance de semana 6.

## Valores de control de los CSV entregados
Recalculados directamente sobre `FactVentas.csv`:
- Filas: 148,959
- Ventas: S/ 4,880,319.40
- Margen: S/ 1,167,325.69
- Unidades: 341,042
- Tickets distintos: 74,110
- Fechas de hechos: 01/01/2024 a 31/10/2026
- Ticket promedio: S/ 65.85
- Margen porcentual: 23.92%

Los valores se refieren al CSV entregado, antes de ejecutar pruebas que agreguen ventas. No mezclar con totales posteriores a pruebas.

## Validaciones antes de presentar
1. Confirmar que cada clave dimensional es única y que no existen claves foráneas sin correspondencia.
2. Confirmar que las seis relaciones sean 1:* y no muchos-a-muchos.
3. Comparar las tarjetas con los valores de control anteriores.
4. Verificar filtros de año, categoría, producto y método de pago.
5. Guardar capturas de las páginas 1–3. La página 4 queda para la entrega final.

## Nota sobre el archivo PBIX
Este paquete contiene los datos, medidas y especificación del modelo y páginas. El archivo `.pbix` final debe guardarse desde Power BI Desktop después de cargar los CSV y construir los visuales.
