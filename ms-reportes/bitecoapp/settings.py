"""
Django settings for ms-reportes — Sprint 4.

Cambios respecto al Sprint 3:
- Solo incluye apps de reporte, registroAuditoria, alerta, recursoCloud, registroCosto
- BD propia: reportes_db (primary + replica)
- Se elimina accounts_db y monitoring_db
- Se agrega Redis como caché (django-redis) para ASR-1
- Se agrega django-ratelimit para ASR-S4-SEG
- AUTH_USER_MODEL removido (este MS no gestiona usuarios)
- Auth0 removido (autenticación delegada al MS-Usuario)
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get(
    "SECRET_KEY",
    "django-insecure-reportes-dev-key-cambiar-en-produccion",
)
DEBUG = os.environ.get("DEBUG", "True") == "True"
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "*").split(",")


INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",

    # Rate limiting (ASR-S4-SEG)
    "django_ratelimit",

    "alerta",
    "recursoCloud",
    "registroAuditoria",
    "registroCosto",
    "reporte",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",

    # ASR-14 - registra cada request a endpoints auditables
    "bitecoapp.audit_middleware.AuditMiddleware",
]

ROOT_URLCONF = "bitecoapp.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "bitecoapp.wsgi.application"

# BD propia del MS-Reportes (primary + replica)
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql_psycopg2",
        "NAME": os.environ.get("DB_NAME", "reportes_db"),
        "USER": os.environ.get("DB_USER", "biteco_user"),
        "PASSWORD": os.environ.get("DB_PASSWORD", "biteco_pass"),
        "HOST": os.environ.get("DB_HOST_PRIMARY", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
    },
    "replica": {
        "ENGINE": "django.db.backends.postgresql_psycopg2",
        "NAME": os.environ.get("DB_NAME", "reportes_db"),
        "USER": os.environ.get("DB_USER", "biteco_user"),
        "PASSWORD": os.environ.get("DB_PASSWORD", "biteco_pass"),
        "HOST": os.environ.get("DB_HOST_REPLICA", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
    },
}

DATABASE_ROUTERS = ["bitecoapp.db_router.MonitoringReplicaRouter"]

# Redis como caché (ASR-1 - reduce latencia P95)
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": os.environ.get("REDIS_URL", "redis://localhost:6379/0"),
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
        },
        "TIMEOUT": 3600,  # TTL: 1 hora para reportes mensuales
    }
}

# Rate limiting (ASR-S4-SEG) - 60 requests/minuto por IP
RATELIMIT_USE_CACHE = "default"
RATELIMIT_ENABLE = True

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "simple": {"format": "[%(asctime)s] %(levelname)s %(name)s: %(message)s"},
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "simple"},
    },
    "loggers": {
        "biteco.audit": {"handlers": ["console"], "level": "INFO"},
        "django": {"handlers": ["console"], "level": "INFO"},
    },
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True