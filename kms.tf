# ─────────────────────────────────────────────
# KMS Key 1: S3 Resume Bucket
# ─────────────────────────────────────────────
resource "aws_kms_key" "rp_s3_key" {
  description              = "Encrypts resumes in the S3 bucket - PII data"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  multi_region             = false


  # Every 3 months automatic key rotation
  enable_key_rotation     = true
  rotation_period_in_days = 90


  deletion_window_in_days = 7


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Full admin access for the root account
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Key administrators — your IAM user / admin role
      {
        Sid    = "KeyAdministrators"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      }
      # Key Users (EC2 role) will be added in Part 7
    ]
  })


  tags = {
    Name    = "rp-s3-key"
    Project = "ResumePortal"
  }
}


resource "aws_kms_alias" "rp_s3_key_alias" {
  name          = "alias/rp-s3-key"
  target_key_id = aws_kms_key.rp_s3_key.key_id
}


# ─────────────────────────────────────────────
# KMS Key 2: RDS PostgreSQL Database
# ─────────────────────────────────────────────
resource "aws_kms_key" "rp_rds_key" {
  description              = "Encrypts the RDS PostgreSQL database"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  multi_region             = false


  # Every 2 months automatic key rotation
  enable_key_rotation     = true
  rotation_period_in_days = 90




  deletion_window_in_days = 7


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Full admin access for the root account
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Key administrators
      {
        Sid    = "KeyAdministrators"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      }
      # Key Users (EC2 role) will be added in Part 7
    ]
  })


  tags = {
    Name    = "rp-rds-key"
    Project = "ResumePortal"
  }
}


resource "aws_kms_alias" "rp_rds_key_alias" {
  name          = "alias/rp-rds-key"
  target_key_id = aws_kms_key.rp_rds_key.key_id
}


# ─────────────────────────────────────────────
# Outputs — ARNs needed in Parts 3 (S3) & 4 (RDS)
# ─────────────────────────────────────────────
output "rp_s3_key_arn" {
  description = "KMS key ARN for the S3 resume bucket"
  value       = aws_kms_key.rp_s3_key.arn
}


output "rp_rds_key_arn" {
  description = "KMS key ARN for the RDS PostgreSQL database"
  value       = aws_kms_key.rp_rds_key.arn
}
