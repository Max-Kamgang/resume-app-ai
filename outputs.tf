# What you need after `terraform apply`.

output "portal_url" {
  description = "Public address of the site."
  value       = "https://${local.app_fqdn}"
}

output "sender_email" {
  description = "Address the emails are sent from."
  value       = local.sender_email
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

    ─── TEST IT ───────────────────────────────────────────────────────────

    Open the site, pick a role, fill the form using ${var.hr_email} as the
    candidate email, and upload a PDF CV. The match score appears on the page
    and in the decision email.

    ─── WHEN YOU ARE DONE ─────────────────────────────────────────────────

    terraform destroy

    This stack costs roughly 55 USD per month if left running.

  EOT
}
