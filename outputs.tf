# What you need after `terraform apply`.

# us-east-1 on-demand, per day. "free_tier" assumes the classic 12-month
# allowance: 750 h of db.t3.micro, 750 h of t3.micro, 20 GB of RDS storage and
# 30 GB of EBS - one instance's worth, not two.
locals {
  _cost_nat   = var.enable_nat_gateway ? 1.080 : 0
  _cost_alb   = 0.540
  _cost_fixed = 0.096 # 2 KMS keys, Secrets Manager, zone
  _cost_rds   = 0.432 + 0.077
  _cost_web   = (0.250 + 0.079) * var.instance_count

  cost_per_day = (
    local._cost_nat + local._cost_alb + local._cost_fixed +
    local._cost_rds + local._cost_web
  )

  # The Free Tier covers the database and exactly one web server.
  cost_per_day_free_tier = (
    local._cost_nat + local._cost_alb + local._cost_fixed +
    (0.250 + 0.079) * max(var.instance_count - 1, 0)
  )
}


output "portal_url" {
  description = "Public address of the site."
  value       = "https://${local.app_fqdn}"
}

output "sender_email" {
  description = "Address the emails are sent from."
  value       = local.sender_email
}

output "email_provider" {
  description = "Which provider actually sends. SES stays wired as the fallback."
  # Whether a key is set is not itself a secret; the key is. Terraform marks
  # anything derived from a sensitive variable, so the mark is lifted here.
  value = nonsensitive(var.resend_api_key) != "" ? "Resend (SES kept as fallback)" : "Amazon SES"
}

output "gemini_model" {
  description = "Gemini model used to score CVs."
  value       = var.gemini_model
}

output "match_threshold" {
  description = "Score at or above which an application is successful."
  value       = var.match_threshold
}

output "open_positions" {
  description = "Role ids offered on the site."
  value       = keys(var.job_openings)
}

output "hr_portal_url" {
  description = "Internal HR portal: where the match score and the AI review live."
  value       = "https://${local.app_fqdn}/admin"
}

output "hr_portal_users" {
  description = "HR portal usernames (passwords are not printed here)."
  value       = local.hr_portal_usernames
}

# Only meaningful when var.hr_portal_users is left empty: Terraform then
# generates a single "hr" account. Read it with:
#   terraform output -raw hr_portal_password
output "hr_portal_password" {
  description = "Generated password for the \"hr\" account."
  value       = length(var.hr_portal_users) > 0 ? "set in var.hr_portal_users" : random_password.hr_portal.result
  sensitive   = true
}

output "assets_bucket" {
  description = "Bucket holding index.html, app/app.py and app/jobs.json."
  value       = aws_s3_bucket.rp_frontend.id
}


# Printed at the end of the apply.
output "next_steps" {
  description = "The one manual action Terraform cannot perform for you."
  value       = <<-EOT

    ┌───────────────────────────────────────────────────────────────────────┐
    │  DEPLOYMENT COMPLETE                                                  │
    └───────────────────────────────────────────────────────────────────────┘

    Your site: https://${local.app_fqdn}

    Give it 3 to 5 minutes: the servers boot and must pass two health checks
    before the site answers.

    ─── STEP 1: verify your email address ─────────────────────────────────

    AWS has just emailed a verification link to ${var.hr_email}.
    CLICK IT, or no email can be sent or received.

      aws sesv2 list-email-identities --region ${data.aws_region.current.region} --output table

    While the account is in the SES sandbox you can only write to verified
    addresses. For testing, enter ${var.hr_email} as the candidate address.
    To accept real candidates, request production access in the SES console.

    ─── STEP 2: nothing to do, the AI is already live ─────────────────────

    CV screening runs on ${var.gemini_model} with the key you supplied.
    No AWS permission to request, no form to fill in.

    If a screening fails, the candidate still gets an "under review" message
    and an alert goes to ${var.hr_email}.

    ─── STEP 3: sign in to the HR portal ──────────────────────────────────

    https://${local.app_fqdn}/admin

    The match score, the AI reasoning and the override controls live there and
    nowhere else. The candidate never sees a score: they receive either a
    rejection, or an invitation carrying a private link on which they enter
    their availability for the screening call.

    Username: ${join(", ", local.hr_portal_usernames)}
    Password: terraform output -raw hr_portal_password

    ─── TEST IT ───────────────────────────────────────────────────────────

    Open the site, pick a role, fill the form using ${var.hr_email} as the
    candidate email, and upload a PDF CV. You receive the candidate email;
    the score behind it is in the HR portal, where you can also overturn the
    bot and email the other outcome.

    ─── WHAT THIS IS COSTING YOU ──────────────────────────────────────────

    Mode: ${var.enable_nat_gateway ? "private subnets + NAT Gateway" : "public subnets, no NAT"} · ${var.instance_count} web server${var.instance_count > 1 ? "s" : ""}

    List price      ~${format("%.2f", local.cost_per_day)} $/day   (~${format("%.0f", local.cost_per_day * 30)} $/month)
    With Free Tier  ~${format("%.2f", local.cost_per_day_free_tier)} $/day   (~${format("%.0f", local.cost_per_day_free_tier * 30)} $/month)

    Charged by the hour with zero traffic.${var.enable_nat_gateway ? "\n    The NAT Gateway alone is 1.08 $/day: see \"Running this on a student\n    account\" in the README to turn it off." : ""}

    ─── WHEN YOU ARE DONE ─────────────────────────────────────────────────

    terraform destroy

    Always destroy the stack when you are finished testing. The two KMS keys
    linger for 7 days afterwards at ~1 $/month each: that is the AWS minimum
    deletion window, not something left behind.

  EOT
}
