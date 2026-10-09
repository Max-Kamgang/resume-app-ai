# ─────────────────────────────────────────────
# EC2 Instance 1 — us-east-1a
# ─────────────────────────────────────────────
resource "aws_instance" "rp_server_1" {
  # AMI AL2023 la plus recente DE LA REGION COURANTE (cf. data.tf).
  # Un id code en dur n'est valable que dans une seule region.
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.rp_private_1a.id
  vpc_security_group_ids      = [aws_security_group.rp_ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.rp_ec2_profile.name
  associate_public_ip_address = false

  # The app, the frontend and the AI screening config all arrive through
  # user-data, so a change to it must actually reach the instances.
  user_data_replace_on_change = true


  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    resume_bucket         = aws_s3_bucket.rp_resumes.id
    assets_bucket         = aws_s3_bucket.rp_frontend.id
    jobs_key              = aws_s3_object.rp_jobs_json.key
    db_secret_name        = aws_secretsmanager_secret.rp_db_credentials.name
    sender_email          = local.sender_email
    sender_name           = local.sender_display_name
    hr_email              = var.hr_email
    ses_config_set        = aws_sesv2_configuration_set.rp_ses_config_set.configuration_set_name
    gemini_api_key        = var.gemini_api_key
    gemini_model          = var.gemini_model
    gemini_fallback_model = var.gemini_fallback_model
    match_threshold       = var.match_threshold
    booking_url           = var.interview_booking_url
    aws_region            = data.aws_region.current.region
  })


  tags = {
    Name    = "rp-server-1"
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# EC2 Instance 2 — us-east-1b
# ─────────────────────────────────────────────
resource "aws_instance" "rp_server_2" {
  # AMI AL2023 la plus recente DE LA REGION COURANTE (cf. data.tf).
  # Un id code en dur n'est valable que dans une seule region.
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.rp_private_1b.id
  vpc_security_group_ids      = [aws_security_group.rp_ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.rp_ec2_profile.name
  associate_public_ip_address = false

  # The app, the frontend and the AI screening config all arrive through
  # user-data, so a change to it must actually reach the instances.
  user_data_replace_on_change = true


  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }


  user_data = templatefile("${path.module}/user-data.sh", {
    resume_bucket         = aws_s3_bucket.rp_resumes.id
    assets_bucket         = aws_s3_bucket.rp_frontend.id
    jobs_key              = aws_s3_object.rp_jobs_json.key
    db_secret_name        = aws_secretsmanager_secret.rp_db_credentials.name
    sender_email          = local.sender_email
    sender_name           = local.sender_display_name
    hr_email              = var.hr_email
    ses_config_set        = aws_sesv2_configuration_set.rp_ses_config_set.configuration_set_name
    gemini_api_key        = var.gemini_api_key
    gemini_model          = var.gemini_model
    gemini_fallback_model = var.gemini_fallback_model
    match_threshold       = var.match_threshold
    booking_url           = var.interview_booking_url
    aws_region            = data.aws_region.current.region
  })


  tags = {
    Name    = "rp-server-2"
    Project = "ResumePortal"
  }
}
