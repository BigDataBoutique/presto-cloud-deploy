resource "aws_ebs_volume" "coordinator" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = 10
  type              = "gp2"
  encrypted         = var.volume_encryption

  tags = {
    Name              = "presto-${var.environment_name}-coordinator"
    Environment       = var.environment_name
    PrestoCoordinator = true
  }
}
