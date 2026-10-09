# Runtime-discovered values. Nothing is hardcoded here, which is what lets the
# stack deploy into any AWS account and any region.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


# An AMI id is valid in ONE region only. This public SSM parameter always points
# at the latest AL2023 image for the current region.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


# "us-east-1a" does not exist in Paris or Frankfurt. The filter excludes opt-in
# zones (Local Zones, Wavelength), which support neither RDS nor ALB.
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
