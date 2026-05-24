# GUÍA MAESTRA DE DESPLIEGUE — BITE.co Sprint 4
# =========================================================
# ORDEN:
#   1. CloudShell → terraform apply
#   2. EC2 → usuarios-db-primary → fix pg_hba.conf
#   3. EC2 → usuarios-db-replica → streaming replication
#   4. EC2 → reportes-db-primary → fix pg_hba.conf
#   5. EC2 → reportes-db-replica → streaming replication
#   6. EC2 → redis-server → fix protected-mode y bind
#   7. EC2 → ms-usuario → clonar, instalar, migrate, runserver
#   8. EC2 → ms-reportes → clonar, instalar, migrate, seed, gunicorn
#   9. EC2 → ms-nubes → clonar, instalar, uvicorn (FastAPI)
#  10. Auth0 Dashboard → registrar callback URL del ALB
# =========================================================


# ==============================================================
# ANTES DE EMPEZAR — valores que necesitas tener a mano
# ==============================================================
# De manage.auth0.com → Applications → tu app → Settings:
#   AUTH0_DOMAIN        = dev-lhsedsl4b3teyxes.us.auth0.com
#   AUTH0_CLIENT_ID     = UGG4z0BT5d2t3HcOt6LdVehrY5K5Qpkw
#   AUTH0_CLIENT_SECRET = pP3B0TkrhBj0VvsAO0tBSJS7g4wozh4_D6YIryAryvK6L6TqrkxpiN97P0GZh4rkt


# ==============================================================
# PASO 1 — CLOUDSHELL: lanzar Terraform
# ==============================================================
cd ~/biteco-infra
cat > main.tf   # pegar contenido de deploymentSprint4.tf
terraform apply
# Escribe "yes". Tarda ~5-8 minutos.

# Outputs del último despliegue:
#   accounts_db_private_ip  = "172.31.16.43"
#   alb_url                 = "http://biteco-alb-308585655.us-east-1.elb.amazonaws.com"
#   auth0_callback_url      = "http://biteco-alb-308585655.us-east-1.elb.amazonaws.com/complete/auth0"
#   ms_nubes_public_ip      = "100.31.94.159"
#   ms_reportes_public_ip   = "98.88.29.20"
#   ms_usuario_public_ip    = "54.160.249.152"
#   redis_private_ip        = "172.31.27.148"
#   reportes_db_primary_ip  = "172.31.20.147"
#   reportes_db_replica_ip  = "172.31.18.91"
#   usuarios_db_primary_ip  = "172.31.18.31"
#   usuarios_db_replica_ip  = "172.31.19.146"


# ==============================================================
# PASO 2 — USUARIOS-DB-PRIMARY: fix pg_hba.conf para la réplica
# ==============================================================
# EC2 → biteco-usuarios-db-primary → Connect → EC2 Instance Connect

echo "host replication replicator <USUARIOS_DB_REPLICA_IP>/32 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
sudo systemctl restart postgresql@16-main
sudo systemctl status postgresql@16-main | grep Active
# Debe mostrar: Active: active (running)


# ==============================================================
# PASO 3 — USUARIOS-DB-REPLICA: configurar streaming replication
# ==============================================================
# EC2 → biteco-usuarios-db-replica → Connect → EC2 Instance Connect

sudo systemctl stop postgresql@16-main

sudo rm -rf /var/lib/postgresql/16/main
sudo mkdir -p /var/lib/postgresql/16/main
sudo chown postgres:postgres /var/lib/postgresql/16/main
sudo chmod 700 /var/lib/postgresql/16/main

PRIMARY_IP=<USUARIOS_DB_PRIMARY_IP>

sudo -u postgres PGPASSWORD=replicator_pass pg_basebackup \
  -h $PRIMARY_IP -U replicator \
  -D /var/lib/postgresql/16/main \
  -P -R -X stream -C -S replica_slot_usuarios

sudo chown -R postgres:postgres /var/lib/postgresql/16/main
sudo chmod 700 /var/lib/postgresql/16/main

echo "listen_addresses='*'" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
echo "host all biteco_user 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf

sudo systemctl start postgresql@16-main

# Verificar réplica (debe retornar "t"):
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"


# ==============================================================
# PASO 4 — REPORTES-DB-PRIMARY: fix pg_hba.conf para la réplica
# ==============================================================
# EC2 → biteco-reportes-db-primary → Connect → EC2 Instance Connect

echo "host replication replicator <REPORTES_DB_REPLICA_IP>/32 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
sudo systemctl restart postgresql@16-main
sudo systemctl status postgresql@16-main | grep Active
# Debe mostrar: Active: active (running)


# ==============================================================
# PASO 5 — REPORTES-DB-REPLICA: configurar streaming replication
# ==============================================================
# EC2 → biteco-reportes-db-replica → Connect → EC2 Instance Connect

sudo systemctl stop postgresql@16-main

sudo rm -rf /var/lib/postgresql/16/main
sudo mkdir -p /var/lib/postgresql/16/main
sudo chown postgres:postgres /var/lib/postgresql/16/main
sudo chmod 700 /var/lib/postgresql/16/main

PRIMARY_IP=<REPORTES_DB_PRIMARY_IP>

sudo -u postgres PGPASSWORD=replicator_pass pg_basebackup \
  -h $PRIMARY_IP -U replicator \
  -D /var/lib/postgresql/16/main \
  -P -R -X stream -C -S replica_slot_reportes

sudo chown -R postgres:postgres /var/lib/postgresql/16/main
sudo chmod 700 /var/lib/postgresql/16/main

echo "listen_addresses='*'" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
echo "host all biteco_user 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf

sudo systemctl start postgresql@16-main

# Verificar réplica (debe retornar "t"):
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"


# ==============================================================
# PASO 6 — REDIS-SERVER: fix protected-mode y bind
# ==============================================================
# EC2 → biteco-redis → Connect → EC2 Instance Connect

# ⚠️ IMPORTANTE: hacer estos dos fixes o Redis rechazará conexiones externas

# Fix 1: deshabilitar protected-mode
sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# Fix 2: comentar el bind restrictivo (dejar solo el bind 0.0.0.0)
sudo sed -i 's/^bind 127.0.0.1 -::1/# bind 127.0.0.1 -::1/' /etc/redis/redis.conf

sudo systemctl restart redis

# Verificar:
redis-cli ping
# Debe retornar: PONG


# ==============================================================
# PASO 7 — MS-USUARIO: clonar, instalar, migrate y runserver
# ==============================================================
# EC2 → biteco-ms-usuario → Connect → EC2 Instance Connect

cd /home/ubuntu
git clone https://github.com/jcamilc17/Sprint4.git
cd Sprint4/ms-usuario

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cat > .env << 'ENVEOF'
DEBUG=False
SECRET_KEY=clave-secreta-aleatoria-larga-aqui
ALLOWED_HOSTS=*
DB_NAME=accounts_db
DB_USER=biteco_user
DB_PASSWORD=biteco_pass
DB_HOST=<ACCOUNTS_DB_PRIVATE_IP>
DB_PORT=5432
AUTH0_DOMAIN=dev-lhsedsl4b3teyxes.us.auth0.com
AUTH0_CLIENT_ID=UGG4z0BT5d2t3HcOt6LdVehrY5K5Qpkw
AUTH0_CLIENT_SECRET=pP3B0TkrhBj0VvsAO0tBSJS7g4wozh4_D6YIryAryvK6L6TqrkxpiN97P0GZh4rkt
ALB_URL=http://<ALB_DNS>
ENVEOF

export $(grep -v '^#' .env | xargs)

# ⚠️ IMPORTANTE: crear la tabla usuario_usuario manualmente antes de migrar
# Esto es necesario porque social_django tiene FK a esta tabla y falla si no existe
psql accounts_db -U biteco_user -h <ACCOUNTS_DB_PRIVATE_IP> -c "
CREATE TABLE IF NOT EXISTS usuario_usuario (
    id SERIAL PRIMARY KEY,
    password VARCHAR(128) NOT NULL,
    last_login TIMESTAMPTZ,
    is_superuser BOOLEAN NOT NULL,
    username VARCHAR(150) NOT NULL UNIQUE,
    first_name VARCHAR(150) NOT NULL,
    last_name VARCHAR(150) NOT NULL,
    email VARCHAR(254) NOT NULL,
    is_staff BOOLEAN NOT NULL,
    is_active BOOLEAN NOT NULL,
    date_joined TIMESTAMPTZ NOT NULL,
    nombre_negocio VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    rol VARCHAR(50) NOT NULL,
    telefono VARCHAR(15) NOT NULL,
    estado VARCHAR(50) NOT NULL,
    fechaCreacion DATE NOT NULL,
    ultimoAcceso DATE NOT NULL,
    empresa_id INTEGER
);"

# Marcar migración de usuario como aplicada y migrar el resto
python manage.py migrate usuario --fake
python manage.py migrate

# Arrancar el servidor
python manage.py runserver 0.0.0.0:8001


# ==============================================================
# PASO 8 — MS-REPORTES: clonar, instalar, migrate, seed y gunicorn
# ==============================================================
# EC2 → biteco-ms-reportes → Connect → EC2 Instance Connect

cd /home/ubuntu
git clone https://github.com/jcamilc17/Sprint4.git
cd Sprint4/ms-reportes

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn

cat > .env << 'ENVEOF'
DEBUG=False
SECRET_KEY=clave-secreta-aleatoria-larga-aqui
ALLOWED_HOSTS=*
DB_NAME=reportes_db
DB_USER=biteco_user
DB_PASSWORD=biteco_pass
DB_HOST_PRIMARY=<REPORTES_DB_PRIMARY_IP>
DB_HOST_REPLICA=<REPORTES_DB_REPLICA_IP>
DB_PORT=5432
REDIS_URL=redis://<REDIS_PRIVATE_IP>:6379/0
ALB_URL=http://<ALB_DNS>
ENVEOF

export $(grep -v '^#' .env | xargs)

# ⚠️ IMPORTANTE: actualizar el db_router para Sprint 4 (el del Sprint 3 usa 'monitoring')
cat > bitecoapp/db_router.py << 'ROUTEREOF'
class ReportesReplicaRouter:
    def db_for_read(self, model, **hints):
        return "default"
    def db_for_write(self, model, **hints):
        return "default"
    def allow_relation(self, obj1, obj2, **hints):
        return True
    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == "default"
ROUTEREOF

python manage.py migrate

# ⚠️ IMPORTANTE: crear tabla reporte_consumocloud manualmente antes del seed
psql reportes_db -U biteco_user -h <REPORTES_DB_PRIMARY_IP> -c "
CREATE TABLE IF NOT EXISTS reporte_consumocloud (
    id bigserial PRIMARY KEY,
    empresa_id integer NOT NULL,
    empresa_nombre varchar(100) NOT NULL,
    proveedor varchar(20) NOT NULL,
    servicio varchar(100) NOT NULL,
    costo numeric(12,4) NOT NULL,
    mes integer NOT NULL,
    anio integer NOT NULL,
    region varchar(50)
);"

python manage.py seed_demo
# Debe mostrar: Seed completo. 27 filas de ConsumoCloud creadas.

# ⚠️ IMPORTANTE: usar gunicorn en vez de runserver para aguantar carga de los experimentos
gunicorn bitecoapp.wsgi:application --bind 0.0.0.0:8002 --workers 4


# ==============================================================
# PASO 9 — MS-NUBES: clonar, instalar y arrancar con uvicorn
# ==============================================================
# EC2 → biteco-ms-nubes → Connect → EC2 Instance Connect

cd /home/ubuntu
git clone https://github.com/jcamilc17/Sprint4.git
cd Sprint4/ms-nubes

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cat > .env << 'ENVEOF'
REDIS_URL=redis://<REDIS_PRIVATE_IP>:6379/1
ALB_URL=http://<ALB_DNS>
ENVEOF

export $(grep -v '^#' .env | xargs)

uvicorn main:app --host 0.0.0.0 --port 8003 --workers 2


# ==============================================================
# PASO 10 — AUTH0 DASHBOARD: actualizar URLs con el nuevo ALB
# ==============================================================
# ⚠️ IMPORTANTE — Hacer esto CADA VEZ que se redespliegue
#
# manage.auth0.com → Applications → BITE.CO → Settings:
#
#   Allowed Callback URLs:
#     http://<ALB_DNS>/complete/auth0
#
#   Allowed Logout URLs:
#     http://<ALB_DNS>
#
#   Allowed Web Origins:
#     http://<ALB_DNS>
#
#   Save Changes
#
# Tenant Settings → Advanced → Allowed Logout URLs:
#   http://<ALB_DNS>
#   Save


# ==============================================================
# PASO 11 — VERIFICACIÓN FINAL
# ==============================================================

# Health check general (desde tu Mac):
curl http://<ALB_DNS>/health-check/
# Debe retornar: OK

# Endpoint de nubes:
curl "http://<ALB_DNS>/api/nubes/consumo?empresa_id=1&mes=3&anio=2026"
# Debe retornar: {"empresa_id":1,"mes":3,"anio":2026,"consumo":{}}

# Endpoint de reportes (retorna Unauthorized — correcto, está protegido):
curl "http://<ALB_DNS>/api/reportes/mensual?empresa_id=1&mes=3&anio=2026"
# Debe retornar: {"error": "Unauthorized", "reason": "Authentication required"}

# Verificar rate limiting (primeros 60 dan 401, del 61 en adelante dan 429):
for i in {1..65}; do curl -s -o /dev/null -w "%{http_code}\n" "http://<ALB_DNS>/api/reportes/mensual?empresa_id=1&mes=3&anio=2026"; done

# Verificar replicación usuarios-db (en biteco-usuarios-db-primary):
sudo -u postgres psql -c "SELECT client_addr, state FROM pg_stat_replication;"

# Verificar replicación reportes-db (en biteco-reportes-db-primary):
sudo -u postgres psql -c "SELECT client_addr, state FROM pg_stat_replication;"

# Verificar Redis:
redis-cli -h <REDIS_PRIVATE_IP> ping
# Debe retornar: PONG


# ==============================================================
# REFERENCIA RÁPIDA — Reiniciar microservicios
# ==============================================================

# MS-Usuario (Django runserver):
cd /home/ubuntu/Sprint4/ms-usuario
source venv/bin/activate
export $(grep -v '^#' .env | xargs)
python manage.py runserver 0.0.0.0:8001

# MS-Reportes (Gunicorn):
cd /home/ubuntu/Sprint4/ms-reportes
source venv/bin/activate
export $(grep -v '^#' .env | xargs)
pkill gunicorn   # si ya hay uno corriendo
gunicorn bitecoapp.wsgi:application --bind 0.0.0.0:8002 --workers 4

# MS-Nubes (FastAPI uvicorn):
cd /home/ubuntu/Sprint4/ms-nubes
source venv/bin/activate
export $(grep -v '^#' .env | xargs)
uvicorn main:app --host 0.0.0.0 --port 8003 --workers 2

# Puertos por microservicio:
#   MS-Usuario  → 8001
#   MS-Reportes → 8002
#   MS-Nubes    → 8003
#   Redis       → 6379


# ==============================================================
# REFERENCIA RÁPIDA — Correr experimentos k6
# ==============================================================
# Los scripts están en Sprint4/tests/

# ASR-13 (Mantenimiento) — 3 minutos:
k6 run tests/experimento_asr13.js
# Al minuto 1: reiniciar MS-Reportes en EC2

# ASR-1 (Latencia) — 13 minutos:
k6 run tests/experimento_asr1.js

# ASR-S4-SEG (Seguridad) — 3 minutos:
k6 run tests/experimento_seguridad.js


# ==============================================================
# NOTA — Si reinicias las instancias EC2
# ==============================================================
# Ningún proceso persiste entre reinicios. Volver a correr
# el comando correspondiente en cada instancia.