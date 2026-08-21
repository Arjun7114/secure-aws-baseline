resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "secure-baseline-vpc"
  }
}
# Public Subnet - For internet-facing resources
resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130:Public subnet intentionally assigns public IPs for the internet-facing web server by design. Private workloads use the private subnet.
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "secure-baseline-public-subnet"
  }
}

# Private Subnet - Strictly isolated from direct internet access
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "secure-baseline-private-subnet"
  }
}
# Internet Gateway - The "front door" for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "secure-baseline-igw"
  }
}

# Public Route Table - Directs traffic to the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "secure-baseline-public-rt"
  }
}

# Route Table Association - Links the public subnet to the public route table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}
# ==========================================================
#  VPC Flow Logs  (CKV2_AWS_11, CKV_AWS_158, CKV_AWS_338,
#                  CKV_AWS_355, CKV_AWS_290)
# ==========================================================

# KMS key to encrypt the flow-log group (CKV_AWS_158)
# Read current account ID and region (needed for the key policy below)
# KMS key to encrypt the flow-log group (CKV_AWS_158, CKV2_AWS_64)
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
resource "aws_kms_key" "flow_logs" {
  description             = "KMS key for VPC flow logs"
  enable_key_rotation     = true
  deletion_window_in_days = 10

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
}

# CloudWatch log group that receives the flow logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/secure-baseline-flow-logs"
  retention_in_days = 365                          # at least 1 year (CKV_AWS_338)
  kms_key_id        = aws_kms_key.flow_logs.arn     # encryption (CKV_AWS_158)
}

# IAM role that lets the VPC flow-log service write to CloudWatch
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "secure-baseline-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

# Least-privilege policy: scoped to ONLY this log group (CKV_AWS_355, CKV_AWS_290)
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "secure-baseline-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

# The flow log itself, attached to the VPC
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# ==========================================================
#  Lock the VPC's default security group to deny-all (CKV2_AWS_12)
# ==========================================================
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  # No ingress or egress rules = deny all traffic
}    