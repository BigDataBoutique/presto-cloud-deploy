terraform {
  required_version = ">= 0.11.0"
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "trino" {
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "tag:ImageType"
    values = ["trino-packer-image"]
  }
  owners      = ["self"]
  most_recent = true
}

resource "aws_security_group" "trino" {
  name        = "trino-${var.environment_name}-security-group"
  description = "Trino access"
  vpc_id      = data.aws_subnet.main_subnet.vpc_id

  tags = {
    Name        = "trino-${var.environment_name}"
    environment = var.environment_name
  }

  # All Trino communications are done via HTTP
  ingress {
    from_port = var.http_port
    to_port   = var.http_port
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = var.http_port
    to_port   = var.http_port
    protocol  = "tcp"
    cidr_blocks = concat(
      [
        var.public_facing ? "0.0.0.0/0" : data.aws_subnet.main_subnet.cidr_block,
      ],
      var.allow_cidr_blocks,
    )
  }

  # JMX
  ingress {
    from_port = 33381
    to_port   = 33381
    protocol  = "tcp"
    self      = true
  }

  # ssh access from everywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
