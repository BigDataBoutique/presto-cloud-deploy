data "template_file" "worker-userdata-script" {
  template = file("${path.module}/../assets/user_data.sh")

  vars = {
    cloud_provider             = "aws"
    mode_presto                = "worker"
    heap_size                  = var.worker_heap_size
    memory_size                = var.worker_memory_size
    total_memory_size          = var.worker_memory_size + 3
    query_max_memory           = var.query_max_memory
    environment_name           = var.environment_name
    security_groups            = aws_security_group.presto.id
    aws_access_key_id          = var.aws_access_key_id
    aws_secret_access_key      = var.aws_secret_access_key
    http_port                  = var.http_port
    address_presto_coordinator = aws_elb.coordinator-lb.dns_name
  }
}

resource "aws_launch_configuration" "workers" {
  name_prefix                 = "presto-${var.environment_name}-worker"
  image_id                    = data.aws_ami.presto.id
  instance_type               = var.worker_instance_type
  security_groups             = [aws_security_group.presto.id]
  iam_instance_profile        = aws_iam_instance_profile.presto.id
  associate_public_ip_address = false
  user_data                   = data.template_file.worker-userdata-script.rendered
  key_name                    = var.key_name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers" {
  name                 = "presto-${var.environment_name}-worker"
  min_size             = "0"
  max_size             = "999"
  desired_capacity     = var.count_workers
  launch_configuration = aws_launch_configuration.workers.id

  vpc_zone_identifier = [var.subnet_id]
  availability_zones  = [data.aws_subnet.selected.availability_zone]

  tag {
    key                 = "Name"
    value               = format("presto-%s-worker", var.environment_name)
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
    value               = "false"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

