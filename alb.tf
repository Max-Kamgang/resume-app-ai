# ─────────────────────────────────────────────
# Target Group
# ─────────────────────────────────────────────
resource "aws_lb_target_group" "rp_targets" {
  name             = "rp-targets"
  port             = 80
  protocol         = "HTTP"
  vpc_id           = aws_vpc.rp_vpc.id
  target_type      = "instance"
  ip_address_type  = "ipv4"
  protocol_version = "HTTP1"


  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }


  tags = {
    Name    = "rp-targets"
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# Target Group Attachments — register EC2s
# ─────────────────────────────────────────────
resource "aws_lb_target_group_attachment" "rp_server_1" {
  target_group_arn = aws_lb_target_group.rp_targets.arn
  target_id        = aws_instance.rp_server_1.id
  port             = 80
}


resource "aws_lb_target_group_attachment" "rp_server_2" {
  target_group_arn = aws_lb_target_group.rp_targets.arn
  target_id        = aws_instance.rp_server_2.id
  port             = 80
}


# ─────────────────────────────────────────────
# Application Load Balancer
# ─────────────────────────────────────────────
resource "aws_lb" "rp_alb" {
  name               = "rp-alb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.rp_alb_sg.id]


  subnets = [
    aws_subnet.rp_public_1a.id,
    aws_subnet.rp_public_1b.id
  ]


  # Un ALB devient actif en 2 a 5 min; on laisse large pour absorber une
  # coupure reseau passagere pendant l'attente.
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }


  tags = {
    Name    = "rp-alb"
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# Listener 1 — HTTP port 80 → redirect to HTTPS
# ---------------------------------------------
# Listener HTTP (port 80)
#
# Avec un domaine  : redirige vers HTTPS.
# Sans domaine     : sert directement le site, car il n'existe aucun
#                    certificat et rediriger vers 443 donnerait une page
#                    inaccessible. C'est ce qui rend le stack utilisable
#                    du premier coup sans nom de domaine.
# ---------------------------------------------
resource "aws_lb_listener" "rp_http" {
  load_balancer_arn = aws_lb.rp_alb.arn
  port              = 80
  protocol          = "HTTP"

  # Tout le trafic en clair est redirige vers HTTPS : un candidat televerse
  # un CV, cela ne doit jamais transiter sans chiffrement.
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name    = "rp-http-listener"
    Project = "ResumePortal"
  }
}


resource "aws_lb_listener" "rp_https" {

  load_balancer_arn = aws_lb.rp_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.rp_cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rp_targets.arn
  }

  tags = {
    Name    = "rp-https-listener"
    Project = "ResumePortal"
  }
}


# ---------------------------------------------
# api.<domaine> - second nom pour le meme ALB
# ---------------------------------------------
resource "aws_route53_record" "rp_api_record" {

  zone_id = data.aws_route53_zone.rp_zone.zone_id
  name    = "api.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.rp_alb.dns_name
    zone_id                = aws_lb.rp_alb.zone_id
    evaluate_target_health = true
  }

  allow_overwrite = true
}
