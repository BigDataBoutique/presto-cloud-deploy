data "template_file" "worker-userdata-script" {
  template = templatefile("${path.module}/../assets/user_data.sh", {
    cloud_provider                  = "aws"
    mode_trino                     = "worker"
    aws_region                      = var.aws_region
    environment_name                = var.environment_name
    http_port                       = var.http_port
    address_trino_coordinator      = aws_elb.coordinator-lb.dns_name
    security_groups                 = aws_security_group.trino.id
    heap_size                       = var.worker_heap_size
    query_max_memory                = var.query_max_memory
    extra_worker_configs            = var.extra_worker_configs
    additional_bootstrap_scripts    = var.additional_bootstrap_scripts
  })
}


resource "null_resource" "render-template" {
  triggers = {
    json = data.template_file.worker-userdata-script.rendered
  }
}


resource "aws_launch_configuration" "workers" {
  name_prefix                 = "trino-${var.environment_name}-worker"
  image_id                    = data.aws_ami.trino.id
  instance_type               = var.worker_instance_type
  security_groups             = [aws_security_group.trino.id]
  iam_instance_profile        = aws_iam_instance_profile.trino.id
  associate_public_ip_address = var.public_facing
  user_data                   = data.template_file.worker-userdata-script.rendered
  key_name                    = var.key_name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers" {
  name_prefix          = "trino-${var.environment_name}-worker"
  min_size             = "0"
  max_size             = "999"
  desired_capacity     = var.count_workers
  launch_configuration = aws_launch_configuration.workers.id
  vpc_zone_identifier  = var.subnet_ids

  tag {
    key                 = "Name"
    value               = format("trino-%s-worker", var.environment_name)
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

