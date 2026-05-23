from fastapi import APIRouter

router = APIRouter()

@router.get("/consumo")
def get_consumo_gcp(empresa_id: int, mes: int, anio: int):
    return {"proveedor": "GCP", "empresa_id": empresa_id, "mes": mes, "anio": anio, "costo": 0}
