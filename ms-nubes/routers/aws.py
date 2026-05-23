from fastapi import APIRouter

router = APIRouter()

@router.get("/consumo")
def get_consumo_aws(empresa_id: int, mes: int, anio: int):
    return {"proveedor": "AWS", "empresa_id": empresa_id, "mes": mes, "anio": anio, "costo": 0}
