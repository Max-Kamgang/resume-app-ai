# ─────────────────────────────────────────────
# Données découvertes à l'exécution
#
# Rien n'est codé en dur ici : c'est ce qui permet au stack de se déployer
# sur N'IMPORTE QUEL compte AWS et dans n'importe quelle région, sans qu'un
# débutant ait à modifier quoi que ce soit.
# ─────────────────────────────────────────────

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


# ─── AMI Amazon Linux 2023 ───────────────────────────────────────────────────
# Un identifiant d'AMI n'est valable que dans UNE région. Le coder en dur
# faisait échouer tout déploiement hors us-east-1 avec « InvalidAMIID.NotFound ».
# On interroge le SSM Parameter Store public d'AWS, qui pointe toujours vers la
# dernière AMI AL2023 de la région courante.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


# ─── Zones de disponibilité ──────────────────────────────────────────────────
# "us-east-1a" n'existe pas à Paris ni à Francfort. On prend les deux premières
# zones réellement disponibles dans la région choisie.
#
# Le filtre exclut les zones "opt-in" (Local Zones, Wavelength) qui ne
# supportent ni RDS ni ALB : sans lui, un compte peut tomber sur une zone
# inutilisable et échouer à la création du sous-réseau.
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}


locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]

}
