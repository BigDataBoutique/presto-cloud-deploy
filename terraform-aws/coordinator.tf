data "template_file" "coordinator-userdata-script" {
  template = file("${path.module}/../assets/user_data.sh")

  vars = {
    cloud_provider             = "aws"
    environment_name           = var.environment_name
    aws_region                 = var.aws_region
    http_port                  = var.http_port
    mode_presto                = var.count_workers == "0" && var.count_workers_spot == "0" ? "coordinator-worker" : "coordinator"
    heap_size                  = var.coordinator_heap_size
    query_max_memory_per_node  = ceil(var.worker_heap_size * 0.7)
    query_max_total_memory_per_node = ceil(var.worker_heap_size * 0.9)
    query_max_memory           = var.query_max_memory
    security_groups            = aws_security_group.presto.id
    aws_access_key_id          = var.aws_access_key_id
    aws_secret_access_key      = var.aws_secret_access_key
    address_presto_coordinator = ""
    extra_worker_configs       = var.extra_worker_configs
  }
}

resource "aws_launch_configuration" "coordinator" {
  name_prefix                 = "presto-${var.environment_name}-coordinator"
  image_id                    = data.aws_ami.presto.id
  instance_type               = var.coordinator_instance_type
  security_groups             = [aws_security_group.presto.id]
  iam_instance_profile        = aws_iam_instance_profile.presto.id
  associate_public_ip_address = var.public_facing
  user_data                   = data.template_file.coordinator-userdata-script.rendered
  key_name                    = var.key_name
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "coordinator" {
  name                 = "presto-${var.environment_name}-coordinator"
  min_size             = "0"
  max_size             = "1"
  desired_capacity     = "1"
  launch_configuration = aws_launch_configuration.coordinator.id
  vpc_zone_identifier = [var.subnet_id]

  load_balancers = [aws_elb.coordinator-lb.id]

  tag {
    key                 = "Name"
    value               = format("presto-%s-coordinator", var.environment_name)
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
  name = format("%s-presto-lb", var.environment_name)
  security_groups = concat(
    [aws_security_group.presto.id],
    var.additional_security_groups,
  )
  subnets  = [var.subnet_id]
  internal = var.public_facing == "true" ? "false" : "true"

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
    target              = "HTTP:8080/ui/"
    interval            = 6
  }

  tags = {
    Name = format("%s-presto-lb", var.environment_name)
  }
}

