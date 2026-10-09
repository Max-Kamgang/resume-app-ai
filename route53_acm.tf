# Domain, TLS certificate and DNS.
#
# Prerequisite before the first apply: a Route 53 hosted zone must already exist
# in THIS account for var.root_domain, and the registrar must point at it.
# ACM validates over public DNS, so there is no way around this.
#
#   aws route53 list-hosted-zones-by-name --dns-name example.com

data "aws_route53_zone" "rp_zone" {

  name         = var.root_domain
  private_zone = false
}


resource "aws_acm_certificate" "rp_cert" {

  domain_name               = var.root_domain
  subject_alternative_names = ["*.${var.root_domain}"]
  validation_method         = "DNS"

  tags = { Project = "ResumePortal" }

  lifecycle {
    create_before_destroy = true
  }
}


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


# The site and the API share one origin, which removes any need for CORS.
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
