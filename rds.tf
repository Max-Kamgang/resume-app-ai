# ─────────────────────────────────────────────
# DB Subnet Group
# ─────────────────────────────────────────────
resource "aws_db_subnet_group" "rp_db_subnet_group" {
  name        = "rp-db-subnet-group"
  description = "Private subnets for resume portal RDS"
  subnet_ids = [
    aws_subnet.rp_private_1a.id,
    aws_subnet.rp_private_1b.id
  ]


  tags = {
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# RDS PostgreSQL Instance
# ─────────────────────────────────────────────
resource "aws_db_instance" "rp_db" {
  identifier     = "rp-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"


  # Storage
  storage_type          = "gp3"
  allocated_storage     = 20
  max_allocated_storage = 0 # disables autoscaling


  # Credentials — single source of truth (see variables.tf / Secrets Manager)
  db_name  = "postgres"
  username = var.db_username
  password = var.db_password


  # Networking
  db_subnet_group_name   = aws_db_subnet_group.rp_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rp_rds_sg.id]
  publicly_accessible    = false
  port                   = 5432


  # Encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rp_rds_key.arn


  # Availability
  availability_zone = local.az_a
  multi_az          = false


  # Backups — disabled (free tier restriction on retention period)
  backup_retention_period = 0
  maintenance_window      = "mon:04:00-mon:05:00"


  # Misc
  skip_final_snapshot = true
  deletion_protection = false


  # Une instance RDS neuve met souvent 5 a 15 min, parfois plus sur un compte
  # recent. Ces valeurs laissent le temps necessaire au lieu d'abandonner.
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }


  tags = {
    Name    = "rp-db"
    Project = "ResumePortal"
  }
}
