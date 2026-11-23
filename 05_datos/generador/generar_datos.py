"""DataShield 360 - Minimarket Diva (licorería)
Generador del histórico simulado de ventas 2024-01-01 a 2026-10-31.
Respeta el modelo original del grupo (11 tablas de MinimarketDiva) y continúa
los IDs después de los datos originales (Registro de datos.sql):
  productos 1-14, clientes 1-12, ventas 1-15, detalles 1-39, pedidos 1-10, det. pedido 1-32.
Semilla fija (2026) => resultados reproducibles.
Uso: python generar_datos.py <carpeta_salida>
"""
import csv, json, os, random, sys
from datetime import date, datetime, timedelta

random.seed(2026)
OUT = sys.argv[1]
for sub in ("oltp", "dw", "nosql", "bigdata"):
    os.makedirs(f"{OUT}/{sub}", exist_ok=True)

def wcsv(path, header, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

CAT = {1: "Cerveza", 2: "Ron", 3: "Pisco", 4: "Whiskey", 5: "Gaseosa", 6: "Vino", 7: "Champán", 8: "Hielo", 9: "Cigarrillos"}
ALCOHOL = {1, 2, 3, 4, 6, 7}
# (nombre, pVenta 2026, pCompra 2026, id_categoria, popularidad, cantidad_media)
PROD = [
    ("Cristal 620 ml", 8.50, 6.20, 1, 30, 4), ("Pilsen Trujillo", 9.00, 6.50, 1, 16, 4),
    ("Ron Cartavio Black", 45.00, 35.00, 2, 5, 1), ("Ron Bacardí Blanco", 58.00, 46.00, 2, 3, 1),
    ("Pisco Queirolo", 42.00, 33.00, 3, 4, 1), ("Pisco Tabernero", 39.00, 31.00, 3, 4, 1),
    ("Johnnie Walker Red", 95.00, 78.00, 4, 3, 1), ("Jack Daniels", 145.00, 120.00, 4, 1.5, 1),
    ("Coca-Cola 3 L", 12.50, 9.80, 5, 12, 1), ("Guaraná 3 L", 8.50, 5.70, 5, 7, 1),
    ("Vino Tabernero Borgoña", 28.00, 22.00, 6, 4, 1), ("Champán Ricadonna", 75.00, 60.00, 7, 1, 1),
    ("Bolsa de hielo 5 kg", 7.00, 4.50, 8, 14, 1), ("Lucky Strike", 22.00, 17.50, 9, 6, 1),
    # --- ampliación del catálogo (productos 15-45) ---
    ("Cusqueña Dorada 620 ml", 9.50, 7.00, 1, 14, 4), ("Corona 355 ml", 7.50, 5.40, 1, 6, 6),
    ("Pilsen Callao lata 355 ml x6", 26.00, 20.00, 1, 9, 1), ("Cristal lata 355 ml x6", 24.00, 18.50, 1, 9, 1),
    ("Cusqueña Negra 620 ml", 9.80, 7.20, 1, 4, 3),
    ("Ron Pomalca Superior", 29.00, 22.00, 2, 3, 1), ("Ron Flor de Caña 4 años", 52.00, 41.00, 2, 2, 1),
    ("Ron Havana Club Añejo", 65.00, 52.00, 2, 1.5, 1),
    ("Pisco Portón Mosto Verde", 89.00, 70.00, 3, 1, 1), ("Pisco 4 Gallos Quebranta", 36.00, 28.00, 3, 3, 1),
    ("Pisco Intipalka Acholado", 48.00, 38.00, 3, 1.5, 1),
    ("Chivas Regal 12 años", 165.00, 135.00, 4, 0.8, 1), ("Johnnie Walker Black", 175.00, 142.00, 4, 0.8, 1),
    ("Old Parr 12 años", 155.00, 126.00, 4, 0.6, 1),
    ("Inca Kola 3 L", 12.50, 9.80, 5, 11, 1), ("Sprite 3 L", 11.00, 8.40, 5, 4, 1),
    ("Agua tónica 1.5 L", 6.50, 4.60, 5, 3, 1), ("Agua San Luis 2.5 L", 4.50, 3.00, 5, 5, 1),
    ("Vino Santiago Queirolo Borgoña", 25.00, 19.00, 6, 3, 1), ("Vino Intipalka Malbec", 42.00, 33.00, 6, 1.5, 1),
    ("Vino Casillero del Diablo Cabernet", 49.00, 38.50, 6, 1.5, 1),
    ("Espumante Tabernero Brut", 39.00, 30.00, 7, 1, 1), ("Champán Riccadonna Ruby", 78.00, 62.00, 7, 0.7, 1),
    ("Freixenet Carta Nevada", 85.00, 68.00, 7, 0.6, 1),
    ("Hielo en cubos 3 kg", 5.00, 3.20, 8, 6, 1),
    ("Hamilton Blue x20", 18.00, 14.00, 9, 3, 1), ("Marlboro Rojo x20", 24.00, 19.00, 9, 3, 1),
    ("Cerveza Pilsen 1 L retornable", 10.50, 7.80, 1, 8, 3), ("Vino Tacama Gran Tinto", 32.00, 25.00, 6, 1.2, 1),
    ("Ron Cartavio Superior 1 L", 34.00, 26.00, 2, 2, 1), ("Agua San Mateo 600 ml", 2.50, 1.60, 5, 4, 1),
]
NP = len(PROD)
# Productos: los 14 originales ya los inserta "Registro de datos.sql"; aquí van 15..45
wcsv(f"{OUT}/oltp/producto_nuevos.csv", ["id_producto", "nombre_producto", "pVenta_producto", "pCompra_producto", "id_categoria"],
     [(i + 1, p[0], f"{p[1]:.2f}", f"{p[2]:.2f}", p[3]) for i, p in enumerate(PROD) if i >= 14])

# Clientes: 1-12 originales, 13 = 'Cliente Varios' (venta sin identificar), 14-600 generados
nombres = ["Juan", "María", "Carlos", "Ana", "Luis", "Rosa", "Jorge", "Patricia", "Miguel", "Carmen", "Diego", "Lucía",
           "José", "Elena", "Raúl", "Silvia", "Pedro", "Teresa", "Hugo", "Gloria", "Renzo", "Milagros", "Kevin", "Fiorella",
           "Bruno", "Valeria", "Sergio", "Daniela", "Alonso", "Camila", "Wilder", "Mauricio", "Gabriela", "Óscar"]
apellidos = ["Quispe", "Flores", "Huamán", "Rojas", "Sánchez", "García", "Mamani", "Chávez", "Ramírez", "Torres", "Vásquez",
             "Mendoza", "Castillo", "Díaz", "Ruiz", "Paredes", "Gutiérrez", "Cruz", "Vargas", "Salazar", "Medina", "Espinoza",
             "Ríos", "Ramos", "Aguilar", "Cárdenas", "Delgado", "Herrera", "Soto", "Morón", "Portillo", "León"]
cli_rows = [(13, "Cliente", "Varios", "-", "000000000")]
for i in range(14, 601):
    cli_rows.append((i, random.choice(nombres), random.choice(apellidos), random.choice(apellidos), f"9{random.randint(10000000, 99999999)}"))
wcsv(f"{OUT}/oltp/cliente_nuevos.csv", ["id_cliente", "nombre_cliente", "ape_pat_cliente", "ape_mat_cliente", "celular_cliente"], cli_rows)
CLIENTES_FRECUENTES = list(range(1, 13)) + list(range(14, 601))
peso_cli = [random.paretovariate(1.3) for _ in CLIENTES_FRECUENTES]      # pocos clientes compran mucho (Pareto)

EMP_TURNO = {"Mañana": [1, 4, 5], "Noche": [2, 3, 6]}
MP_NOMBRE = {1: "Efectivo", 2: "Tarjeta", 3: "Yape", 4: "Plin", 5: "Transferencia"}

def pago(d):
    t = (d - date(2024, 1, 1)).days / 1035          # adopción creciente de billeteras digitales
    return random.choices([1, 2, 3, 4, 5], [.40 - .14 * t, .18, .28 + .12 * t, .10 + .02 * t, .04])[0]

def precio(base, d):                                # inflación ~4.5 % anual hacia atrás desde 2026
    años = (date(2026, 7, 1) - d).days / 365
    return round(base / (1.045 ** max(años, 0)), 1)

def ley_seca(dt):                                   # calendario electoral 2026 (08:00 del día previo a 08:00 del siguiente)
    for e in (date(2026, 4, 12), date(2026, 6, 7)):
        ini = datetime(e.year, e.month, e.day, 8) - timedelta(days=1); fin = ini + timedelta(days=2)
        if ini <= dt < fin: return True
    return False

def cuarto_domingo_julio(y):
    d = date(y, 7, 1); dom = [d + timedelta(days=k) for k in range(31) if (d + timedelta(days=k)).weekday() == 6]
    return dom[3]

MES = {1: 1.12, 2: 1.0, 3: .95, 4: .90, 5: .97, 6: .98, 7: 1.20, 8: .96, 9: .93, 10: 1.02, 11: .98, 12: 1.45}
DOW = {0: .70, 1: .72, 2: .78, 3: .90, 4: 1.55, 5: 1.85, 6: 1.05}
HORAS = list(range(9, 24)); PESO_H = [1, 1.3, 1.8, 2.2, 2.4, 2.4, 2.6, 3.2, 4.2, 5.6, 6.8, 7.4, 6.9, 5.5, 3.6]

ventas, detalles = [], []
vid, did = 15, 39                                    # continúan los IDs originales (15 ventas, 39 detalles)
d = date(2024, 1, 1)
while d <= date(2026, 10, 31):
    if (d.month, d.day) == (1, 1): n_base = 38       # 1 de enero: tienda abre tarde
    else: n_base = random.gauss(58, 6)
    crec = 1 + .09 * ((d - date(2024, 1, 1)).days / 365)
    n = int(n_base * MES[d.month] * DOW[d.weekday()] * crec)
    especial = {}
    if d.month == 12 and d.day in (24, 31): n = int(n * 2.1); especial[7] = 9; especial[6] = 2.5
    if d.month == 7 and d.day in (27, 28, 29): n = int(n * 1.5)
    if d == cuarto_domingo_julio(d.year): especial[3] = 3.5                 # Día del Pisco
    if d.month == 2 and d.weekday() == 5 and d.day <= 7: especial[3] = 2.5  # Día del Pisco Sour
    if d.month == 5 and d.weekday() == 6 and 8 <= d.day <= 14: especial[6] = 3   # Día de la Madre
    if d.month == 10 and d.day == 31: n = int(n * 1.4)                       # Día de la Canción Criolla
    for _ in range(max(n, 0)):
        h = random.choices(HORAS, PESO_H)[0]
        dt = datetime(d.year, d.month, d.day, h, random.randint(0, 59), random.randint(0, 59))
        turno = "Mañana" if h < 17 else "Noche"
        emp = random.choice(EMP_TURNO[turno])
        cli = 13 if random.random() < .46 else random.choices(CLIENTES_FRECUENTES, peso_cli)[0]
        seca = ley_seca(dt)
        pesos = []
        for i, p in enumerate(PROD):
            w = p[4] * especial.get(p[3], 1)
            if p[3] in (1, 8) and d.month in (1, 2, 3, 12): w *= 1.3       # verano: cerveza y hielo
            if seca and p[3] in ALCOHOL: w = 0
            pesos.append(w)
        k = random.choices([1, 2, 3, 4], [.42, .33, .17, .08])[0]
        elegidos = set()
        while len(elegidos) < k: elegidos.add(random.choices(range(NP), pesos)[0])
        if 0 in elegidos or 14 in elegidos:                                  # cerveza fría pide hielo
            if random.random() < .35: elegidos.add(12)
        vid += 1
        estado = "ANULADA" if random.random() < .012 else "REGISTRADA"
        total = 0
        for i in sorted(elegidos):
            did += 1
            cant = max(1, int(random.expovariate(1 / PROD[i][5])) + (1 if PROD[i][5] > 1 else 0))
            pu = precio(PROD[i][1], d)
            total += cant * pu
            detalles.append([did, cant, f"{pu:.2f}", vid, i + 1])
        ventas.append([vid, f"{total:.2f}", dt.strftime("%Y-%m-%d %H:%M:%S"), cli, pago(d), emp, estado])
    d += timedelta(days=1)

wcsv(f"{OUT}/oltp/venta_historico.csv", ["id_venta", "monto_venta", "fecha_venta", "id_cliente", "id_metodoPago", "id_empleado", "estado_venta"], ventas)
wcsv(f"{OUT}/oltp/detalleventa_historico.csv", ["id_detalleVenta", "cantidad_detalleVenta", "precio_unit_detalleVenta", "id_venta", "id_producto"], detalles)

# Pedidos de abastecimiento (11 en adelante): proveedor según categoría
PROV_CAT = {1: [1, 15, 16, 17, 18, 19, 42], 2: [3, 4, 7, 8, 26, 27, 28, 21, 22, 44], 3: [11, 33, 34, 35, 12, 36, 37, 38],
            4: [13, 39, 10, 30, 31, 32, 45], 5: [5, 6, 23, 24, 25, 43], 6: [9, 29, 20], 7: [9, 29, 30, 31], 8: [14, 40, 41, 13]}
ped, dped = [], []
pid, dpid = 10, 32
d = date(2024, 1, 3)
while d <= date(2026, 10, 31):
    for prov, prods in PROV_CAT.items():
        if random.random() < (.55 if prov in (1, 4) else .22):
            pid += 1; tot = 0
            for p in random.sample(prods, min(len(prods), random.randint(2, 4))):
                dpid += 1
                c = random.randint(6, 30) * (3 if PROD[p - 1][3] in (1, 8) else 1)
                pc = precio(PROD[p - 1][2], d); tot += c * pc
                dped.append([dpid, c, f"{pc:.2f}", pid, p])
            ped.append([pid, f"{tot:.2f}", d.isoformat() + " 09:00:00", prov])
    d += timedelta(days=7)
wcsv(f"{OUT}/oltp/pedido_historico.csv", ["id_pedido", "monto_pedido", "fecha_pedido", "id_proveedor"], ped)
wcsv(f"{OUT}/oltp/detallepedido_historico.csv", ["id_detallePedido", "cantidad_detallePedido", "precio_unit_detallePedido", "id_pedido", "id_producto"], dped)

inv = []
for i in range(14, NP):
    mn = 5 if PROD[i][4] < 2 else (10 if PROD[i][4] < 6 else 20)
    stock = random.randint(0, mn * 4) if random.random() > .18 else random.randint(0, mn - 1)
    inv.append([i + 1, stock, mn, mn * 6, "2026-10-31", i + 1])
wcsv(f"{OUT}/oltp/inventario_nuevos.csv", ["id_inventario", "stock_actual_inventario", "stock_minimo_inventario",
                                            "stock_maximo_inventario", "fecha_inventario", "id_producto"], inv)

# ---------- Datos originales del grupo (para que Spark/DW incluyan las 15 ventas de junio 2026) ----------
ORIG_V = [(1,"2026-06-01 10:15:00",1,1,1),(2,"2026-06-02 11:00:00",2,2,2),(3,"2026-06-03 12:00:00",3,3,3),(4,"2026-06-04 13:00:00",4,1,1),
          (5,"2026-06-05 14:00:00",5,2,2),(6,"2026-06-06 15:00:00",6,3,4),(7,"2026-06-07 16:00:00",7,1,5),(8,"2026-06-08 17:00:00",8,2,1),
          (9,"2026-06-09 18:00:00",9,3,2),(10,"2026-06-10 19:00:00",10,1,3),(11,"2026-06-11 20:00:00",11,2,4),(12,"2026-06-12 21:00:00",12,3,1),
          (13,"2026-06-13 10:30:00",1,1,2),(14,"2026-06-14 11:30:00",2,2,3),(15,"2026-06-15 12:30:00",3,3,4)]
ORIG_D = [(6,8.5,1,1),(2,12.5,1,9),(2,7,1,13),(2,45,2,3),(1,28,2,11),(1,145,3,8),(1,75,3,12),(2,58,4,4),(1,42,4,5),(3,8.5,4,10),
          (1,95,5,7),(2,22,5,14),(2,39,6,6),(1,33,6,5),(3,12.5,6,9),(3,9,7,2),(2,8.5,7,1),(2,45,8,3),(1,58,8,4),(1,7,8,13),
          (1,120,9,8),(1,78,9,7),(2,17.5,9,14),(3,8.5,10,1),(2,12.5,10,9),(1,22,10,14),(2,75,11,12),(2,28,11,11),(2,9,11,2),
          (1,95,12,7),(1,42,12,5),(3,8.5,12,10),(2,58,13,4),(1,39,13,6),(1,145,14,8),(1,45,14,3),(2,22,15,14),(3,8.5,15,1),(1,12.5,15,9)]
EMP_T = {1: "Mañana", 2: "Noche", 3: "Noche", 4: "Mañana", 5: "Mañana", 6: "Noche"}
V = {v[0]: v for v in ventas}
for v in ORIG_V: V[v[0]] = [v[0], None, v[1], v[2], v[3], v[4], "REGISTRADA"]
D = [[k + 1, c, f"{pu:.2f}", v, p] for k, (c, pu, v, p) in enumerate(ORIG_D)] + detalles
print("detalles originales", len(ORIG_D))

# ---------- Export crudo del POS (fuente Big Data) con problemas de calidad reales ----------
raw = []
for dt in D:
    v = V[dt[3]]; p = PROD[dt[4] - 1]
    raw.append([dt[0], v[0], v[2], v[3], MP_NOMBRE[v[4]], v[5], EMP_T[v[5]], dt[4], p[0], CAT[p[3]], dt[1], dt[2], p[2], v[6]])
clean_n = len(raw)
sucio = []
for r in random.sample(raw, 900): sucio.append(list(r))                         # duplicados exactos (re-envío del POS)
for r in random.sample(raw, 300): x = list(r); x[9] = "  " + x[9].upper() + " "; sucio.append(x)  # categoría mal escrita (dup)
for r in random.sample(raw, 120): x = list(r); x[10] = -x[10]; x[0] = 9000000 + len(sucio); sucio.append(x)          # cantidad negativa
for r in random.sample(raw, 150): r[4] = ""                                                                          # método de pago vacío (se imputa)
for r in random.sample(raw, 80):  x = list(r); x[2] = "2099-01-01 00:00:00"; x[0] = 9000000 + len(sucio); sucio.append(x)  # fecha inválida
todo = raw + sucio
random.shuffle(todo)
HDR = ["id_detalle", "id_venta", "fecha_venta", "id_cliente", "metodo_pago", "id_empleado", "turno", "id_producto",
       "producto", "categoria", "cantidad", "precio_unitario", "costo_unitario", "estado_venta"]
wcsv(f"{OUT}/bigdata/ventas_pos_raw.csv", HDR, todo)
print("raw", len(todo), "limpias", clean_n, "sucias", len(sucio))

# ---------- Salida esperada del ETL (Data Warehouse) para Power BI ----------
meses = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Setiembre", "Octubre", "Noviembre", "Diciembre"]
dias = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
fer = {(1, 1), (5, 1), (6, 29), (7, 28), (7, 29), (8, 30), (10, 8), (11, 1), (12, 8), (12, 25)}
dimt, x = [], date(2024, 1, 1)
while x <= date(2026, 12, 31):
    dimt.append([int(x.strftime("%Y%m%d")), x.isoformat(), x.year, (x.month - 1) // 3 + 1, x.month, meses[x.month - 1], x.day,
                 dias[x.weekday()], 1 if x.weekday() >= 4 else 0, 1 if (x.month, x.day) in fer else 0,
                 "Campaña" if x.month in (7, 12) else ("Verano" if x.month in (1, 2, 3) else "Regular")])
    x += timedelta(days=1)
wcsv(f"{OUT}/dw/DimTiempo.csv", ["SK_Tiempo", "Fecha", "Anio", "Trimestre", "Mes", "NombreMes", "Dia", "NombreDia",
                                 "EsFinDeSemana", "EsFeriado", "Temporada"], dimt)
wcsv(f"{OUT}/dw/DimHora.csv", ["SK_Hora", "Hora", "Franja", "Turno"],
     [(h, h, "Madrugada" if h < 6 else "Mañana" if h < 12 else "Tarde" if h < 18 else "Noche", "MAÑANA" if h < 17 else "NOCHE") for h in range(24)])
wcsv(f"{OUT}/dw/DimProducto.csv", ["SK_Producto", "IdProducto", "Producto", "Categoria", "EsAlcoholico", "PrecioVenta", "PrecioCompra"],
     [(i + 1, i + 1, p[0].upper(), CAT[p[3]].upper(), "SI" if p[3] in ALCOHOL else "NO", f"{p[1]:.2f}", f"{p[2]:.2f}") for i, p in enumerate(PROD)])
orig_cli = [(1,"Juan","Pérez","García"),(2,"María","López","Torres"),(3,"Carlos","Ramírez","Vega"),(4,"Ana","Flores","Rojas"),
            (5,"Luis","Castillo","Sánchez"),(6,"Rosa","Mendoza","Quispe"),(7,"Jorge","Salazar","Morales"),(8,"Patricia","Navarro","Cruz"),
            (9,"Miguel","Herrera","Silva"),(10,"Carmen","Gutiérrez","Reyes"),(11,"Diego","Vásquez","Campos"),(12,"Lucía","Espinoza","Paredes")]
todos_cli = [(c[0], c[1], c[2]) for c in orig_cli] + [(c[0], c[1], c[2]) for c in cli_rows]
todos_cli.sort()
wcsv(f"{OUT}/dw/DimCliente.csv", ["SK_Cliente", "IdCliente", "ClienteAnonimo", "TipoCliente"],
     [(c[0], c[0], "CLIENTE VARIOS" if c[0] == 13 else f"CLI-{c[0]:05d}", "NO IDENTIFICADO" if c[0] == 13 else "FRECUENTE") for c in todos_cli])
wcsv(f"{OUT}/dw/DimEmpleado.csv", ["SK_Empleado", "IdEmpleado", "Empleado", "Cargo", "Turno"],
     [(1, 1, "JOSÉ FERNÁNDEZ", "VENDEDOR", "MAÑANA"), (2, 2, "ANDREA CÁRDENAS", "VENDEDOR", "NOCHE"), (3, 3, "RICARDO SUÁREZ", "SUPERVISOR", "NOCHE"),
      (4, 4, "KATHERINE MEDINA", "CAJERO", "MAÑANA"), (5, 5, "FERNANDO RÍOS", "ADMINISTRADOR", "MAÑANA"), (6, 6, "PAOLA DELGADO", "CAJERO", "NOCHE")])
wcsv(f"{OUT}/dw/DimMetodoPago.csv", ["SK_MetodoPago", "IdMetodoPago", "MetodoPago", "EsDigital"],
     [(k, k, v.upper(), "NO" if k == 1 else "SI") for k, v in MP_NOMBRE.items()])
fact = []
for dt in D:
    v = V[dt[3]]
    if v[6] == "ANULADA": continue
    p = PROD[dt[4] - 1]; fecha = v[2]
    imp = round(dt[1] * float(dt[2]), 2); costo = round(dt[1] * float(dt[2]) * p[2] / p[1], 2)   # regla R5 del ETL
    fact.append([dt[0], int(fecha[:10].replace("-", "")), int(fecha[11:13]), dt[4], v[3], v[5], v[4], v[0], dt[1],
                 f"{imp:.2f}", f"{costo:.2f}", f"{imp - costo:.2f}"])
wcsv(f"{OUT}/dw/FactVentas.csv", ["IdDetalle", "SK_Tiempo", "SK_Hora", "SK_Producto", "SK_Cliente", "SK_Empleado", "SK_MetodoPago",
                                  "NroVenta", "Cantidad", "Importe", "Costo", "Margen"], fact)

# ---------- NoSQL: pedidos por delivery (WhatsApp) y reseñas, estructura variable ----------
distritos = ["Los Olivos", "San Martín de Porres", "Independencia", "Comas", "Puente Piedra", "Carabayllo"]
resenas = {5: ["Llegó heladita y rápido, excelente.", "Muy buena atención, siempre tienen stock."],
           4: ["Buen servicio, demoró un poco el delivery.", "Precios justos, faltó hielo."],
           3: ["El pedido llegó completo pero tarde.", "No aceptaron Plin esa noche."],
           2: ["La cerveza llegó tibia.", "Se equivocaron de marca de pisco."],
           1: ["Nunca llegó el pedido y no contestan.", "Me cobraron de más por Yape."]}
docs = []
cand = [v for v in ventas if v[3] != 13 and v[6] == "REGISTRADA" and int(v[2][11:13]) >= 18]
for v in random.sample(cand, 1500):
    r = random.choices([5, 4, 3, 2, 1], [.41, .27, .15, .10, .07])[0]
    doc = {"id_venta": {"$numberInt": str(v[0])}, "id_cliente": {"$numberInt": str(v[3])},
           "fecha_pedido": {"$date": v[2].replace(" ", "T") + ".000Z"}, "canal": random.choice(["WhatsApp", "WhatsApp", "Llamada", "Facebook"]),
           "entrega": {"distrito": random.choice(distritos), "minutos": {"$numberInt": str(random.randint(12, 75))}, "repartidor": random.choice(["Moto 1", "Moto 2"])},
           "estado": "ENTREGADO"}
    if random.random() < .55:
        doc["resena"] = {"calificacion": {"$numberInt": str(r)}, "comentario": random.choice(resenas[r]),
                         "etiquetas": random.sample(["rapidez", "temperatura", "precio", "atencion", "pago"], random.randint(1, 2))}
    if r <= 2 and "resena" in doc:
        doc["incidencia"] = {"tipo": random.choice(["Demora", "Producto equivocado", "Cobro incorrecto"]), "estado": random.choice(["ABIERTA", "CERRADA"])}
    if random.random() < .04: doc["estado"] = "CANCELADO"
    docs.append(doc)
with open(f"{OUT}/nosql/pedidos_delivery.json", "w", encoding="utf-8") as f:
    json.dump(docs, f, ensure_ascii=False, indent=1)

tot = sum(float(f[9]) for f in fact)
print(f"ventas {len(ventas)+15} | detalles {len(D)} | fact {len(fact)} | importe DW S/ {tot:,.2f} | pedidos {len(ped)} | det.pedido {len(dped)}")
