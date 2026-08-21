variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

# Web Security Group
resource "aws_security_group" "web_sg" {
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

  # Egress Rule: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-baseline-web-sg"
  }
}