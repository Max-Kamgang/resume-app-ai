###############################################################################
#                                                                             #
#   S E C T I O N   1   —   C E   Q U E   V O U S   D E V E Z   F O U R N I R #
#                                                                             #
#   Quatre informations, et c'est tout. Les variables ci-dessous n'ont PAS   #
#   de valeur par défaut : Terraform vous les demande au lancement.          #
#                                                                             #
#       $ terraform apply                                                     #
#       var.company_name                                                      #
#         Nom de votre société...                                             #
#         Enter a value: _                                                    #
#                                                                             #
#   C'est une INVITE, pas une erreur. Vous tapez, ça continue.                #
#                                                                             #
#   Pour ne plus être invité, créez terraform.tfvars :                        #
#       cp terraform.tfvars.example terraform.tfvars                          #
#                                                                             #
#   Tout le reste (Section 2) a des valeurs qui fonctionnent telles quelles.  #
#                                                                             #
###############################################################################

# ─── 1.1 Votre nom de domaine ────────────────────────────────────────────────
#
# PRÉREQUIS, à faire AVANT le premier `terraform apply` :
#   1. posséder ce domaine chez un registrar ;
#   2. avoir créé une zone hébergée Route 53 pour lui dans CE compte AWS ;
#   3. avoir pointé les serveurs de noms du domaine vers cette zone.
#
# Vérifiez que la zone existe — si cette commande ne renvoie rien, l'apply
# échouera sur « no matching Route53Zone found » :
#
#     aws route53 list-hosted-zones-by-name --dns-name mondomaine.com
#
# Le stack y créera le certificat TLS, les enregistrements DKIM et le
# sous-domaine du portail.
variable "root_domain" {
  description = "Votre domaine, ex. mondomaine.com. Une zone Route 53 doit deja exister pour lui dans ce compte."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+[.][a-z0-9.-]*[a-z]{2,}$", var.root_domain))
    error_message = "root_domain doit etre un nom de domaine, par exemple mondomaine.com (sans https:// ni www)."
  }
}


# ─── 1.2 Votre adresse email ─────────────────────────────────────────────────
#
# Trois rôles : destinataire des réponses des candidats, adresse affichée en
# pied des emails, et boîte qui reçoit les alertes si l'analyse IA échoue.
#
# ATTENTION : une vraie boîte que vous pouvez OUVRIR (Gmail par exemple).
# Pas une adresse de votre domaine : vérifier un domaine dans SES donne le
# droit d'ENVOYER, pas de recevoir.
#
# AWS enverra un lien de vérification à cette adresse après l'apply :
# il faut le cliquer.
variable "hr_email" {
  description = "Votre vraie adresse email, ex. moi@gmail.com. Recoit les reponses et les alertes."
  type        = string

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+[.][a-z]{2,}$", var.hr_email))
    error_message = "hr_email doit etre une adresse email valide, par exemple moi@gmail.com."
  }
}


# ─── 1.3 Le nom de votre société ─────────────────────────────────────────────
#
# Affiché sur le site carrières et dans les emails. Sert aussi à composer le
# nom d'expéditeur vu par le candidat : « Utrains » donne « Utrains HR ».
#
# L'adresse d'expédition, elle, est composée automatiquement :
#   no-reply@<votre domaine>
variable "company_name" {
  description = "Nom de votre societe, ex. Utrains. Apparait sur le site et dans les emails."
  type        = string

  validation {
    condition     = length(trimspace(var.company_name)) >= 2
    error_message = "company_name doit contenir au moins 2 caracteres."
  }
}


# ─── 1.4 Votre clé API Gemini ────────────────────────────────────────────────
#
# Obtenez-la gratuitement sur https://aistudio.google.com/apikey
#
# La clé est écrite par Terraform dans /opt/rp-app/.env sur les serveurs, et
# lue par l'application au démarrage. Elle n'apparaît ni dans le code, ni dans
# l'objet S3 de déploiement.
#
# ATTENTION : la clé transite par terraform.tfstate EN CLAIR. Le .gitignore du
# projet exclut déjà ce fichier — ne le forcez jamais dans un dépôt Git.
#
# Trois façons de la fournir, au choix :
#   1. terraform.tfvars  →  gemini_api_key = "votre-cle"
#   2. variable d'env    →  export TF_VAR_gemini_api_key="votre-cle"
#   3. ne rien faire     →  Terraform vous la demande au lancement
variable "gemini_api_key" {
  description = "Cle API Gemini (https://aistudio.google.com/apikey)."
  type        = string
  sensitive   = true

  # Deux garde-fous : on refuse le texte d'exemple laisse tel quel, et une
  # valeur manifestement trop courte. Sans cela, un oubli deploierait une
  # infrastructure complete dont l'analyse IA echoue silencieusement.
  validation {
    condition     = !can(regex("(?i)collez|votre-cle|your-key|[.][.][.]", var.gemini_api_key))
    error_message = "Vous n'avez pas encore colle votre cle. Ouvrez terraform.tfvars et remplacez le texte d'exemple par la cle obtenue sur https://aistudio.google.com/apikey"
  }

  validation {
    condition     = length(trimspace(var.gemini_api_key)) >= 30
    error_message = "gemini_api_key semble trop courte. Recuperez votre cle sur https://aistudio.google.com/apikey"
  }
}


# ─── 1.5 Région AWS ──────────────────────────────────────────────────────────
# Gardez us-east-1 si vous débutez : c'est la région au niveau gratuit le plus
# large. L'analyse IA passe par Gemini, donc la région n'a aucun effet dessus.
variable "aws_region" {
  description = "Région AWS de déploiement."
  type        = string
  default     = "us-east-1"
}


# ─── 1.6 Seuil d'acceptation ─────────────────────────────────────────────────
# Score (0-100) à partir duquel le candidat est invité en entretien.
# Le seuil est INCLUSIF : avec 80, un score de 80 est accepté, 79 est refusé.
variable "match_threshold" {
  description = "Score de correspondance à partir duquel la candidature est retenue."
  type        = number
  default     = 80

  validation {
    condition     = var.match_threshold >= 0 && var.match_threshold <= 100
    error_message = "match_threshold doit être compris entre 0 et 100."
  }
}


# ─── 1.7 Lien de réunion (facultatif) ────────────────────────────────────────
# Renseigné  → l'email d'acceptation contient un bouton « Réserver mon entretien ».
# Vide       → l'email demande au candidat ses créneaux de disponibilité.
# Collez ici un lien Calendly, Google Meet, Teams, etc.
variable "interview_booking_url" {
  description = "Lien de prise de rendez-vous. Vide = on demande ses disponibilités au candidat."
  type        = string
  default     = ""
}


# ─── 1.8 Suffixe des buckets S3 ──────────────────────────────────────────────
# Les noms de buckets S3 sont uniques dans le MONDE ENTIER : si quelqu'un a
# déjà pris le nom, votre apply échoue. Laissé vide, l'identifiant de votre
# compte AWS est utilisé — unique par construction, donc rien à faire.
variable "bucket_suffix" {
  description = "Suffixe des buckets S3. Vide = identifiant du compte AWS (recommandé)."
  type        = string
  default     = ""
}


# ─── 1.9 Les offres d'emploi ─────────────────────────────────────────────────
# C'est ici que vous décrivez vos postes. Chaque entrée comporte :
#
#   title         intitulé affiché dans le menu déroulant du site
#   contract      CDI, CDD, stage, alternance…
#   location      lieu ou modalité de travail
#   experience    expérience attendue
#   description   l'offre PUBLIQUE, lue par le candidat ET par l'IA
#   scoring_notes grille INTERNE, lue par l'IA uniquement — jamais exposée
#
# Format de `description` reconnu par le site :
#   - une ligne courte finissant par « : »  → devient un intertitre
#   - une ligne commençant par « - »        → devient une puce
#   - le reste                              → paragraphe
#
# Ajouter un poste = ajouter une entrée ici, puis terraform apply.
# Aucun remplacement de serveur : le changement est en ligne en 2 minutes.
###############################################################################

variable "job_openings" {
  description = "Postes ouverts, indexés par un identifiant stable."

  type = map(object({
    title         = string
    contract      = string
    location      = string
    experience    = string
    description   = string
    scoring_notes = string
  }))

  default = {
    llmops-engineer = {
      title      = "Ingénieur LLMOps"
      contract   = "CDI"
      location   = "Hybride — télétravail partiel"
      experience = "5 ans d'expérience minimum"

      description = <<-EOT
        Nous industrialisons des applications bâties sur des grands modèles de langage :
        assistants internes, extraction documentaire, agents outillés. Vous porterez la
        chaîne complète qui mène du prototype au service en production — fiable, mesuré
        et maîtrisé en coût.

        Vos missions :
        - Concevoir, déployer et exploiter nos services d'inférence en production, sur API managées (Amazon Bedrock, Claude) comme sur modèles auto-hébergés.
        - Construire la couche d'orchestration : chaînage d'appels, appel d'outils, sorties structurées, garde-fous et reprises sur erreur.
        - Mettre en place et faire vivre nos jeux d'évaluation : cas de test, métriques de qualité, juges automatiques, détection de régression à chaque changement de prompt ou de modèle.
        - Industrialiser le versionnage des prompts et le déploiement progressif, avec traçabilité complète de ce qui tourne en production.
        - Instrumenter l'observabilité propre aux LLM : latence, consommation de tokens, coût par requête, taux d'erreur, dérive de qualité.
        - Optimiser coût et latence : mise en cache, dimensionnement du contexte, choix du modèle selon la criticité de la tâche.
        - Construire nos pipelines RAG : ingestion, découpage, embeddings, base vectorielle, stratégies de récupération et de reclassement.
        - Sécuriser la chaîne de bout en bout : défense contre l'injection de prompt, cloisonnement des données sensibles, gestion des secrets.

        Ce que nous attendons :
        - Cinq ans d'expérience en ingénierie logicielle, plateforme ou MLOps, dont au moins deux sur des systèmes à base de LLM réellement en production.
        - Python de niveau production : code testé, typé, packagé, relu par les pairs.
        - Au moins une application LLM que vous avez mise en production, intégrée à une API de modèle.
        - Ingénierie de prompt appliquée : sorties structurées, appel d'outils, gestion du contexte.
        - Une pratique réelle de l'évaluation : vous savez démontrer une amélioration par la mesure, pas par l'impression.
        - Docker, déploiement sur cloud public (AWS de préférence), infrastructure as code et CI/CD.

        Ce qui fera la différence :
        - RAG avancé : bases vectorielles, reclassement, recherche hybride.
        - Agents outillés et protocoles d'intégration type MCP.
        - Fine-tuning, distillation, quantification, service de modèles ouverts.
        - Kubernetes, Kafka ou files d'attente pour le traitement asynchrone.
        - Une sensibilité aux enjeux de sécurité et de conformité des systèmes d'IA.
      EOT

      scoring_notes = <<-EOT
        Signaux de disqualification (ne jamais citer textuellement au candidat) :
        - Expérience limitée à l'usage d'un assistant de chat, sans mise en production.
        - Aucune pratique d'évaluation objective de la qualité des sorties.
        - Projets uniquement personnels ou tutoriels, sans contexte professionnel.
        Pondération : les six exigences de « Ce que nous attendons » sont obligatoires et
        portent l'essentiel du score. « Ce qui fera la différence » n'ajoute que quelques points.
      EOT
    }

    devops-engineer = {
      title      = "Ingénieur DevOps"
      contract   = "CDI"
      location   = "Hybride — télétravail partiel"
      experience = "5 ans d'expérience minimum"

      description = <<-EOT
        L'équipe plateforme opère l'infrastructure qui porte nos applications internes et
        clientes. Vous couvrirez l'automatisation de bout en bout : provisionnement,
        livraison continue, supervision, sécurité et maîtrise des coûts.

        Vos missions :
        - Concevoir et exploiter notre infrastructure AWS de production : VPC, sous-réseaux publics et privés, ALB, EC2, RDS, S3, IAM, KMS, Route 53, ACM.
        - Écrire et maintenir l'intégralité de l'infrastructure en Terraform : modules réutilisables, state distant, revue des plans avant application.
        - Construire et maintenir nos pipelines CI/CD complets — build, tests, analyse de sécurité, déploiement automatisé, rollback.
        - Conteneuriser les applications avec Docker et les opérer sur Kubernetes ou ECS : gestion des ressources, autoscaling, mises à jour progressives.
        - Mettre en place l'observabilité : métriques, logs centralisés, traces, tableaux de bord et alerting réellement actionnable.
        - Appliquer la sécurité par défaut : moindre privilège sur IAM, chiffrement au repos et en transit, rotation des secrets, durcissement réseau.
        - Garantir la résilience : sauvegardes testées, plan de reprise, objectifs de disponibilité, gestion des incidents et post-mortems.
        - Optimiser les coûts cloud : dimensionnement, instances réservées ou spot, suivi et réduction de la facture.

        Ce que nous attendons :
        - Cinq ans d'expérience en DevOps, SRE ou ingénierie cloud.
        - Une maîtrise approfondie d'AWS en production, au-delà d'un usage ponctuel ou de laboratoires de formation.
        - Terraform en production : modules, state distant, workflow de revue.
        - Docker et orchestration de conteneurs, Kubernetes ou ECS.
        - Des pipelines CI/CD que vous avez vous-même construits et maintenus.
        - Administration Linux et solides bases réseau : TCP/IP, DNS, TLS.
        - Scripting Python ou Bash, Git et pratique de la revue de code.
        - Supervision, alerting et gestion d'incidents en production.

        Ce qui fera la différence :
        - Une certification AWS (Solutions Architect, DevOps Engineer Professional).
        - Ansible ou un outil de gestion de configuration équivalent.
        - GitOps (ArgoCD, Flux), service mesh, politiques as code.
        - Administration PostgreSQL et réglage de performance.
        - Expérience multi-comptes AWS, Landing Zone, FinOps.
      EOT

      scoring_notes = <<-EOT
        Signaux de disqualification (ne jamais citer textuellement au candidat) :
        - Expérience cloud uniquement théorique ou limitée à des projets personnels.
        - Aucune pratique de l'infrastructure as code.
        - Certification AWS sans expérience d'exploitation correspondante.
        Pondération : les huit exigences de « Ce que nous attendons » sont obligatoires et
        portent l'essentiel du score. « Ce qui fera la différence » n'ajoute que quelques points.
      EOT
    }
  }
}

###############################################################################
#                                                                             #
#   S E C T I O N   2   —   A V A N C É                                       #
#                                                                             #
#   Ces variables ont des valeurs qui fonctionnent telles quelles.            #
#   Vous n'avez normalement PAS besoin d'y toucher pour déployer.             #
#                                                                             #
###############################################################################

# ─── 2.1 Modèle Gemini ───────────────────────────────────────────────────────
# Modèle utilisé pour noter les CV. Flash est rapide et peu coûteux, largement
# suffisant pour comparer un CV à une fiche de poste.
variable "gemini_model" {
  description = "Modele Gemini utilise pour l'analyse des CV."
  type        = string
  default     = "gemini-3.8-flash"
}


variable "gemini_fallback_model" {
  description = "Modele de repli si le principal renvoie 503 (sature). Vide = pas de repli."
  type        = string
  default     = "gemini-flash-latest"
}


# ─── 2.2 Identité du site et des emails ──────────────────────────────────────
variable "sender_display_name" {
  description = "Nom d'expediteur. Vide = \"<company_name> HR\", ex. Utrains HR."
  type        = string
  default     = ""
}

variable "sender_local_part" {
  description = "Partie gauche de l'expéditeur. Adresse finale = <local>@<root_domain>."
  type        = string
  default     = "no-reply"
}

variable "app_subdomain" {
  description = "Sous-domaine du portail. Site final = <app_subdomain>.<root_domain>."
  type        = string
  default     = "resume"
}


# ─── 2.4 Base de données ─────────────────────────────────────────────────────
# Ces identifiants alimentent À LA FOIS RDS et Secrets Manager, pour qu'ils ne
# puissent pas diverger. En production, remplacez le mot de passe par une
# valeur injectée hors du code (TF_VAR_db_password).
variable "db_username" {
  description = "Utilisateur maître de l'instance RDS PostgreSQL."
  type        = string
  default     = "portaladmin"
}

variable "db_password" {
  description = "Mot de passe maître RDS. Source unique partagée avec Secrets Manager."
  type        = string
  sensitive   = true
  default     = "utrains123!"

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password doit faire au moins 8 caractères (exigence RDS)."
  }
}


# ─── 2.5 Route 53 ────────────────────────────────────────────────────────────
# À renseigner uniquement si vous avez PLUSIEURS zones hébergées portant le
# même nom de domaine et qu'il faut lever l'ambiguïté.
variable "hosted_zone_id" {
  description = "ID de zone Route 53 exact. Vide = recherche automatique par nom."
  type        = string
  default     = ""
}
