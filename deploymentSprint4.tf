# ***************** Universidad de los Andes ***********************
# ****** Departamento de Ingeniería de Sistemas y Computación ******
# ********** Arquitectura y diseño de Software - ISIS2503 **********
#
# Infraestructura para el proyecto BITE.co — Sprint 4
#
# Elementos a desplegar en AWS:
# 1. Grupos de seguridad:
#    - biteco-traffic-alb        (puerto 80 público)
#    - biteco-traffic-microserv  (puertos 8001, 8002, 8003 desde ALB + SSH)
#    - biteco-traffic-db         (puerto 5432 + SSH)
#    - biteco-traffic-redis      (puerto 6379 desde microservicios + SSH)
#
# 2. Instancias EC2 Base de Datos:
#    - biteco-accounts-db          (PostgreSQL: accounts_db)
#    - biteco-usuarios-db-primary  (PostgreSQL: usuarios_db, primary)
#    - biteco-usuarios-db-replica  (PostgreSQL: usuarios_db, hot standby)
#    - biteco-reportes-db-primary  (PostgreSQL: reportes_db, primary)
#    - biteco-reportes-db-replica  (PostgreSQL: reportes_db, hot standby)
#
# 3. Instancia EC2 Redis:
#    - biteco-redis  (Redis: caché MS Reportes + BD MS Nubes)
#
# 4. Instancias EC2 Microservicios:
#    - biteco-ms-usuario   (Django runserver puerto 8001)
#    - biteco-ms-reportes  (Django runserver puerto 8002 + rate limiting + Redis)
#    - biteco-ms-nubes     (FastAPI uvicorn puerto 8003)
#
# 5. Application Load Balancer:
#    - biteco-alb → 3 target groups → ms-usuario, ms-reportes, ms-nubes
# ******************************************************************

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefix used for naming AWS resources"
  type        = string
  default     = "biteco"
}

variable "instance_type" {
  description = "EC2 instance type for all hosts"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  default     = "vockey"
}

provider "aws" {
  region = var.region
}

locals {
  project_name = "${var.project_prefix}-app"

  common_tags = {
    Project   = local.project_name
    ManagedBy = "Terraform"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
}

data "aws_vpc" "default" {
  default = true
}

# ==================== SECURITY GROUPS ====================

# Grupo de seguridad para el Application Load Balancer (puerto 80 público).
resource "aws_security_group" "traffic_alb" {
  name        = "${var.project_prefix}-traffic-alb"
  description = "Allow HTTP traffic to ALB from Internet"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-traffic-alb" })
}

# Grupo de seguridad para los microservicios (puertos 8001, 8002, 8003 y SSH).
resource "aws_security_group" "traffic_microserv" {
  name        = "${var.project_prefix}-traffic-microserv"
  description = "Allow microservice ports from ALB and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MS-Usuario from ALB"
    from_port       = 8001
    to_port         = 8001
    protocol        = "tcp"
    security_groups = [aws_security_group.traffic_alb.id]
  }

  ingress {
    description     = "MS-Reportes from ALB"
    from_port       = 8002
    to_port         = 8002
    protocol        = "tcp"
    security_groups = [aws_security_group.traffic_alb.id]
  }

  ingress {
    description     = "MS-Nubes from ALB"
    from_port       = 8003
    to_port         = 8003
    protocol        = "tcp"
    security_groups = [aws_security_group.traffic_alb.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-traffic-microserv" })
}

# Grupo de seguridad para las bases de datos PostgreSQL (5432 y SSH).
resource "aws_security_group" "traffic_db" {
  name        = "${var.project_prefix}-traffic-db"
  description = "Allow PostgreSQL from microservices and replication between DBs"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from microservices"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.traffic_microserv.id]
  }

  ingress {
    description = "Streaming replication between DB instances"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-traffic-db" })
}

# Grupo de seguridad para Redis (puerto 6379 desde microservicios y SSH).
resource "aws_security_group" "traffic_redis" {
  name        = "${var.project_prefix}-traffic-redis"
  description = "Allow Redis from microservices and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Redis from microservices"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.traffic_microserv.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-traffic-redis" })
}

# ==================== BASE DE DATOS: accounts-db ====================

resource "aws_instance" "accounts_db" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_db.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y postgresql postgresql-contrib
              sudo -u postgres psql -c "CREATE USER biteco_user WITH PASSWORD 'biteco_pass';"
              sudo -u postgres createdb -O biteco_user accounts_db
              sudo -u postgres psql -c "ALTER USER biteco_user WITH SUPERUSER;"
              echo "listen_addresses='*'" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "host all biteco_user 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
              sudo service postgresql restart
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-accounts-db", Role = "database-accounts" })
}

# ==================== BASE DE DATOS: usuarios-db ====================

resource "aws_instance" "usuarios_db_primary" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_db.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y postgresql postgresql-contrib
              sudo -u postgres psql -c "CREATE USER biteco_user WITH PASSWORD 'biteco_pass';"
              sudo -u postgres createdb -O biteco_user usuarios_db
              sudo -u postgres psql -c "ALTER USER biteco_user WITH SUPERUSER;"
              sudo -u postgres psql -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_pass';"
              echo "listen_addresses='*'" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "wal_level=replica" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "max_wal_senders=5" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "wal_keep_size=1GB" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "host all biteco_user 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
              echo "host replication replicator 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
              sudo service postgresql restart
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-usuarios-db-primary", Role = "database-primary" })
}

resource "aws_instance" "usuarios_db_replica" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_db.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y postgresql postgresql-contrib
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-usuarios-db-replica", Role = "database-replica" })
  depends_on = [aws_instance.usuarios_db_primary]
}

# ==================== BASE DE DATOS: reportes-db ====================

resource "aws_instance" "reportes_db_primary" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_db.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y postgresql postgresql-contrib
              sudo -u postgres psql -c "CREATE USER biteco_user WITH PASSWORD 'biteco_pass';"
              sudo -u postgres createdb -O biteco_user reportes_db
              sudo -u postgres psql -c "ALTER USER biteco_user WITH SUPERUSER;"
              sudo -u postgres psql -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_pass';"
              echo "listen_addresses='*'" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "wal_level=replica" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "max_wal_senders=5" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "wal_keep_size=1GB" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
              echo "host all biteco_user 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
              echo "host replication replicator 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
              sudo service postgresql restart
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-reportes-db-primary", Role = "database-primary" })
}

resource "aws_instance" "reportes_db_replica" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_db.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y postgresql postgresql-contrib
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-reportes-db-replica", Role = "database-replica" })
  depends_on = [aws_instance.reportes_db_primary]
}

# ==================== REDIS ====================

resource "aws_instance" "redis" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_redis.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y redis-server
              echo "bind 0.0.0.0" | sudo tee -a /etc/redis/redis.conf
              sudo systemctl restart redis
              sudo systemctl enable redis
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-redis", Role = "cache" })
}

# ==================== MICROSERVICIOS ====================

resource "aws_instance" "ms_usuario" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_microserv.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y python3-pip git build-essential libpq-dev python3-dev python3-venv python3.12-venv postgresql-client
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-ms-usuario", Role = "microservice-usuario" })
  depends_on = [aws_instance.accounts_db, aws_instance.usuarios_db_primary]
}

resource "aws_instance" "ms_reportes" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_microserv.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y python3-pip git build-essential libpq-dev python3-dev python3-venv python3.12-venv postgresql-client redis-tools
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-ms-reportes", Role = "microservice-reportes" })
  depends_on = [aws_instance.reportes_db_primary, aws_instance.redis]
}

resource "aws_instance" "ms_nubes" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.traffic_microserv.id]

  user_data = <<-EOT
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y python3-pip git build-essential python3-dev python3-venv python3.12-venv redis-tools
              EOT

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-ms-nubes", Role = "microservice-nubes" })
  depends_on = [aws_instance.redis]
}

# ==================== APPLICATION LOAD BALANCER ====================

resource "aws_lb" "main" {
  name               = "${var.project_prefix}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.traffic_alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-alb" })
}

# Target Group MS-Usuario (puerto 8001)
resource "aws_lb_target_group" "ms_usuario" {
  name     = "${var.project_prefix}-tg-usuario"
  port     = 8001
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/health-check/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-tg-usuario" })
}

# Target Group MS-Reportes (puerto 8002)
resource "aws_lb_target_group" "ms_reportes" {
  name     = "${var.project_prefix}-tg-reportes"
  port     = 8002
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/health-check/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-tg-reportes" })
}

# Target Group MS-Nubes (puerto 8003)
resource "aws_lb_target_group" "ms_nubes" {
  name     = "${var.project_prefix}-tg-nubes"
  port     = 8003
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/health-check"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = "${var.project_prefix}-tg-nubes" })
}

# Listener HTTP del ALB — enruta por path prefix a cada microservicio
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_usuario.arn
  }
}

resource "aws_lb_listener_rule" "reportes" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_reportes.arn
  }

  condition {
    path_pattern {
      values = ["/api/reportes/*"]
    }
  }
}

resource "aws_lb_listener_rule" "nubes" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_nubes.arn
  }

  condition {
    path_pattern {
      values = ["/api/nubes/*"]
    }
  }
}

resource "aws_lb_listener_rule" "reportes_html" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_reportes.arn
  }

  condition {
    path_pattern {
      values = ["/reportes/*"]
    }
  }
}

resource "aws_lb_listener_rule" "asr_hub" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_reportes.arn
  }

  condition {
    path_pattern {
      values = ["/asr-hub/*"]
    }
  }
}

# Attachments
resource "aws_lb_target_group_attachment" "ms_usuario" {
  target_group_arn = aws_lb_target_group.ms_usuario.arn
  target_id        = aws_instance.ms_usuario.id
  port             = 8001
}

resource "aws_lb_target_group_attachment" "ms_reportes" {
  target_group_arn = aws_lb_target_group.ms_reportes.arn
  target_id        = aws_instance.ms_reportes.id
  port             = 8002
}

resource "aws_lb_target_group_attachment" "ms_nubes" {
  target_group_arn = aws_lb_target_group.ms_nubes.arn
  target_id        = aws_instance.ms_nubes.id
  port             = 8003
}

# ==================== OUTPUTS ====================

output "alb_url" {
  description = "URL pública del ALB"
  value       = "http://${aws_lb.main.dns_name}"
}

output "auth0_callback_url" {
  description = "Pegar en Auth0 → Allowed Callback URLs"
  value       = "http://${aws_lb.main.dns_name}/complete/auth0"
}

output "accounts_db_private_ip" {
  description = "IP privada accounts-db → DB_HOST_DEFAULT en .env"
  value       = aws_instance.accounts_db.private_ip
}

output "usuarios_db_primary_ip" {
  description = "IP privada usuarios-db-primary → DB_HOST_PRIMARY en ms-usuario .env"
  value       = aws_instance.usuarios_db_primary.private_ip
}

output "usuarios_db_replica_ip" {
  description = "IP privada usuarios-db-replica → DB_HOST_REPLICA en ms-usuario .env"
  value       = aws_instance.usuarios_db_replica.private_ip
}

output "reportes_db_primary_ip" {
  description = "IP privada reportes-db-primary → DB_HOST_PRIMARY en ms-reportes .env"
  value       = aws_instance.reportes_db_primary.private_ip
}

output "reportes_db_replica_ip" {
  description = "IP privada reportes-db-replica → DB_HOST_REPLICA en ms-reportes .env"
  value       = aws_instance.reportes_db_replica.private_ip
}

output "redis_private_ip" {
  description = "IP privada Redis → REDIS_URL en ms-reportes y ms-nubes .env"
  value       = aws_instance.redis.private_ip
}

output "ms_usuario_public_ip" {
  description = "IP pública MS-Usuario para verificación directa"
  value       = aws_instance.ms_usuario.public_ip
}

output "ms_reportes_public_ip" {
  description = "IP pública MS-Reportes para verificación directa"
  value       = aws_instance.ms_reportes.public_ip
}

output "ms_nubes_public_ip" {
  description = "IP pública MS-Nubes para verificación directa"
  value       = aws_instance.ms_nubes.public_ip
}
