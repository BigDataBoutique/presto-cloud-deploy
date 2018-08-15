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
  description = "Presto access"
  vpc_id = "${var.vpc_id}"

  tags {
    Name = "presto-${var.environment_name}"
    environment = "${var.environment_name}"
  }

  # All Presto communications are done via HTTP
  ingress {
    from_port         = "${var.http_port}"
    to_port           = "${var.http_port}"
    protocol          = "tcp"
    self              = true
  }

  ingress {
    from_port         = "${var.http_port}"
    to_port           = "${var.http_port}"
    protocol          = "tcp"
    cidr_blocks       = ["${concat(list(var.public_facing ? "0.0.0.0/0" : data.aws_subnet.selected.cidr_block), var.allow_cidr_blocks)}"]
  }

  # JMX
  ingress {
    from_port         = 33381
    to_port           = 33381
    protocol          = "tcp"
  }

  # ssh access from everywhere
  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }
}