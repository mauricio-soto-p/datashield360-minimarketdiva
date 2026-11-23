# Guía paso a paso — Dashboard Power BI "DataShield 360 · Minimarket Diva"

Esta guía te lleva desde cero hasta el archivo `NombreGrupo_CIIN1487R_EF.pbix`, con **4 páginas y 9 visualizaciones**. Cubre lo que pide la rúbrica: KPI, OLAP por al menos 2 dimensiones y tendencia. Tiempo estimado: 60 a 90 minutos.

> **Herramienta:** Power BI Desktop (gratuito, Microsoft Store). Si no puedes instalarlo, los mismos pasos funcionan en Tableau Public.

---

## Paso 1 · Obtener los datos (elige UNA opción)

**Opción A (recomendada, demuestra la integración con SQL Server):**
1. *Inicio → Obtener datos → SQL Server*.
2. Servidor: `localhost` (o el nombre de tu instancia, por ejemplo `.\SQLEXPRESS`). Base de datos: `MinimarketDiva_DW`. Modo: **Importar**.
3. Marca las 7 tablas del esquema `dw`: `FactVentas`, `DimTiempo`, `DimHora`, `DimProducto`, `DimCliente`, `DimEmpleado` y `DimMetodoPago`. Luego pulsa **Cargar**.
4. Usa el usuario `lg_analista_bi` si quieres demostrar el mínimo privilegio. En ese caso hay que darle `SELECT` sobre el esquema `dw` del DW.

**Opción B (sin SQL Server):** *Obtener datos → Texto/CSV* y carga los 7 archivos de `05_datos/dw/`. Son la salida exacta del ETL, con los mismos totales.

**Integración con Big Data:** carga también `03_spark/resultados/powerbi_resumen_spark.csv` y `R5_canasta.csv`. Se usan en la página 4.

## Paso 2 · Verificar el modelo estrella (vista *Modelo*)

Power BI suele detectar las relaciones solo. Revisa que existan estas 6 relaciones, todas **de varios (FactVentas) a uno (dimensión)**, con dirección de filtro **única**:

| FactVentas | Dimensión |
|---|---|
| SK_Tiempo | DimTiempo[SK_Tiempo] |
| SK_Hora | DimHora[SK_Hora] |
| SK_Producto | DimProducto[SK_Producto] |
| SK_Cliente | DimCliente[SK_Cliente] |
| SK_Empleado | DimEmpleado[SK_Empleado] |
| SK_MetodoPago | DimMetodoPago[SK_MetodoPago] |

Luego haz esto:
- En *DimTiempo*, clic derecho → **Marcar como tabla de fechas** → columna `Fecha`.
- Ordena `NombreMes` por `Mes` (*Herramientas de columnas → Ordenar por columna*). Haz lo mismo con `NombreDia`: crea en Power Query una columna `NumDia` (lunes = 1) y ordena por ella.
- Oculta las claves `SK_*` de la tabla de hechos (clic derecho → *Ocultar en la vista de informe*).

## Paso 3 · Crear las medidas DAX (*Inicio → Nueva medida*)

Crea primero una tabla vacía llamada `_Medidas` (*Especificar datos* → Cargar) y guarda ahí todas las medidas:

```DAX
Ventas = SUM ( FactVentas[Importe] )
Margen = SUM ( FactVentas[Margen] )
Margen % = DIVIDE ( [Margen], [Ventas] )
Tickets = DISTINCTCOUNT ( FactVentas[NroVenta] )
Ticket Promedio = DIVIDE ( [Ventas], [Tickets] )
Unidades = SUM ( FactVentas[Cantidad] )
Ventas Año Anterior = CALCULATE ( [Ventas], SAMEPERIODLASTYEAR ( DimTiempo[Fecha] ) )
Crecimiento Interanual % = DIVIDE ( [Ventas] - [Ventas Año Anterior], [Ventas Año Anterior] )
% Pagos Digitales =
    DIVIDE ( CALCULATE ( [Tickets], DimMetodoPago[EsDigital] = "SI" ), [Tickets] )
Ventas Fin de Semana % =
    DIVIDE ( CALCULATE ( [Ventas], DimTiempo[EsFinDeSemana] = 1 ), [Ventas] )
Meta Margen % = 0.22
```

Da formato a cada una: moneda S/ para `Ventas`, `Margen` y `Ticket Promedio`, y porcentaje con 1 decimal para las de %.

## Paso 4 · Construir las páginas

### Página 1 — "Resumen ejecutivo" (KPI + tendencia)
1. **4 tarjetas** (objeto *Tarjeta*): `Ventas`, `Margen %`, `Tickets` y `Ticket Promedio`.
2. **KPI** (objeto *KPI*): valor = `Ventas`, eje de tendencia = `DimTiempo[Fecha]` (jerarquía Año-Mes) y objetivo = `Ventas Año Anterior`.
3. **Gráfico de líneas — tendencia** ⭐ (requisito): eje X = `DimTiempo[Mes]` (o `NombreMes`), eje Y = `Ventas`, leyenda = `DimTiempo[Anio]`. Muestra los picos de julio y diciembre y el crecimiento entre años.
4. **Segmentadores**: `DimTiempo[Anio]` y `DimProducto[Categoria]`.

### Página 2 — "Análisis OLAP por producto y tiempo" (2+ dimensiones)
5. **Matriz** (OLAP *drill-down*): filas = `DimProducto[Categoria]` → `DimProducto[Producto]`, columnas = `DimTiempo[Anio]` → `Trimestre`, valores = `Ventas` y `Margen %`. Activa los botones **⬇ Explorar** para mostrar *drill-down* y *roll-up*.
6. **Gráfico de barras** "Top 10 productos": eje = `Producto`, valor = `Ventas`, con filtro de visual *N superior = 10* por `Ventas`.
7. **Gráfico de dispersión** "Margen vs ventas": X = `Ventas`, Y = `Margen %`, detalles = `Producto`, tamaño = `Unidades`. Sirve para ubicar productos de alto volumen y bajo margen.

### Página 3 — "Operación: turnos, horas y pagos"
8. **Matriz con formato condicional (mapa de calor)**: filas = `DimTiempo[NombreDia]`, columnas = `DimHora[Hora]`, valores = `Tickets`. Luego *Formato → Elementos de celda → Color de fondo = activado*. Responde a la pregunta "¿cuántas personas pongo por turno?".
9. **Gráfico de columnas apiladas al 100 %**: eje = `DimTiempo[Anio]`, leyenda = `DimMetodoPago[MetodoPago]`, valor = `Tickets`. Muestra la adopción de Yape y Plin.
10. Tarjetas `% Pagos Digitales` y `Ventas Fin de Semana %`.

### Página 4 — "Big Data (Spark)"
11. Tabla con `R5_canasta.csv` (regla, soporte, confianza, lift). Es la evidencia de integración entre la parte BI y la parte Big Data.
12. Gráfico de columnas con `powerbi_resumen_spark.csv`: eje = `turno`, valor = `importe`, leyenda = `categoria`.

## Paso 5 · Diseño y gobierno
- Pon un título y un subtítulo en cada visual con la **pregunta de negocio** que responde. Ejemplo: *"¿En qué meses debo reforzar el stock de cerveza?"*.
- Agrega un cuadro de texto al pie con la **fuente**: *"Fuente: MinimarketDiva_DW, carga ETL del dd/mm/aaaa (etl.LogCarga)"*.
- El modelo no contiene nombres ni celulares de clientes, porque el ETL los seudonimiza (regla R7). Menciónalo en la exposición: es gobernanza de datos (Tema 6.3 y 6.4).

## Paso 6 · Evidencias para el informe (E-07 y E-13)
1. *Archivo → Exportar → PDF* (exporta todas las páginas).
2. Captura cada página con `Win + Shift + S` y pégala en la sección 6.4 del informe, en el lugar marcado **«Insertar captura»**.
3. Guarda el archivo como `NombreGrupo_CIIN1487R_EF.pbix` dentro de la carpeta `04_powerbi/`.

## Valores de control (para comprobar que tu dashboard está bien)
Si cargaste los datos completos sin ejecutar las pruebas del script 10, deberías ver:

| Indicador | Valor esperado |
|---|---|
| Ventas totales (ene-2024 a oct-2026) | S/ 4,880,319.40 |
| Tickets | 74,110 · Ticket promedio S/ 65.85 · Margen 23.9 % (detalle en `VALORES_CONTROL.md`) |

Si ejecutaste el script 10, los totales cambian en unos pocos soles, porque las pruebas agregan ventas nuevas.
