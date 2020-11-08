resource "aws_launch_configuration" "workers-spot" {
  name_prefix                 = "presto-${var.environment_name}-worker-spot"
  image_id                    = data.aws_ami.presto.id
  instance_type               = var.worker_instance_type
  security_groups             = [aws_security_group.presto.id]
  iam_instance_profile        = aws_iam_instance_profile.presto.id
  associate_public_ip_address = false
  user_data                   = data.template_file.worker-userdata-script.rendered
  key_name                    = var.key_name
  spot_price                  = var.worker_spot_hourly_price

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers-spot" {
  name_prefix          = "presto-${var.environment_name}-worker-spot"
  min_size             = "0"
  max_size             = "999"
  desired_capacity     = var.count_workers_spot
  launch_configuration = aws_launch_configuration.workers-spot.id
  vpc_zone_identifier = [for s in data.aws_subnet.subnets : s.id]

  tag {
    key                 = "Name"
    value               = format("presto-%s-worker-spot", var.environment_name)
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment_name
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }
  tag {
    key                 = "Spot"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

