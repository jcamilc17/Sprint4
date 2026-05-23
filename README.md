# BITE.co — Sprint 4

Plataforma de optimización de costos cloud (AWS y GCP) para múltiples empresas, migrada a arquitectura de microservicios.

## Stack

- **MS-Usuario**: Django 4.2 + PostgreSQL 16 (usuarios-db Primary/Replica)
- **MS-Reportes**: Django 4.2 + PostgreSQL 16 (reportes-db Primary/Replica) + Redis (caché)
- **MS-Nubes**: FastAPI + Redis (BD principal)
- **Auth**: Auth0 OAuth2 + RBAC (via `social-auth-app-django`) — en MS-Usuario
- **Auditoría**: middleware Django + `RegistroAuditoria` — en MS-Reportes
- **Seguridad**: `django-ratelimit` (rate limiting por IP) — en MS-Reportes
- **Infraestructura**: AWS EC2 + ALB Multi-AZ + PostgreSQL Streaming Replication

## ASRs cubiertos en Sprint 4

| ASR | Atributo | Mecanismo |
|---|---|---|
| **ASR-13** | Mantenimiento | Cada microservicio en instancia EC2 independiente con BD propia |
| **ASR-1** | Desempeño – Latencia | BD dedicada por servicio + Redis caché + Primary/Replica |
| **ASR-S4-SEG** | Seguridad | Rate limiting por IP (`django-ratelimit`) + circuit breaker en MS-Reportes |

## Estructura

```
Sprint4/
├── ms-usuario/                 # Microservicio de gestión de usuarios
│   ├── bitecoapp/
│   │   ├── settings.py         # BD: accounts_db + usuarios_db Primary/Replica
│   │   ├── urls.py             # Auth0 OAuth2 + /api/auth/ + /dashboard/
│   │   ├── audit_middleware.py # Registro de acciones
│   │   └── db_router.py       # reads → replica, writes → primary
│   ├── usuario/                # Modelo Usuario + pipeline Auth0
│   ├── empresa/                # Modelo Empresa
│   ├── templates/base/         # home.html, dashboard.html
│   ├── manage.py
│   └── requirements.txt
│
├── ms-reportes/                # Microservicio de reportes y alertas
│   ├── bitecoapp/
│   │   ├── settings.py         # BD: reportes_db Primary/Replica + Redis caché
│   │   ├── urls.py             # /api/reportes/ + /reportes/ + /asr-hub/
│   │   ├── audit_middleware.py # Registro de acciones
│   │   └── db_router.py       # reads → replica, writes → primary
│   ├── reporte/                # Modelos + lógica + seed_demo
│   ├── registroAuditoria/      # Audit Logger centralizado
│   ├── alerta/                 # Modelos de alerta
│   ├── recursoCloud/           # Modelos de recursos cloud
│   ├── registroCosto/          # Modelos de registro de costos
│   ├── manage.py
│   └── requirements.txt        # Incluye django-ratelimit + django-redis
│
├── ms-nubes/                   # Microservicio de integración cloud (FastAPI)
│   ├── main.py                 # App FastAPI + endpoints /api/nubes/
│   ├── routers/                # Routers por proveedor (aws.py, gcp.py)
│   └── requirements.txt        # fastapi + uvicorn + redis + httpx
│
└── .gitignore
```

## Quick start por microservicio

### MS-Usuario (puerto 8001)

```bash
cd ms-usuario
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# editar .env con las IPs de usuarios-db y accounts-db
python manage.py migrate
python manage.py seed_demo
python manage.py runserver 0.0.0.0:8001
```

### MS-Reportes (puerto 8002)

```bash
cd ms-reportes
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# editar .env con las IPs de reportes-db y Redis
python manage.py migrate
python manage.py seed_demo
python manage.py runserver 0.0.0.0:8002
```

### MS-Nubes (puerto 8003)

```bash
cd ms-nubes
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# editar .env con la IP de Redis
uvicorn main:app --host 0.0.0.0 --port 8003 --workers 2
```

## Variables de entorno por microservicio

### MS-Usuario `.env`

```
SECRET_KEY=...
DEBUG=False
ALLOWED_HOSTS=*
DB_NAME_DEFAULT=accounts_db
DB_NAME=usuarios_db
DB_USER=biteco_user
DB_PASSWORD=biteco_pass
DB_HOST_DEFAULT=<ACCOUNTS_DB_IP>
DB_HOST_PRIMARY=<USUARIOS_DB_PRIMARY_IP>
DB_HOST_REPLICA=<USUARIOS_DB_REPLICA_IP>
DB_PORT=5432
AUTH0_DOMAIN=<TU_AUTH0_DOMAIN>
AUTH0_CLIENT_ID=<TU_CLIENT_ID>
AUTH0_CLIENT_SECRET=<TU_CLIENT_SECRET>
ALB_URL=http://<ALB_DNS>
```

### MS-Reportes `.env`

```
SECRET_KEY=...
DEBUG=False
ALLOWED_HOSTS=*
DB_NAME=reportes_db
DB_USER=biteco_user
DB_PASSWORD=biteco_pass
DB_HOST_PRIMARY=<REPORTES_DB_PRIMARY_IP>
DB_HOST_REPLICA=<REPORTES_DB_REPLICA_IP>
DB_PORT=5432
REDIS_URL=redis://<REDIS_IP>:6379/0
```

### MS-Nubes `.env`

```
REDIS_URL=redis://<REDIS_IP>:6379/1
AWS_ACCESS_KEY_ID=<TU_AWS_KEY>
AWS_SECRET_ACCESS_KEY=<TU_AWS_SECRET>
AWS_REGION=us-east-1
GCP_PROJECT_ID=<TU_GCP_PROJECT>
```

## URLs principales por microservicio

### MS-Usuario `:8001`

| Ruta | Descripción | Auth |
|---|---|---|
| `/` | Landing pública | — |
| `/login/auth0` | Inicia OAuth2 con Auth0 | — |
| `/dashboard/` | Dashboard post-login | login |
| `/api/auth/login` | API JSON login | — |
| `/health-check/` | Para el ALB | — |

### MS-Reportes `:8002`

| Ruta | Descripción | Auth |
|---|---|---|
| `/reportes/` | Reporte mensual (HTML) | login |
| `/asr-hub/` | ASR Testing Hub | login |
| `/asr-hub/auditoria/` | Tabla completa de auditoría | login |
| `/api/reportes/mensual` | API JSON de reporte | JWT |
| `/health-check/` | Para el ALB | — |

### MS-Nubes `:8003`

| Ruta | Descripción | Auth |
|---|---|---|
| `/api/nubes/consumo` | Consumo cloud consolidado | — |
| `/api/nubes/aws/...` | Endpoints AWS | — |
| `/api/nubes/gcp/...` | Endpoints GCP | — |
| `/health-check` | Para el ALB | — |

## Cambios respecto al Sprint 3

| Componente | Sprint 3 | Sprint 4 |
|---|---|---|
| Arquitectura | Monolito Django | 3 microservicios independientes |
| Servidores web | web-1, web-2 (Django) | ms-usuario, ms-reportes (Django) + ms-nubes (FastAPI) |
| Base de datos | monitoring_db compartida | reportes_db + usuarios_db independientes |
| Caché | Sin caché | Redis en MS-Reportes (TTL 1h) |
| Seguridad | Auth0 + middleware | + Rate limiting por IP (django-ratelimit) |
| Pruebas de carga | JMeter | k6 |

## Documentación adicional

- **`docs/AWS_SETUP.md`** — Despliegue AWS (Terraform + EC2 + ALB)
- **`docs/AUTH0_SETUP.md`** — Configuración Auth0
- **`docs/ASR_TESTING.md`** — Cómo validar cada ASR
- **`guiaSprint4.md`** — Guía maestra de despliegue paso a paso
EOF