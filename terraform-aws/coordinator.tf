data "template_file" "coordinator-userdata-script" {
  template = templatefile("${path.module}/../assets/user_data.sh", {
    cloud_provider                  = "aws"
    environment_name                = var.environment_name
    aws_region                      = var.aws_region
    http_port                       = var.http_port
    mode_trino                     = var.count_workers == "0" && var.count_workers_spot == "0" ? "coordinator-worker" : "coordinator"
    heap_size                       = var.coordinator_heap_size
    query_max_memory_per_node       = ceil(var.worker_heap_size * 0.4)
    query_max_total_memory_per_node = ceil(var.worker_heap_size * 0.6)
    query_max_memory                = var.query_max_memory
    security_groups                 = aws_security_group.trino.id
    address_trino_coordinator      = ""
    extra_worker_configs            = var.extra_worker_configs
    additional_bootstrap_scripts    = var.additional_bootstrap_scripts

  })
}

resource "aws_launch_configuration" "coordinator" {
  name_prefix                 = "trino-${var.environment_name}-coordinator"
  image_id                    = data.aws_ami.trino.id
  instance_type               = var.coordinator_instance_type
  security_groups             = concat([aws_security_group.trino.id], var.additional_security_groups)
  iam_instance_profile        = aws_iam_instance_profile.trino.id
  associate_public_ip_address = var.public_facing
  user_data                   = data.template_file.coordinator-userdata-script.rendered
  key_name                    = var.key_name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "coordinator" {
  name                 = "trino-${var.environment_name}-coordinator"
  min_size             = "0"
  max_size             = "1"
  desired_capacity     = "1"
  launch_configuration = aws_launch_configuration.coordinator.id
  vpc_zone_identifier = [data.aws_subnet.main_subnet.id]

  load_balancers = [aws_elb.coordinator-lb.id]

  tag {
    key                 = "Name"
    value               = format("trino-%s-coordinator", var.environment_name)
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment_name
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "coordinator"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "coordinator-lb" {
  name = format("%s-trino-lb", var.environment_name)
  security_groups = concat(
    [aws_security_group.trino.id],
    var.additional_security_groups,
  )
  subnets  = [for s in data.aws_subnet.subnets : s.id]
  internal = !var.public_facing

  cross_zone_load_balancing = false
  idle_timeout              = 400

  listener {
    instance_port     = var.http_port
    instance_protocol = "http"
    lb_port           = var.http_port
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/ui/login.html"
    interval            = 6
  }

  tags = {
    Name = format("%s-trino-lb", var.environment_name)
  }
}

