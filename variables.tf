###############################################################################
#  SECTION 1 — WHAT YOU MUST PROVIDE                                          #
#                                                                             #
#  Four values. The variables below have NO default, so Terraform asks for     #
#  them at launch — that is a prompt, not an error.                           #
#                                                                             #
#  To stop being asked:  cp terraform.tfvars.example terraform.tfvars         #
#  Everything in Section 2 already works as-is.                               #
###############################################################################

# Requires, BEFORE the first apply: you own this domain, a Route 53 hosted zone
# exists for it in THIS account, and the registrar points at that zone.
# Check with: aws route53 list-hosted-zones-by-name --dns-name example.com
variable "root_domain" {
  description = "Your domain, e.g. example.com. A Route 53 zone must already exist for it in this account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+[.][a-z0-9.-]*[a-z]{2,}$", var.root_domain))
    error_message = "root_domain must be a domain name such as example.com (no https:// and no www)."
  }
}


# A real inbox you can OPEN, not an address on your domain: verifying a domain
# in SES grants the right to SEND, not to receive. AWS mails a verification
# link here after the apply; you must click it.
variable "hr_email" {
  description = "Your real email address. Receives candidate replies and alerts."
  type        = string

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+[.][a-z]{2,}$", var.hr_email))
    error_message = "hr_email must be a valid email address, e.g. me@gmail.com."
  }
}


# Also composes the sender name shown to candidates: "Utrains" -> "Utrains HR".
variable "company_name" {
  description = "Your company name. Shown on the site and in the emails."
  type        = string

  validation {
    condition     = length(trimspace(var.company_name)) >= 2
    error_message = "company_name must be at least 2 characters."
  }
}


# Free from https://aistudio.google.com/apikey
# Terraform writes it to /opt/rp-app/.env on the servers. It also passes through
# terraform.tfstate IN CLEAR — the project .gitignore excludes that file, never
# force it into a repository.
variable "gemini_api_key" {
  description = "Gemini API key (https://aistudio.google.com/apikey)."
  type        = string
  sensitive   = true

  # Rejects the example text left as-is: otherwise a forgotten paste deploys a
  # whole stack whose screening fails silently.
  validation {
    condition     = !can(regex("(?i)paste|your-key|votre-cle|[.][.][.]", var.gemini_api_key))
    error_message = "You have not pasted your key yet. Open terraform.tfvars and replace the example text with the key from https://aistudio.google.com/apikey"
  }

  validation {
    condition     = length(trimspace(var.gemini_api_key)) >= 30
    error_message = "gemini_api_key looks too short. Get your key from https://aistudio.google.com/apikey"
  }
}


variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}


# Inclusive: at 80, a score of 80 is accepted and 79 is rejected.
variable "match_threshold" {
  description = "Score at or above which a candidate is invited to interview."
  type        = number
  default     = 80

  validation {
    condition     = var.match_threshold >= 0 && var.match_threshold <= 100
    error_message = "match_threshold must be between 0 and 100."
  }
}


# Set: the acceptance email carries a "Book my interview" button.
# Empty: the email asks the candidate for their availability instead.
variable "interview_booking_url" {
  description = "Scheduling link. Empty = ask the candidate for availability."
  type        = string
  default     = ""
}


# S3 bucket names are globally unique. Empty uses your AWS account id, which is
# unique by construction.
variable "bucket_suffix" {
  description = "Suffix for the S3 bucket names. Empty = AWS account id."
  type        = string
  default     = ""
}


# Each role carries:
#   description    the PUBLIC posting, read by the candidate AND by the AI
#   scoring_notes  the INTERNAL grid, read by the AI only, never exposed
#
# Format recognised by the site:
#   a short line ending in ":"  -> section heading
#   a line starting with "- "   -> bullet
#   anything else               -> paragraph
variable "job_openings" {
  description = "Open roles, keyed by a stable id."

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
      title      = "LLMOps Engineer"
      contract   = "Full-time"
      location   = "Hybrid — partly remote"
      experience = "5+ years of experience"

      description = <<-EOT
        We productionise applications built on large language models: internal
        assistants, document extraction, tool-using agents. You will own the whole
        chain that takes a prototype to a reliable, measured, cost-controlled service.

        What you will do:
        - Design, deploy and operate our inference services in production, on managed APIs as well as self-hosted models.
        - Build the orchestration layer: call chaining, tool use, structured outputs, guardrails and error recovery.
        - Build and maintain our evaluation sets: test cases, quality metrics, automated judges, regression detection on every prompt or model change.
        - Industrialise prompt versioning and progressive rollout, with full traceability of what runs in production.
        - Instrument LLM-specific observability: latency, token spend, cost per request, error rate, quality drift.
        - Optimise cost and latency: caching, context sizing, model choice matched to how critical the task is.
        - Build our RAG pipelines: ingestion, chunking, embeddings, vector store, retrieval and reranking strategies.
        - Secure the chain end to end: prompt injection defence, isolation of sensitive data, secret management.

        What we expect:
        - Five years in software, platform or MLOps engineering, including at least two on LLM systems genuinely running in production.
        - Production-grade Python: tested, typed, packaged, peer-reviewed code.
        - At least one LLM application you took to production, integrated with a model API.
        - Applied prompt engineering: structured outputs, tool use, context management.
        - Real evaluation practice: you can show an improvement by measurement, not by impression.
        - Docker, deployment on a public cloud (AWS preferred), infrastructure as code and CI/CD.

        What will set you apart:
        - Advanced RAG: vector stores, reranking, hybrid search.
        - Tool-using agents and integration protocols such as MCP.
        - Fine-tuning, distillation, quantisation, serving open models.
        - Kubernetes, Kafka or queues for asynchronous processing.
        - A feel for the security and compliance questions AI systems raise.
      EOT

      scoring_notes = <<-EOT
        Disqualifying signals (never quote verbatim to the candidate):
        - Experience limited to using a chat assistant, with nothing in production.
        - No objective evaluation of output quality.
        - Personal or tutorial projects only, with no professional context.
        Weighting: the six "What we expect" requirements are mandatory and carry most
        of the score. "What will set you apart" adds only a few points.
      EOT
    }

    devops-engineer = {
      title      = "DevOps Engineer"
      contract   = "Full-time"
      location   = "Hybrid — partly remote"
      experience = "5+ years of experience"

      description = <<-EOT
        The platform team runs the infrastructure our internal and customer-facing
        applications sit on. You will cover automation end to end: provisioning,
        continuous delivery, monitoring, security and cost control.

        What you will do:
        - Design and operate our production AWS infrastructure: VPC, public and private subnets, ALB, EC2, RDS, S3, IAM, KMS, Route 53, ACM.
        - Write and maintain all infrastructure in Terraform: reusable modules, remote state, plan review before every apply.
        - Build and maintain our full CI/CD pipelines — build, tests, security scanning, automated deployment, rollback.
        - Containerise applications with Docker and run them on Kubernetes or ECS: resource management, autoscaling, rolling updates.
        - Set up observability: metrics, centralised logs, traces, dashboards and alerting people can actually act on.
        - Apply security by default: least privilege in IAM, encryption at rest and in transit, secret rotation, network hardening.
        - Keep the platform resilient: tested backups, recovery plans, availability targets, incident handling and post-mortems.
        - Control cloud cost: right-sizing, reserved or spot instances, tracking and reducing the bill.

        What we expect:
        - Five years in DevOps, SRE or cloud engineering.
        - Deep AWS experience in production, well beyond occasional use or training labs.
        - Terraform in production: modules, remote state, review workflow.
        - Docker and container orchestration, Kubernetes or ECS.
        - CI/CD pipelines you built and maintained yourself.
        - Linux administration and solid networking fundamentals: TCP/IP, DNS, TLS.
        - Python or Bash scripting, Git and code review practice.
        - Monitoring, alerting and incident handling in production.

        What will set you apart:
        - An AWS certification (Solutions Architect, DevOps Engineer Professional).
        - Ansible or an equivalent configuration management tool.
        - GitOps (ArgoCD, Flux), service mesh, policy as code.
        - PostgreSQL administration and performance tuning.
        - Multi-account AWS, Landing Zone, FinOps experience.
      EOT

      scoring_notes = <<-EOT
        Disqualifying signals (never quote verbatim to the candidate):
        - Cloud experience that is only theoretical or limited to personal projects.
        - No infrastructure-as-code practice.
        - An AWS certification with no matching operational experience.
        Weighting: the eight "What we expect" requirements are mandatory and carry most
        of the score. "What will set you apart" adds only a few points.
      EOT
    }
  }
}


###############################################################################
#  SECTION 2 — ADVANCED                                                       #
#  These defaults work as-is. You normally never need to touch them.          #
###############################################################################

# Flash is fast and cheap, and plenty for matching a CV to a posting.
variable "gemini_model" {
  description = "Gemini model used to score CVs."
  type        = string
  default     = "gemini-3.8-flash"
}

# The newest models occasionally answer 503 "high demand".
variable "gemini_fallback_model" {
  description = "Model used when the primary one is overloaded. Empty = no fallback."
  type        = string
  default     = "gemini-flash-latest"
}

variable "sender_display_name" {
  description = "Sender name. Empty = \"<company_name> HR\"."
  type        = string
  default     = ""
}

variable "sender_local_part" {
  description = "Left part of the sender address. Final = <local>@<root_domain>."
  type        = string
  default     = "no-reply"
}

variable "app_subdomain" {
  description = "Portal subdomain. Site = <app_subdomain>.<root_domain>."
  type        = string
  default     = "resume"
}

# Feeds both RDS and Secrets Manager so they cannot drift apart. In production,
# inject the password out of band with TF_VAR_db_password.
variable "db_username" {
  description = "RDS PostgreSQL master username."
  type        = string
  default     = "portaladmin"
}

variable "db_password" {
  description = "RDS master password. Single source shared with Secrets Manager."
  type        = string
  sensitive   = true
  default     = "utrains123!"

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password must be at least 8 characters (RDS requirement)."
  }
}

# Only needed when several hosted zones share the same domain name.
variable "hosted_zone_id" {
  description = "Exact Route 53 zone id. Empty = look it up by name."
  type        = string
  default     = ""
}
