# ─────────────────────────────────────────────
# CloudWatch Log Group for VPC Flow Logs
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "rp_flow_logs" {
  # name_prefix : un destroy interrompu laisse parfois le groupe de logs
  # derriere lui, et l'apply suivant echoue sur "log group already exists".
  # Un prefixe genere un nom unique, donc plus aucune collision possible.
  name_prefix       = "/rp/vpc/flow-logs-"
  log_group_class   = "STANDARD"
  retention_in_days = 30


  tags = {
    Project = "ResumePortal"
  }
}


# ─────────────────────────────────────────────
# IAM Role — trusted by vpc-flow-logs service
# ─────────────────────────────────────────────
resource "aws_iam_role" "rp_flow_logs_role" {
  name        = "rp-flow-logs-role"
  description = "Allows VPC Flow Logs to write to CloudWatch"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
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
# Inline Policy — write permissions scoped to
# the specific log group (no hardcoded IDs)
# ─────────────────────────────────────────────
resource "aws_iam_role_policy" "rp_flow_logs_policy" {
  name = "rp-flow-logs-policy"
  role = aws_iam_role.rp_flow_logs_role.id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.rp_flow_logs.arn}:*"
      }
    ]
  })
}


# ─────────────────────────────────────────────
# VPC Flow Log
# ─────────────────────────────────────────────
resource "aws_flow_log" "rp_vpc_flow_log" {
  vpc_id          = aws_vpc.rp_vpc.id
  log_destination = aws_cloudwatch_log_group.rp_flow_logs.arn
  iam_role_arn    = aws_iam_role.rp_flow_logs_role.arn


  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  max_aggregation_interval = 60


  tags = {
    Name    = "rp-vpc-flow-logs"
    Project = "ResumePortal"
  }
}
