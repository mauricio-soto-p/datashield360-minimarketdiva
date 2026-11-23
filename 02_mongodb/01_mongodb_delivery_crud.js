/* =====================================================================
   PROYECTO : DataShield 360 - Minimarket Diva (licorería)
   SCRIPT   : Componente NoSQL (MongoDB) - pedidos por delivery y reseñas
   Ejecutar : mongosh "mongodb://localhost:27017" --file 01_mongodb_delivery_crud.js
              o por bloques en MongoDB Compass > pestaña _MONGOSH
   ---------------------------------------------------------------------
   ¿Por qué NoSQL? Los pedidos que llegan por WhatsApp / Facebook tienen
   estructura VARIABLE: unos traen reseña, otros incidencia, otros nada;
   la entrega trae distrito, minutos y repartidor. En el modelo relacional
   eso exigiría 3-4 tablas nuevas con muchas columnas NULL. En MongoDB
   cada pedido se guarda como un documento JSON tal como se genera.
   Integración híbrida: id_venta e id_cliente apuntan a dbo.Venta y
   dbo.Cliente de SQL Server (persistencia políglota).
   ===================================================================== */
db = db.getSiblingDB("minimarketdiva_nosql");
db.pedidos_delivery.drop();                     // reinicio limpio (laboratorio)

/* ---------- 0. Esquema flexible con validación mínima ($jsonSchema) ---------- */
db.createCollection("pedidos_delivery", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["id_venta", "id_cliente", "fecha_pedido", "canal", "estado"],
    properties: {
      id_venta:     { bsonType: "int", description: "FK lógica a dbo.Venta" },
      id_cliente:   { bsonType: "int", description: "FK lógica a dbo.Cliente" },
      fecha_pedido: { bsonType: "date" },
      canal:        { enum: ["WhatsApp", "Llamada", "Facebook"] },
      estado:       { enum: ["ENTREGADO", "CANCELADO", "EN_RUTA"] },
      entrega:      { bsonType: "object", properties: { minutos: { bsonType: "int", minimum: 0 } } },
      resena:       { bsonType: "object", properties: { calificacion: { bsonType: "int", minimum: 1, maximum: 5 } } }
    } } },
  validationAction: "error"
});

/* =====================================================================
   C - CREATE
   ===================================================================== */
// Carga masiva (1,500 pedidos, Extended JSON) DESDE LA TERMINAL de Windows:
//   mongoimport --db minimarketdiva_nosql --collection pedidos_delivery --jsonArray ^
//               --file "05_datos\nosql\pedidos_delivery.json"

// insertOne: pedido con reseña e incidencia (subdocumentos)
db.pedidos_delivery.insertOne({
  id_venta: NumberInt(75030), id_cliente: NumberInt(25),
  fecha_pedido: ISODate("2026-10-31T22:40:00Z"), canal: "WhatsApp", estado: "ENTREGADO",
  productos: [ { id_producto: 1, nombre: "Cristal 620 ml", cantidad: 12 },
               { id_producto: 13, nombre: "Bolsa de hielo 5 kg", cantidad: 2 } ],
  entrega: { distrito: "Los Olivos", minutos: NumberInt(48), repartidor: "Moto 1",
             ubicacion: { type: "Point", coordinates: [-77.0705, -11.9917] } },
  resena: { calificacion: NumberInt(2), comentario: "La cerveza llegó tibia.", etiquetas: ["temperatura"] },
  incidencia: { tipo: "Producto en mal estado", estado: "ABIERTA" }
});

// insertMany: documentos con ESTRUCTURA DIFERENTE entre sí (esquema flexible)
db.pedidos_delivery.insertMany([
  { id_venta: NumberInt(75031), id_cliente: NumberInt(140), fecha_pedido: ISODate("2026-10-31T23:05:00Z"),
    canal: "Facebook", estado: "ENTREGADO",
    entrega: { distrito: "Comas", minutos: NumberInt(25), repartidor: "Moto 2" } },          // sin reseña
  { id_venta: NumberInt(75032), id_cliente: NumberInt(77), fecha_pedido: ISODate("2026-10-31T23:20:00Z"),
    canal: "Llamada", estado: "CANCELADO", motivo_cancelacion: "Cliente no respondió" },     // sin entrega
  { id_venta: NumberInt(75033), id_cliente: NumberInt(301), fecha_pedido: ISODate("2026-10-31T23:45:00Z"),
    canal: "WhatsApp", estado: "EN_RUTA", pago: { metodo: "Yape", comprobante: "img_yape_0931.jpg" },
    entrega: { distrito: "Independencia", minutos: NumberInt(0), repartidor: "Moto 1" } }
]);

/* =====================================================================
   R - READ
   ===================================================================== */
// 1) Filtro + proyección + orden: incidencias abiertas más recientes
db.pedidos_delivery.find({ "incidencia.estado": "ABIERTA" },
                         { _id: 0, id_venta: 1, fecha_pedido: 1, "incidencia.tipo": 1, "resena.comentario": 1 })
                   .sort({ fecha_pedido: -1 }).limit(10);

// 2) Operadores de comparación y existencia: entregas lentas (> 45 min) con reseña
db.pedidos_delivery.countDocuments({ "entrega.minutos": { $gt: 45 }, resena: { $exists: true } });

// 3) Búsqueda dentro de arreglos: reseñas que mencionan "temperatura"
db.pedidos_delivery.find({ "resena.etiquetas": "temperatura" }, { _id: 0, id_venta: 1, "resena.comentario": 1 });

// 4) Agregación: tiempo promedio de entrega y satisfacción por distrito
db.pedidos_delivery.aggregate([
  { $match: { estado: "ENTREGADO" } },
  { $group: { _id: "$entrega.distrito",
              pedidos: { $sum: 1 },
              minutos_promedio: { $avg: "$entrega.minutos" },
              calificacion_promedio: { $avg: "$resena.calificacion" } } },
  { $project: { _id: 0, distrito: "$_id", pedidos: 1,
                minutos_promedio: { $round: ["$minutos_promedio", 1] },
                calificacion_promedio: { $round: ["$calificacion_promedio", 2] } } },
  { $sort: { calificacion_promedio: 1 } }
]);

// 5) Agregación con $unwind: etiquetas más mencionadas en reseñas negativas (<= 2)
db.pedidos_delivery.aggregate([
  { $match: { "resena.calificacion": { $lte: 2 } } },
  { $unwind: "$resena.etiquetas" },
  { $group: { _id: "$resena.etiquetas", menciones: { $sum: 1 } } },
  { $sort: { menciones: -1 } }
]);

/* =====================================================================
   U - UPDATE
   ===================================================================== */
// updateOne con $set y $push: se cierra la incidencia y se guarda historial
db.pedidos_delivery.updateOne(
  { id_venta: 75030 },
  { $set:  { "incidencia.estado": "CERRADA", "incidencia.solucion": "Reposición de 12 cervezas frías" },
    $push: { "incidencia.historial": { fecha: new Date(), accion: "Cierre", usuario: "supervisor_noche" } } }
);

// updateMany: los pedidos EN_RUTA de más de 2 horas pasan a revisión
db.pedidos_delivery.updateMany(
  { estado: "EN_RUTA", fecha_pedido: { $lt: new Date(Date.now() - 2 * 3600 * 1000) } },
  { $set: { requiere_revision: true } }
);

// $inc: corrección del tiempo de entrega registrado
db.pedidos_delivery.updateOne({ id_venta: 75031 }, { $inc: { "entrega.minutos": NumberInt(5) } });

// Prueba del validador: calificación fuera de rango -> RECHAZADO
try {
  db.pedidos_delivery.updateOne({ id_venta: 75030 }, { $set: { "resena.calificacion": NumberInt(9) } });
} catch (e) { print("Validación rechazó el cambio: " + e.message); }

/* =====================================================================
   D - DELETE
   ===================================================================== */
// deleteOne: se elimina el pedido cancelado de prueba
db.pedidos_delivery.deleteOne({ id_venta: 75032, estado: "CANCELADO" });

// deleteMany: derecho de cancelación (Ley 29733, derechos ARCO):
// el cliente 301 solicita eliminar todo su historial de delivery
db.pedidos_delivery.deleteMany({ id_cliente: 301 });

/* =====================================================================
   ÍNDICES y plan de ejecución
   ===================================================================== */
db.pedidos_delivery.createIndex({ id_cliente: 1, fecha_pedido: -1 });               // historial por cliente
db.pedidos_delivery.createIndex({ "incidencia.estado": 1 }, { sparse: true });       // solo docs con incidencia
db.pedidos_delivery.createIndex({ "resena.comentario": "text" }, { default_language: "spanish" });
db.pedidos_delivery.createIndex({ "entrega.ubicacion": "2dsphere" });                // consultas geográficas

db.pedidos_delivery.find({ $text: { $search: "tibia demoró" } }, { _id: 0, "resena.comentario": 1 });
// Debe mostrar IXSCAN (usa índice) y no COLLSCAN
db.pedidos_delivery.find({ id_cliente: 25 }).explain("executionStats").executionStats;

print("Documentos en pedidos_delivery: " + db.pedidos_delivery.countDocuments());
