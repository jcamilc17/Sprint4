"""
bitecoapp/urls.py — MS-Usuario Sprint 4

Expone:
- /health-check/
- /login/auth0, /complete/auth0, /logout/  (Auth0 OAuth2)
- /dashboard/
- /api/auth/  (API JSON)
"""
from django.contrib import admin
from django.contrib.auth.decorators import login_required
from django.contrib.auth import logout
from django.shortcuts import render, redirect
from django.urls import path, include
from django.http import HttpResponse
import os


def health_check(request):
    """Endpoint para el ALB. NO auditado, NO autenticado."""
    return HttpResponse("OK", status=200)


def home(request):
    if request.user.is_authenticated:
        return redirect("/dashboard/")
    return render(request, "base/home.html")


@login_required
def dashboard_view(request):
    return render(request, "base/dashboard.html", {
        "user": request.user,
        "rol": getattr(request.user, "rol", "Usuario"),
        "empresa_id": getattr(request.user, "empresa_id", None),
    })


def custom_logout(request):
    logout(request)
    domain = os.environ.get("AUTH0_DOMAIN")
    client_id = os.environ.get("AUTH0_CLIENT_ID")
    alb_url = os.environ.get("ALB_URL", "http://localhost:8001")
    return redirect(
        f"https://{domain}/v2/logout"
        f"?client_id={client_id}"
        f"&returnTo={alb_url}"
    )


urlpatterns = [
    path("admin/", admin.site.urls),
    path("health-check/", health_check, name="health_check"),

    # Auth0 OAuth2
    path("", include("social_django.urls", namespace="social")),
    path("logout/", custom_logout, name="logout"),

    # HTML
    path("", home, name="home"),
    path("dashboard/", dashboard_view, name="dashboard"),

    # API JSON
    path("api/auth/", include("usuario.urls")),
]