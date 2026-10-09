# ─────────────────────────────────────────────
# IAM Role — EC2 trusted entity
# ─────────────────────────────────────────────
resource "aws_iam_role" "rp_ec2_role" {
  name        = "rp-ec2-role"
  description = "Allows EC2 to access S3, Secrets Manager, SES, and Session Manager"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })


  tags = {
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# Managed Policy — SSM Session Manager access
# ─────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "rp_ec2_ssm" {
  role       = aws_iam_role.rp_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# ─────────────────────────────────────────────
# Inline Policy — least privilege custom perms
# ─────────────────────────────────────────────
resource "aws_iam_role_policy" "rp_ec2_policy" {
  name = "rp-ec2-policy"
  role = aws_iam_role.rp_ec2_role.id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3UploadResumes"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.rp_resumes.arn}/*"
      },
      {
        # The app code, the frontend and jobs.json are pulled from the
        # frontend bucket at boot and by the periodic sync timer.
        Sid    = "AllowReadAppAssets"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.rp_frontend.arn}/*"
      },
      {
        Sid    = "AllowReadSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        # Les secrets utilisent name_prefix "rp-..." (cf. secretsmanger.tf),
        # donc le motif doit etre "rp-*" et non "rp/*" : sinon l'application
        # ne peut plus lire le mot de passe de la base.
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:rp-*"
      },
      {
        Sid    = "AllowKMSForS3AndRDS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.rp_s3_key.arn,
          aws_kms_key.rp_rds_key.arn
        ]
      },
      # Aucune permission IA ici : l'analyse des CV passe par l'API Gemini,
      # appelee directement avec une cle. Rien a autoriser cote AWS.
      {
        # Resource MUST stay "*". SendEmail is authorised against the
        # RECIPIENT identity as well as the sender, and applicants are
        # arbitrary addresses we cannot enumerate in advance. Scoping this
        # to our own identity ARNs denies every candidate email.
        # The sender is constrained instead, by condition, below.
        Sid    = "AllowSendEmail"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
        Condition = {
          # Two patterns because the From header carries a display name
          # ("Utrains HR <no-reply@...>") and the bare address form is also
          # possible. Both are anchored on the address, so no other sender
          # is permitted.
          StringLike = {
            "ses:FromAddress" = [
              local.sender_email,
              "*<${local.sender_email}>"
            ]
          }
        }
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/rp/*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# Instance Profile — wraps the role for EC2
# ─────────────────────────────────────────────
resource "aws_iam_instance_profile" "rp_ec2_profile" {
  name = "rp-ec2-profile"
  role = aws_iam_role.rp_ec2_role.name


  tags = {
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# KMS Key Policy update — add EC2 role as Key User
# on both rp-s3-key and rp-rds-key
# ─────────────────────────────────────────────
resource "aws_kms_grant" "rp_s3_key_ec2_grant" {
  name              = "rp-s3-key-ec2-grant"
  key_id            = aws_kms_key.rp_s3_key.key_id
  grantee_principal = aws_iam_role.rp_ec2_role.arn
  operations        = ["Decrypt", "GenerateDataKey"]
}


resource "aws_kms_grant" "rp_rds_key_ec2_grant" {
  name              = "rp-rds-key-ec2-grant"
  key_id            = aws_kms_key.rp_rds_key.key_id
  grantee_principal = aws_iam_role.rp_ec2_role.arn
  operations        = ["Decrypt", "GenerateDataKey"]
}
