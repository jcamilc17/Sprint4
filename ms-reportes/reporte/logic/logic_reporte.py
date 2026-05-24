"""
reporte/logic/logic_reporte.py - Logica de negocio de reportes Sprint 4.
Cambio: se elimina .using("monitoring_replica") — ahora usa el router.
"""
from collections import defaultdict
from decimal import Decimal
from reporte.models import ConsumoCloud

def get_reporte_mensual(empresa_id, mes, anio):
    return ConsumoCloud.objects.filter(
        empresa_id=empresa_id,
        mes=mes,
        anio=anio,
    )

def get_total_por_proveedor(empresa_id, mes, anio):
    consumos = get_reporte_mensual(empresa_id, mes, anio)
    totales = defaultdict(Decimal)
    for c in consumos:
        totales[c.proveedor] += c.costo
    return {k: float(v) for k, v in totales.items()}