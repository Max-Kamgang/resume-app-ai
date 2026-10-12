locals {
  # Without a NAT gateway there is no route out of the private subnets, so the
  # servers have to sit in the public ones or they cannot reach dnf, S3,
  # Secrets Manager or the Gemini API at boot. They are no more exposed for it:
  # the EC2 security group only accepts port 80 from the load balancer.
  web_subnet_a  = var.enable_nat_gateway ? aws_subnet.rp_private_1a.id : aws_subnet.rp_public_1a.id
  web_subnet_b  = var.enable_nat_gateway ? aws_subnet.rp_private_1b.id : aws_subnet.rp_public_1b.id
  web_public_ip = !var.enable_nat_gateway
}


# ─────────────────────────────────────────────
# EC2 Instance 1 — first availability zone
# ─────────────────────────────────────────────
resource "aws_instance" "rp_server_1" {
  # AMI AL2023 la plus recente DE LA REGION COURANTE (cf. data.tf).
  # Un id code en dur n'est valable que dans une seule region.
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = local.web_subnet_a
  vpc_security_group_ids      = [aws_security_group.rp_ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.rp_ec2_profile.name
  associate_public_ip_address = local.web_public_ip

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
    company_name          = var.company_name
    ses_config_set        = aws_sesv2_configuration_set.rp_ses_config_set.configuration_set_name
    gemini_api_key        = var.gemini_api_key
    resend_api_key        = var.resend_api_key
    gemini_model          = var.gemini_model
    gemini_fallback_model = var.gemini_fallback_model
    match_threshold       = var.match_threshold
    app_base_url          = "https://${local.app_fqdn}"
    hr_portal_users_b64   = local.hr_portal_users_b64
    session_secret        = random_password.session_secret.result
    aws_region            = data.aws_region.current.region
  })


  tags = {
    Name    = "rp-server-1"
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# EC2 Instance 2 — second availability zone
#
# Not created when instance_count = 1: the Free Tier covers 750 instance-hours
# a month, which is one t3.micro running non-stop, not two.
# ─────────────────────────────────────────────
resource "aws_instance" "rp_server_2" {
  count = var.instance_count >= 2 ? 1 : 0

  # AMI AL2023 la plus recente DE LA REGION COURANTE (cf. data.tf).
  # Un id code en dur n'est valable que dans une seule region.
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = local.web_subnet_b
  vpc_security_group_ids      = [aws_security_group.rp_ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.rp_ec2_profile.name
  associate_public_ip_address = local.web_public_ip

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
    company_name          = var.company_name
    ses_config_set        = aws_sesv2_configuration_set.rp_ses_config_set.configuration_set_name
    gemini_api_key        = var.gemini_api_key
    resend_api_key        = var.resend_api_key
    gemini_model          = var.gemini_model
    gemini_fallback_model = var.gemini_fallback_model
    match_threshold       = var.match_threshold
    app_base_url          = "https://${local.app_fqdn}"
    hr_portal_users_b64   = local.hr_portal_users_b64
    session_secret        = random_password.session_secret.result
    aws_region            = data.aws_region.current.region
  })


  tags = {
    Name    = "rp-server-2"
    Project = "ResumePortal"
  }
}
