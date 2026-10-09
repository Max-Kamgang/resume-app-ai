# ─────────────────────────────────────────────
# SG 1: ALB Security Group
# ─────────────────────────────────────────────
resource "aws_security_group" "rp_alb_sg" {
  name        = "rp-alb-sg"
  description = "Allow HTTP and HTTPS from internet"
  vpc_id      = aws_vpc.rp_vpc.id


  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name    = "rp-alb-sg"
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# SG 2: EC2 Security Group
# ─────────────────────────────────────────────
resource "aws_security_group" "rp_ec2_sg" {
  name        = "rp-ec2-sg"
  description = "Allow HTTP from ALB only"
  vpc_id      = aws_vpc.rp_vpc.id


  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.rp_alb_sg.id]
  }


  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name    = "rp-ec2-sg"
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# SG 3: RDS Security Group
# ─────────────────────────────────────────────
resource "aws_security_group" "rp_rds_sg" {
  name        = "rp-rds-sg"
  description = "Allow PostgreSQL from EC2 only"
  vpc_id      = aws_vpc.rp_vpc.id


  ingress {
    description     = "PostgreSQL from EC2 only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rp_ec2_sg.id]
  }


  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name    = "rp-rds-sg"
    Project = "ResumePortal"
  }
}
