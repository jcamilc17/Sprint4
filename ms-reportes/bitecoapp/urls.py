"""
bitecoapp/urls.py — MS-Reportes Sprint 4

Solo expone:
- /health-check/
- /api/reportes/  (con rate limiting para ASR-S4-SEG)
- /reportes/      (HTML)
- /asr-hub/       (auditoría)
"""
from django.contrib import admin
from django.http import HttpResponse
from django.urls import path, include
from django_ratelimit.decorators import ratelimit


def health_check(request):
    """Endpoint para el ALB. NO auditado, NO autenticado."""
    return HttpResponse("OK", status=200)


urlpatterns = [
    path("admin/", admin.site.urls),
    path("health-check/", health_check, name="health_check"),

    # HTML
    path("reportes/", include("reporte.urls_html")),
    path("asr-hub/", include("registroAuditoria.urls_html")),

    # API JSON con rate limiting (ASR-S4-SEG)
    path("api/reportes/", include("reporte.urls")),
]