"""
reporte/views.py - API JSON de reportes.
Cambios respecto al original:
1. Si el usuario no esta autenticado (no hay sesion Django), retorna 401.
2. Si el usuario autenticado intenta acceder a otra empresa que la del JWT,
   retorna 403 (cumpliendo ASR-01 escenario 4 del informe).
3. La auditoria se hace automaticamente en AuditMiddleware - no se duplica aqui.
4. Rate limiting por IP: 60 requests/minuto (ASR-S4-SEG)
"""
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django_ratelimit.decorators import ratelimit
from reporte.logic.logic_reporte import get_total_por_proveedor

@csrf_exempt
@ratelimit(key='header:X-Forwarded-For', rate='60/m', method='GET', block=False)
def reporte_mensual(request):
    if request.method != "GET":
        return JsonResponse({"error": "Metodo no permitido"}, status=405)

    # === ASR-S4-SEG: Rate limiting ===
    if getattr(request, 'limited', False):
        return JsonResponse(
            {"error": "Too Many Requests", "reason": "Rate limit exceeded"},
            status=429,
            headers={"Retry-After": "60"}
        )

    # === ASR-01: Autenticación ===
    if not request.user.is_authenticated:
        return JsonResponse(
            {"error": "Unauthorized", "reason": "Authentication required"},
            status=401,
        )

    # === Parametros ===
    try:
        empresa_id_param = int(request.GET.get("empresa_id", 1))
        mes = int(request.GET.get("mes", 3))
        anio = int(request.GET.get("anio", 2026))
    except (TypeError, ValueError):
        return JsonResponse({"error": "Parametros invalidos"}, status=400)

    # === ASR-01: Acceso cruzado entre empresas ===
    user_empresa = getattr(request.user, "empresa_id", None)
    user_rol = getattr(request.user, "rol", "Usuario")
    if user_rol != "Admin" and user_empresa is not None and empresa_id_param != user_empresa:
        return JsonResponse(
            {
                "error": "Forbidden",
                "reason": "Cross-empresa access blocked",
                "your_empresa": user_empresa,
                "requested": empresa_id_param,
            },
            status=403,
        )

    # === Lógica de negocio ===
    totales = get_total_por_proveedor(empresa_id_param, mes, anio)
    return JsonResponse({
        "empresa_id": empresa_id_param,
        "mes": mes,
        "anio": anio,
        "total_por_proveedor": totales,
    })