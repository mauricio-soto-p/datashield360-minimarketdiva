# DataShield 360 – Minimarket Diva

## 1. Descripción del proyecto

DataShield 360 es un proyecto académico de integración de bases de datos avanzadas, inteligencia de negocios y procesamiento Big Data, desarrollado para el caso empresarial Minimarket Diva.

La solución propone un ecosistema de datos que integra SQL Server, MongoDB, un Data Warehouse, Power BI y Apache Spark, con el propósito de fortalecer la gestión de información, la seguridad de los datos y el análisis para la toma de decisiones.

El proyecto utiliza datos sintéticos generados con fines académicos y reproducibles.

## 2. Objetivo general

Diseñar e implementar una solución integrada de gestión y análisis de datos que permita mejorar el control transaccional, la seguridad, el seguimiento de entregas, la explotación analítica y el procesamiento de información de Minimarket Diva.

## 3. Arquitectura de la solución

La arquitectura de DataShield 360 se organiza en los siguientes componentes:

| Componente | Tecnología | Función |
|---|---|---|
| Base de datos transaccional | SQL Server | Gestiona ventas, inventario, clientes y operaciones del negocio. |
| Automatización y seguridad | T-SQL | Implementa procedimientos almacenados, funciones, triggers, roles, auditoría y controles. |
| Componente NoSQL | MongoDB | Almacena información complementaria del delivery, como seguimiento, ubicación, reseñas e incidencias. |
| Data Warehouse | SQL Server | Organiza la información analítica mediante un modelo dimensional. |
| Proceso ETL | SQL Server / T-SQL | Extrae, transforma y carga los datos hacia el Data Warehouse. |
| Inteligencia de Negocios | Power BI | Presenta indicadores, tendencias y visualizaciones para el análisis empresarial. |
| Procesamiento Big Data | Apache Spark / PySpark | Procesa conjuntos de datos mediante DataFrames y formatos como Parquet. |

### Flujo general de información

1. Las operaciones transaccionales se registran en SQL Server.
2. La información complementaria de las entregas se almacena en MongoDB.
3. Los datos necesarios se extraen y transforman mediante el proceso ETL.
4. El Data Warehouse almacena la información organizada para el análisis.
5. Power BI consume el modelo analítico para presentar indicadores y visualizaciones.
6. Apache Spark procesa datasets para desarrollar análisis de escalabilidad, rendimiento y procesamiento distribuido.

## 4. Estructura del repositorio

```text
datashield360-minimarketdiva/
│
├── 01_sql_server/
│   └── Scripts de creación, automatización,
│       seguridad, respaldo, ETL y validación.
│
├── 02_mongodb/
│   └── Scripts de estructura, validación,
│       operaciones CRUD, consultas e índices.
│
├── 03_spark/
│   └── Notebook PySpark, resultados,
│       gráficos y archivos de configuración.
│
├── 04_powerbi/
│   └── Dashboard, medidas DAX,
│       archivos auxiliares y resultados.
│
├── 05_datos/
│   └── Datasets OLTP, Data Warehouse,
│       archivos históricos y datos de delivery.
│
├── 06_informe/
│   └── Documentación, diagramas,
│       informes y evidencias.
│
├── 07_presentacion/
│   └── Material de exposición del proyecto.
│
├── .gitignore
└── README.md
```

## 5. Tecnologías y herramientas

El entorno documentado para el desarrollo del proyecto comprende:

| Tecnología | Versión o configuración documentada |
|---|---|
| Microsoft SQL Server | SQL Server 2019 o superior, Developer Edition |
| SQL Server Management Studio | Entorno de administración SQL Server |
| MongoDB Community | Serie 7.x |
| MongoDB Compass | Interfaz gráfica de administración |
| Apache Spark | 4.3.0 |
| Python | 3.13.18 |
| pandas | 3.0.5 |
| PyArrow | 26.0 |
| Power BI Desktop | Versión de noviembre de 2026 |
| Formato de almacenamiento Big Data | Parquet |

Las versiones corresponden al entorno descrito en la documentación del proyecto. La configuración efectiva puede variar según el equipo de ejecución.

## 6. Organización de los componentes

### 6.1 SQL Server

Contiene los scripts T-SQL relacionados con:

- Creación y extensión de la base de datos.
- Creación de tablas y carga de información.
- Funciones y procedimientos almacenados.
- Triggers y auditoría.
- Seguridad, roles y permisos.
- Política de respaldo.
- Modelo dimensional.
- Proceso ETL.
- Experimentos y pruebas de validación.

### 6.2 MongoDB

Contiene el componente NoSQL destinado a almacenar información complementaria de las entregas.

Incluye:

- Definición de la colección.
- Validación mediante JSON Schema.
- Operaciones CRUD.
- Consultas y agregaciones.
- Índices compuestos, de texto y geoespaciales.
- Pruebas de ejecución y análisis del plan de consulta.

### 6.3 Apache Spark

Contiene el notebook de PySpark y los recursos utilizados para el procesamiento Big Data.

Incluye análisis de volumen, particiones, formatos de almacenamiento y comparación de rendimiento entre herramientas de procesamiento.

### 6.4 Power BI

Contiene el archivo del dashboard, las medidas DAX y los archivos auxiliares utilizados para construir las visualizaciones y los indicadores empresariales.

### 6.5 Datos

Almacena los datasets sintéticos utilizados por los componentes transaccionales, analíticos y Big Data.

### 6.6 Documentación

Contiene los informes, diagramas de arquitectura, modelos de datos y evidencias de ejecución.

### 6.7 Presentación

Contiene el material preparado para la exposición y sustentación del proyecto.

## 7. Orden general de ejecución

El orden recomendado para reproducir la solución es:

1. Preparar el entorno de SQL Server y ejecutar los scripts de creación y carga de la base transaccional.
2. Ejecutar los scripts de automatización, seguridad y auditoría.
3. Configurar MongoDB y ejecutar su script de implementación y operaciones.
4. Crear y cargar el Data Warehouse mediante el proceso ETL.
5. Ejecutar las consultas y experimentos de rendimiento de SQL Server.
6. Abrir el dashboard de Power BI y verificar sus fuentes de datos.
7. Configurar el entorno de Python y Apache Spark para ejecutar el notebook correspondiente.

**Importante:** antes de ejecutar los scripts, revisar las rutas locales, nombres de bases de datos, conexiones y parámetros de configuración. Algunos archivos pueden requerir ajustes para adaptarse al entorno de otro equipo.

El script de inicialización de MongoDB debe revisarse antes de ejecutarlo, ya que puede recrear la colección y eliminar documentos existentes. Utilizar una base de datos de demostración.

## 8. Resultados documentados

Entre los resultados registrados durante el desarrollo del proyecto se encuentran:

- Carga de 148 959 registros en la tabla de hechos del Data Warehouse.
- Conciliación de importes OLTP y DW con una diferencia de S/ 0,00.
- Catorce pruebas de validación SQL Server aprobadas en la ejecución documentada.
- Implementación de operaciones CRUD y validación de documentos en MongoDB.
- Verificación de índices y uso de IXSCAN en una consulta de MongoDB.
- Experimentos de rendimiento en SQL Server y procesamiento Big Data con Spark.

Los resultados detallados, sus condiciones de ejecución y las evidencias correspondientes se encuentran en las carpetas del proyecto y en el informe técnico.

## 9. Integrantes

Proyecto desarrollado por el equipo de trabajo del curso Base de Datos Avanzadas y Big Data, período académico 2026-2.

Los integrantes, sus responsabilidades y sus contribuciones se documentarán en el apartado correspondiente del informe y en el registro de aportes del repositorio.

## 10. Evidencias y documentación

Los archivos de implementación, resultados, diagramas, capturas e informes se encuentran distribuidos en las carpetas correspondientes del repositorio.

## 11. Repositorio

**GitHub:**  
https://github.com/mauricio-soto-p/datashield360-minimarketdiva

---

**Proyecto académico DataShield 360 – Minimarket Diva**  
Curso: Base de Datos Avanzadas y Big Data  
Período: 2026-2
