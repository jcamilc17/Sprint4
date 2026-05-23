"""
ms-nubes/main.py — Microservicio de Nubes (FastAPI) — Sprint 4

Responsabilidad: consumo de datos de AWS y GCP, almacenados en Redis.
Puerto: 8003
"""
from fastapi import FastAPI
from routers import aws, gcp
import redis
import os

app = FastAPI(title="MS-Nubes BITE.CO", version="1.0.0")

# Conexión a Redis (BD principal de este microservicio)
redis_client = redis.from_url(
    os.environ.get("REDIS_URL", "redis://localhost:6379/1"),
    decode_responses=True
)

# Routers por proveedor cloud
app.include_router(aws.router, prefix="/api/nubes/aws", tags=["AWS"])
app.include_router(gcp.router, prefix="/api/nubes/gcp", tags=["GCP"])


@app.get("/health-check")
def health_check():
    """Endpoint para el ALB."""
    return {"status": "ok"}


@app.get("/api/nubes/consumo")
def get_consumo(empresa_id: int, mes: int, anio: int):
    """
    Retorna el consumo cloud consolidado (AWS + GCP) para una empresa y mes.
    Busca primero en Redis; si no existe, retorna vacío.
    """
    key = f"empresa:{empresa_id}:mes:{mes}:anio:{anio}"
    data = redis_client.get(key)
    if data:
        import json
        return {"empresa_id": empresa_id, "mes": mes, "anio": anio, "consumo": json.loads(data)}
    return {"empresa_id": empresa_id, "mes": mes, "anio": anio, "consumo": {}}