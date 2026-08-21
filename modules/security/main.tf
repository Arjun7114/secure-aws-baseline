variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

# Web Security Group
resource "aws_security_group" "web_sg" {
  #checkov:skip=CKV_AWS_260:Public web server intentionally accepts HTTP from the internet on port 80 by design.
  #checkov:skip=CKV2_AWS_5:Security group is attached to the EC2 instance in the compute module; not visible when scanning this module in isolation.
  name        = "secure-baseline-web-sg"
  description = "Security group for web instances allowing HTTP/HTTPS ingress"
  vpc_id      = var.vpc_id

  # Ingress Rule: Allow HTTPS (TCP 443)
  ingress {
    description = "Allow HTTPS inbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress Rule: Allow HTTP (TCP 80)
  ingress {
    description = "Allow HTTP inbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound HTTPS (package updates, downloads)
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound HTTP (package repos that still use HTTP)
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-baseline-web-sg"
  }
}