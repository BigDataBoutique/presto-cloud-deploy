terraform {
  required_version = ">= 0.11.0"
}

provider "aws" {
  region = "${var.aws_region}"
}

data "aws_ami" "presto" {
  filter {
    name = "state"
    values = ["available"]
  }
  filter {
    name = "tag:ImageType"
    values = ["presto-packer-image"]
  }
  most_recent = true
}

resource "aws_security_group" "presto" {
  name = "presto-${var.environment_name}-clients-security-group"
  vpc_id = "${var.vpc_id}"

  tags {
    Name = "presto-${var.environment_name}"
    environment = "${var.environment_name}"
  }

  ingress {
    from_port         = 8080
    to_port           = 8080
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  # ssh access from everywhere
  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  # allow inter-cluster ping
  ingress {
    from_port         = 8
    to_port           = 0
    protocol          = "icmp"
    self              = true
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }
}