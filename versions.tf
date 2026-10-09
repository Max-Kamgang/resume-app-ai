terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.49.0"
    }
  }
}


# ─────────────────────────────────────────────
# AWS provider
#
# Resilience settings matter here because this stack is applied from laptops on
# home or campus Wi-Fi. A brief DNS or connectivity blip used to surface as
# "dial tcp: lookup ec2.us-east-1.amazonaws.com: no such host" and abort an
# apply that was otherwise healthy, leaving half-created resources behind.
#
#   max_retries  the SDK retries transient failures - including name-resolution
#                and connection errors - instead of failing the apply. 25 is the
#                provider default; 60 covers a connection drop of a minute or two.
#   retry_mode   "adaptive" backs off on throttling rather than hammering the
#                API, which also helps on new accounts with low rate limits.
#
# These only affect TRANSIENT failures. A real error - no permission, a name
# already taken - still fails straight away instead of retrying pointlessly.
# ─────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  max_retries = 60
  retry_mode  = "adaptive"

  default_tags {
    tags = {
      Project   = "ResumePortal"
      ManagedBy = "Terraform"
    }
  }
}
