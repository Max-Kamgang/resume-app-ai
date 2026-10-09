# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
resource "aws_vpc" "rp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"


  tags = {
    Name = "rp-vpc"
  }
}


# ─────────────────────────────────────────────
# Internet Gateway
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "rp_igw" {
  vpc_id = aws_vpc.rp_vpc.id


  tags = {
    Name = "rp-igw"
  }
}


# ─────────────────────────────────────────────
# Public Subnets (us-east-1a and us-east-1b)
# ─────────────────────────────────────────────
resource "aws_subnet" "rp_public_1a" {
  vpc_id                  = aws_vpc.rp_vpc.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = local.az_a
  map_public_ip_on_launch = true


  tags = {
    Name = "rp-subnet-public1-${local.az_a}"
  }
}


resource "aws_subnet" "rp_public_1b" {
  vpc_id                  = aws_vpc.rp_vpc.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = local.az_b
  map_public_ip_on_launch = true


  tags = {
    Name = "rp-subnet-public2-${local.az_b}"
  }
}


# ─────────────────────────────────────────────
# Private Subnets (us-east-1a and us-east-1b)
# ─────────────────────────────────────────────
resource "aws_subnet" "rp_private_1a" {
  vpc_id            = aws_vpc.rp_vpc.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = local.az_a


  tags = {
    Name = "rp-subnet-private1-${local.az_a}"
  }
}


resource "aws_subnet" "rp_private_1b" {
  vpc_id            = aws_vpc.rp_vpc.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = local.az_b


  tags = {
    Name = "rp-subnet-private2-${local.az_b}"
  }
}


# ─────────────────────────────────────────────
# Elastic IP for NAT Gateway (1 AZ only)
# ─────────────────────────────────────────────
resource "aws_eip" "rp_nat_eip" {
  domain = "vpc"


  tags = {
    Name = "rp-eip-${local.az_a}"
  }
}


# ─────────────────────────────────────────────
# NAT Gateway — placed in public subnet 1a
# ─────────────────────────────────────────────
resource "aws_nat_gateway" "rp_nat" {
  allocation_id = aws_eip.rp_nat_eip.id
  subnet_id     = aws_subnet.rp_public_1a.id


  tags = {
    Name = "rp-nat-public1-${local.az_a}"
  }


  depends_on = [aws_internet_gateway.rp_igw]

  # La passerelle NAT met 1 a 3 min a devenir disponible.
  timeouts {
    create = "30m"
    delete = "30m"
  }
}


# ─────────────────────────────────────────────
# Public Route Table
# ─────────────────────────────────────────────
resource "aws_route_table" "rp_public_rt" {
  vpc_id = aws_vpc.rp_vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rp_igw.id
  }


  tags = {
    Name = "rp-rtb-public"
  }
}


resource "aws_route_table_association" "rp_public_rta_1a" {
  subnet_id      = aws_subnet.rp_public_1a.id
  route_table_id = aws_route_table.rp_public_rt.id
}


resource "aws_route_table_association" "rp_public_rta_1b" {
  subnet_id      = aws_subnet.rp_public_1b.id
  route_table_id = aws_route_table.rp_public_rt.id
}


# ─────────────────────────────────────────────
# Private Route Table (both private subnets
# share the single NAT in us-east-1a)
# ─────────────────────────────────────────────
resource "aws_route_table" "rp_private_rt" {
  vpc_id = aws_vpc.rp_vpc.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.rp_nat.id
  }


  tags = {
    Name = "rp-rtb-private1-${local.az_a}"
  }
}


resource "aws_route_table_association" "rp_private_rta_1a" {
  subnet_id      = aws_subnet.rp_private_1a.id
  route_table_id = aws_route_table.rp_private_rt.id
}


resource "aws_route_table_association" "rp_private_rta_1b" {
  subnet_id      = aws_subnet.rp_private_1b.id
  route_table_id = aws_route_table.rp_private_rt.id
}

# Note: VPC Flow Logs (CloudWatch log group, IAM role/policy, flow log)
# are defined in flowlogs_cloudwatch.tf
