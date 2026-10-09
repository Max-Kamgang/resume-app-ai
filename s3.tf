# ─────────────────────────────────────────────
# S3 Bucket 1: Frontend (no encryption)
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "rp_frontend" {
  bucket        = local.frontend_bucket
  force_destroy = true


  tags = {
    Project = "ResumePortal"
  }
}


resource "aws_s3_bucket_public_access_block" "rp_frontend_pab" {
  bucket = aws_s3_bucket.rp_frontend.id


  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_versioning" "rp_frontend_versioning" {
  bucket = aws_s3_bucket.rp_frontend.id


  versioning_configuration {
    status = "Disabled"
  }
}


# ---------------------------------------------
# Application assets published to the frontend
# bucket. The EC2 instances pull these at boot and
# every 2 minutes, so editing index.html, app.py or
# a job description is a terraform apply - no
# instance replacement needed.
#
# etag/source_hash make Terraform notice local edits.
# ---------------------------------------------
resource "aws_s3_object" "rp_index_html" {
  bucket       = aws_s3_bucket.rp_frontend.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  etag         = filemd5("${path.module}/index.html")
  content_type = "text/html"


  tags = {
    Project = "ResumePortal"
  }
}


resource "aws_s3_object" "rp_app_py" {
  bucket       = aws_s3_bucket.rp_frontend.id
  key          = "app/app.py"
  source       = "${path.module}/app.py"
  etag         = filemd5("${path.module}/app.py")
  content_type = "text/x-python"


  tags = {
    Project = "ResumePortal"
  }
}


# Job openings fed to the model. Keyed by id, each
# entry carries the title shown in the dropdown and
# the job description the resume is scored against.
resource "aws_s3_object" "rp_jobs_json" {
  bucket       = aws_s3_bucket.rp_frontend.id
  key          = "app/jobs.json"
  content      = jsonencode(var.job_openings)
  content_type = "application/json"
  etag         = md5(jsonencode(var.job_openings))


  tags = {
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# S3 Bucket 2: Resumes (SSE-KMS, versioning on)
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "rp_resumes" {
  bucket        = local.resumes_bucket
  force_destroy = true


  tags = {
    Project = "ResumePortal"
  }
}


resource "aws_s3_bucket_public_access_block" "rp_resumes_pab" {
  bucket = aws_s3_bucket.rp_resumes.id


  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_versioning" "rp_resumes_versioning" {
  bucket = aws_s3_bucket.rp_resumes.id


  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "rp_resumes_encryption" {
  bucket = aws_s3_bucket.rp_resumes.id


  rule {
    bucket_key_enabled = true


    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.rp_s3_key.arn
    }
  }
}
