locals {
  # Public portal hostname, e.g. resume.example.com
  app_fqdn = "${var.app_subdomain}.${var.root_domain}"

  # Return path for bounces and complaints.
  mail_from_domain = "mail.${var.root_domain}"

  # Sender: no-reply@<domain>, DKIM-signed.
  sender_email = "${var.sender_local_part}@${var.root_domain}"

  # Derived from the company name to avoid asking for one more value:
  # "Utrains" -> "Utrains HR". Override with var.sender_display_name.
  sender_display_name = var.sender_display_name != "" ? var.sender_display_name : "${var.company_name} HR"

  # Globally unique bucket names (see var.bucket_suffix).
  bucket_suffix   = var.bucket_suffix != "" ? var.bucket_suffix : data.aws_caller_identity.current.account_id
  frontend_bucket = "rp-frontend-${local.bucket_suffix}"
  resumes_bucket  = "rp-resumes-${local.bucket_suffix}"
}


# Groups the portal mail so reputation is tracked separately.
resource "aws_sesv2_configuration_set" "rp_ses_config_set" {
  configuration_set_name = "rp-portal"

  delivery_options {
    tls_policy = "REQUIRE"
  }

  reputation_options {
    reputation_metrics_enabled = true
  }

  sending_options {
    sending_enabled = true
  }

  tags = {
    Project = "ResumePortal"
  }
}


# Recruiter inbox: reply-to for candidates, and where screening alerts land.
# Verified as an SES identity so it can receive mail while the account is still
# in the SES sandbox. AWS mails a verification link here — it must be clicked.
resource "aws_sesv2_email_identity" "rp_ses_identity" {
  email_identity = var.hr_email

  tags = {
    Project = "ResumePortal"
  }
}


# Lets us send from no-reply@<domain> rather than a personal mailbox.
resource "aws_sesv2_email_identity" "rp_domain_identity" {

  email_identity         = var.root_domain
  configuration_set_name = aws_sesv2_configuration_set.rp_ses_config_set.configuration_set_name

  dkim_signing_attributes {
    next_signing_key_length = "RSA_2048_BIT"
  }

  tags = {
    Project = "ResumePortal"
  }
}


# Three CNAMEs proving domain ownership. Without them SES never verifies the
# domain and every send fails.
resource "aws_route53_record" "rp_ses_dkim" {
  count = 3

  zone_id         = data.aws_route53_zone.rp_zone.zone_id
  name            = "${element(aws_sesv2_email_identity.rp_domain_identity.dkim_signing_attributes[0].tokens, count.index)}._domainkey.${var.root_domain}"
  type            = "CNAME"
  ttl             = 600
  records         = ["${element(aws_sesv2_email_identity.rp_domain_identity.dkim_signing_attributes[0].tokens, count.index)}.dkim.amazonses.com"]
  allow_overwrite = true
}


# Bounces and complaints return to our own domain, which aligns SPF/DMARC and
# improves deliverability.
resource "aws_sesv2_email_identity_mail_from_attributes" "rp_mail_from" {

  email_identity         = aws_sesv2_email_identity.rp_domain_identity.email_identity
  mail_from_domain       = local.mail_from_domain
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}


resource "aws_route53_record" "rp_ses_mail_from_mx" {

  zone_id         = data.aws_route53_zone.rp_zone.zone_id
  name            = local.mail_from_domain
  type            = "MX"
  ttl             = 600
  records         = ["10 feedback-smtp.${data.aws_region.current.region}.amazonses.com"]
  allow_overwrite = true
}


resource "aws_route53_record" "rp_ses_mail_from_spf" {

  zone_id         = data.aws_route53_zone.rp_zone.zone_id
  name            = local.mail_from_domain
  type            = "TXT"
  ttl             = 600
  records         = ["v=spf1 include:amazonses.com ~all"]
  allow_overwrite = true
}
