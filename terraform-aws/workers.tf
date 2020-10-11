data "template_file" "worker-userdata-script" {
  template = file("${path.module}/../assets/user_data.sh")

  vars = {
    cloud_provider             = "aws"
    mode_presto                = "worker"
    aws_region                 = var.aws_region
    environment_name           = var.environment_name
    http_port                  = var.http_port
    address_presto_coordinator = aws_elb.coordinator-lb.dns_name
    security_groups            = aws_security_group.presto.id
    heap_size                  = var.worker_heap_size
    query_max_memory_per_node  = ceil(var.worker_heap_size * 0.7)
    query_max_total_memory_per_node = ceil(var.worker_heap_size * 0.9)
    query_max_memory           = var.query_max_memory
    aws_access_key_id          = var.aws_access_key_id
    aws_secret_access_key      = var.aws_secret_access_key
    extra_worker_configs       = var.extra_worker_configs
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
  name_prefix          = "presto-${var.environment_name}-worker"
  min_size             = "0"
  max_size             = "999"
  desired_capacity     = var.count_workers
  launch_configuration = aws_launch_configuration.workers.id
  vpc_zone_identifier = [var.subnet_id]

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

