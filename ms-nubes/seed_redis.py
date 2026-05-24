"""
seed_redis.py — Poblar Redis con datos de consumo cloud para MS-Nubes

Uso:
    python seed_redis.py

Genera datos de consumo cloud para 3 empresas, 12 meses, 2 proveedores (AWS y GCP)
con volúmenes representativos del crecimiento esperado del negocio.
"""
import redis
import json
import os
from decimal import Decimal

REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/1")

# Datos representativos de consumo cloud
EMPRESAS = [
    {"id": 1, "nombre": "Empresa Demo 1"},
    {"id": 2, "nombre": "Empresa Demo 2"},
    {"id": 3, "nombre": "Empresa Demo 3"},
]

PROVEEDORES = {
    "aws": {
        "compute": [1200.50, 1350.75, 1500.00, 1650.25, 1800.50, 1950.75,
                    2100.00, 2250.25, 2400.50, 2550.75, 2700.00, 2850.25],
        "storage": [450.30, 480.60, 510.90, 541.20, 571.50, 601.80,
                    632.10, 662.40, 692.70, 723.00, 753.30, 783.60],
        "network":  [180.20, 195.40, 210.60, 225.80, 241.00, 256.20,
                     271.40, 286.60, 301.80, 317.00, 332.20, 347.40],
    },
    "gcp": {
        "compute": [980.40, 1050.80, 1121.20, 1191.60, 1262.00, 1332.40,
                    1402.80, 1473.20, 1543.60, 1614.00, 1684.40, 1754.80],
        "storage": [320.15, 345.30, 370.45, 395.60, 420.75, 445.90,
                    471.05, 496.20, 521.35, 546.50, 571.65, 596.80],
        "network":  [120.10, 132.20, 144.30, 156.40, 168.50, 180.60,
                     192.70, 204.80, 216.90, 229.00, 241.10, 253.20],
    },
}

ANIO = 2026


def seed():
    r = redis.from_url(REDIS_URL, decode_responses=True)

    count = 0
    for empresa in EMPRESAS:
        for mes in range(1, 13):
            consumo_mes = {}
            for proveedor, servicios in PROVEEDORES.items():
                consumo_proveedor = {}
                for servicio, costos in servicios.items():
                    # Escalar costos por empresa (empresa 2 = 1.5x, empresa 3 = 2x)
                    factor = 1.0 + (empresa["id"] - 1) * 0.5
                    costo = round(costos[mes - 1] * factor, 2)
                    consumo_proveedor[servicio] = costo
                consumo_proveedor["total"] = round(sum(consumo_proveedor.values()), 2)
                consumo_mes[proveedor] = consumo_proveedor

            key = f"empresa:{empresa['id']}:mes:{mes}:anio:{ANIO}"
            r.set(key, json.dumps({
                "empresa_id": empresa["id"],
                "empresa_nombre": empresa["nombre"],
                "mes": mes,
                "anio": ANIO,
                "consumo": consumo_mes,
            }))
            count += 1

    print(f"Seed completo. {count} registros de consumo cloud creados en Redis.")
    print(f"Keys generadas: empresa:{{1-3}}:mes:{{1-12}}:anio:{ANIO}")

    # Verificar un registro
    sample = r.get(f"empresa:1:mes:3:anio:{ANIO}")
    if sample:
        data = json.loads(sample)
        print(f"\nEjemplo — empresa:1:mes:3:anio:{ANIO}:")
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    seed()