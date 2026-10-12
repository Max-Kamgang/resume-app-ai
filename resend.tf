# ─────────────────────────────────────────────
# Resend — transactional email
#
# Why this exists alongside ses.tf rather than replacing it:
#
# SES starts every new account in a SANDBOX. Until AWS grants production
# access, you may only write to addresses you have verified one at a time,
# which makes a demo with real candidates impossible. Resend sends to anyone
# as soon as the domain is verified, with no approval ticket.
#
# ses.tf is deliberately kept: the application uses Resend when a key is
# present and falls back to SES when Resend refuses, so a misconfiguration
# degrades instead of losing a candidate's email. Blank resend_api_key to go
# back to SES alone — nothing else needs changing.
#
# The key travels through user-data into /opt/rp-app/.env (umask 077,
# chmod 600), exactly like the Gemini key, and never ships to S3 with the
# application code.
# ─────────────────────────────────────────────

# ---------------------------------------------
# Domain verification records
#
# Resend prints these when you add the domain in its dashboard. Paste them
# into terraform.tfvars and apply: the Route 53 zone is already managed here,
# so there is nothing to click at a registrar.
#
# They do not collide with ses.tf. SES signs from "mail.<domain>" (see
# var.root_domain usage there) while Resend uses its own subdomain, so both
# sets of records coexist and either provider can send.
# ---------------------------------------------
resource "aws_route53_record" "rp_resend_verification" {
  for_each = var.resend_dns_records

  # You very likely pasted these into the Route 53 console by hand to get the
  # domain verified before wiring them here. Without this, Terraform would
  # refuse the apply with "RRSet already exists"; with it, it adopts the
  # record you already created instead of failing.
  allow_overwrite = true

  zone_id = data.aws_route53_zone.rp_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}
