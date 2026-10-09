# ─────────────────────────────────────────────
# Secrets Manager Secret — RDS Credentials
# ─────────────────────────────────────────────
resource "aws_secretsmanager_secret" "rp_db_credentials" {
  # IMPORTANT pour un projet pedagogique.
  # Par defaut AWS ne supprime PAS un secret tout de suite : il le place en
  # fenetre de recuperation de 30 jours, pendant laquelle le NOM reste
  # reserve. Un cycle "terraform destroy" puis "terraform apply" echoue alors
  # sur : "a secret with this name is already scheduled for deletion".
  # 0 = suppression immediate, nom reutilisable aussitot. C'est ce qu'il faut
  # pour un stack qu'on detruit et recree souvent.
  recovery_window_in_days = 0

  # name_prefix, et non name.
  #
  # Supprimer un secret le place en fenetre de recuperation : son NOM reste
  # reserve et un nouvel apply echoue sur "already scheduled for deletion".
  # Avec un prefixe, Terraform genere un nom unique a chaque deploiement, donc
  # la collision est structurellement impossible. Le nom reel est transmis a
  # l'application par variable d'environnement : il n'a pas besoin d'etre fixe.
  name_prefix = "rp-db-credentials-"
  description = "PostgreSQL credentials for resume portal"


  # Using default aws/secretsmanager key (free)
  # kms_key_id is omitted to use the default AWS managed key
  tags = {
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# Secret Value — RDS credentials as JSON
# ─────────────────────────────────────────────
resource "aws_secretsmanager_secret_version" "rp_db_credentials_value" {
  secret_id = aws_secretsmanager_secret.rp_db_credentials.id


  # Must match the credentials RDS was actually created with, otherwise the
  # app reads a password the database will reject.
  secret_string = jsonencode({
    username             = var.db_username
    password             = var.db_password
    engine               = "postgres"
    host                 = aws_db_instance.rp_db.address
    port                 = 5432
    dbname               = "postgres"
    dbInstanceIdentifier = aws_db_instance.rp_db.identifier
  })
}
