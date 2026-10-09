# ─────────────────────────────────────────────
# Domaine, certificat TLS et DNS
#
# PRÉREQUIS avant le premier apply : une zone hébergée Route 53 doit déjà
# exister dans CE compte pour var.root_domain, et les serveurs de noms du
# domaine doivent pointer vers elle chez votre registrar. Sans cela la
# validation ACM ne peut pas aboutir.
#
#   Vérifiez :
#     aws route53 list-hosted-zones-by-name --dns-name mondomaine.com
# ─────────────────────────────────────────────

# ─── ZONE HÉBERGÉE ───────────────────────────────────────────────────────────
# Doit déjà exister dans ce compte. Vérifiez avec :
#   aws route53 list-hosted-zones-by-name --dns-name mondomaine.com
data "aws_route53_zone" "rp_zone" {

  name         = var.root_domain
  private_zone = false
}


# ─── CERTIFICAT TLS ──────────────────────────────────────────────────────────
resource "aws_acm_certificate" "rp_cert" {

  domain_name               = var.root_domain
  subject_alternative_names = ["*.${var.root_domain}"]
  validation_method         = "DNS"

  tags = { Project = "ResumePortal" }

  lifecycle {
    create_before_destroy = true
  }
}


# ─── VALIDATION DNS DU CERTIFICAT ────────────────────────────────────────────
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.rp_cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.rp_zone.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}


resource "aws_acm_certificate_validation" "rp_cert_validation" {

  certificate_arn         = aws_acm_certificate.rp_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "30m"
  }
}


# ─── ENREGISTREMENT DNS DU PORTAIL ───────────────────────────────────────────
# resume.<domaine> pointe vers l'ALB. Le site et l'API partagent la même
# origine, ce qui évite toute configuration CORS.
resource "aws_route53_record" "rp_portal_record" {

  zone_id = data.aws_route53_zone.rp_zone.zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.rp_alb.dns_name
    zone_id                = aws_lb.rp_alb.zone_id
    evaluate_target_health = true
  }

  allow_overwrite = true
}
