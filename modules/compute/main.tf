variable "public_subnet_id" {
  description = "ID of the public subnet where the server will live"
  type        = string
}

variable "web_sg_id" {
  description = "ID of the web security group"
  type        = string
}

# Automatically find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- IAM role so the instance gets an identity (CKV2_AWS_41) ---

# 1. Trust policy: allow EC2 to assume this role
resource "aws_iam_role" "web_server_role" {
  name = "secure-baseline-web-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "secure-baseline-web-server-role"
  }
}

# 2. Instance profile: the wrapper that lets an EC2 instance use the role
resource "aws_iam_instance_profile" "web_server_profile" {
  name = "secure-baseline-web-server-profile"
  role = aws_iam_role.web_server_role.name
}
# The actual EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro" # Free-tier eligible
  iam_instance_profile = aws_iam_instance_profile.web_server_profile.name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.web_sg_id]
  root_block_device {
    encrypted = true
  }

  # Require IMDSv2 (CKV_AWS_79)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Detailed CloudWatch monitoring (CKV_AWS_126)
  monitoring = true

  # EBS-optimized storage (CKV_AWS_135)
  ebs_optimized = true

  # This script runs once on the very first boot
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Secure Baseline Network is Active and Routing Traffic!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "secure-baseline-web-server"
  }
}