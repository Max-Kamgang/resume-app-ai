# ─────────────────────────────────────────────
# Sorties — ce dont vous avez besoin après `terraform apply`
# ─────────────────────────────────────────────

output "portal_url" {
  description = "Adresse publique du site."
  value       = "https://${local.app_fqdn}"
}

output "sender_email" {
  description = "Adresse d'expédition des emails. À vérifier dans SES si ce n'est pas un domaine."
  value       = local.sender_email
}

output "gemini_model" {
  description = "Modele Gemini utilise pour noter les CV."
  value       = var.gemini_model
}

output "match_threshold" {
  description = "Score à partir duquel une candidature est retenue."
  value       = var.match_threshold
}

output "open_positions" {
  description = "Identifiants des postes proposés sur le site."
  value       = keys(var.job_openings)
}



output "assets_bucket" {
  description = "Bucket contenant index.html, app/app.py et app/jobs.json."
  value       = aws_s3_bucket.rp_frontend.id
}


# ─────────────────────────────────────────────
# Ce qu'il reste à faire à la main — affiché à la fin de l'apply
# ─────────────────────────────────────────────
output "etapes_suivantes" {
  description = "Les deux actions manuelles qu'aucun code Terraform ne peut réaliser."
  value       = <<-EOT

    ┌───────────────────────────────────────────────────────────────────────┐
    │  DÉPLOIEMENT TERMINÉ                                                  │
    └───────────────────────────────────────────────────────────────────────┘

    Votre site : https://${local.app_fqdn}

    Comptez 3 à 5 minutes : les serveurs démarrent et doivent passer deux
    contrôles de santé avant que le site réponde.

    ─── ÉTAPE 1 : vérifier votre adresse email ────────────────────────────

    AWS vient d'envoyer un lien de vérification à ${var.hr_email}.
    CLIQUEZ-LE, sinon aucun email ne pourra partir ni arriver.

      aws sesv2 list-email-identities --region ${data.aws_region.current.region} --output table

    Tant que le compte est en bac à sable SES, vous ne pouvez écrire qu'aux
    adresses vérifiées. Pour tester, saisissez ${var.hr_email} comme adresse
    du candidat. Pour accepter de vrais candidats, demandez l'accès production
    dans la console SES.

    ─── ÉTAPE 2 : rien à faire, l'IA est déjà active ──────────────────────

    L'analyse des CV tourne sur ${var.gemini_model} avec la clé que vous avez
    fournie. Aucune autorisation AWS à demander, aucun formulaire à remplir.

    Si une analyse échoue, le candidat reçoit quand même un message
    « dossier en cours d'examen » et une alerte part vers ${var.hr_email}.

    ─── TESTER ────────────────────────────────────────────────────────────

    Ouvrez le site, choisissez un poste, remplissez le formulaire avec
    ${var.hr_email} comme email, et envoyez un CV en PDF.

  EOT
}
