data "template_file" "client-userdata-script" {
  count    = var.count_clients != "0" ? 1 : 0
  template = file("${path.module}/../assets/client_user_data.sh")

  vars = {
    presto_coordinator_host = aws_elb.coordinator-lb.dns_name
    coordinator_port        = var.http_port
    admin_password          = var.count_clients != "0" ? random_string.clients-admin-password[0].result : ""
    cert_pem                = tls_self_signed_cert.presto-clients-cert.cert_pem
    key_pem                 = tls_private_key.presto-clients-private-key.private_key_pem
  }
}

resource "random_string" "clients-admin-password" {
  count   = var.count_clients != "0" ? 1 : 0
  length  = 16
  special = false
}

resource "tls_private_key" "presto-clients-private-key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "presto-clients-cert" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.presto-clients-private-key.private_key_pem

  subject {
    common_name = "*"
  }

  validity_period_hours = 48

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_iam_server_certificate" "presto-clients-cert" {
  name_prefix      = "presto-clients-cert"
  certificate_body = tls_self_signed_cert.presto-clients-cert.cert_pem
  private_key      = tls_private_key.presto-clients-private-key.private_key_pem

  lifecycle {
    create_before_destroy = true
  }
}

# Redash LB configuration
resource "aws_lb_target_group" "redash-https-clients" {
  name     = "redash-https-clients-tg"
  port     = "8500"
  protocol = "HTTPS"
  vpc_id   = data.aws_subnet.selected.vpc_id

  stickiness {
    type = "lb_cookie"
  }

  health_check {
    protocol = "HTTPS"
    matcher  = "302"
  }
}

resource "aws_lb_listener" "redash-https-clients" {
  count             = var.count_clients != "0" ? 1 : 0
  load_balancer_arn = aws_lb.clients-lb[0].arn
  port              = "8500"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_iam_server_certificate.presto-clients-cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.redash-https-clients.arn
  }
}

# Superset LB configuration
resource "aws_lb_target_group" "superset-https-clients" {
  name     = "superset-https-clients-tg"
  port     = "8600"
  protocol = "HTTPS"
  vpc_id   = data.aws_subnet.selected.vpc_id

  stickiness {
    type = "lb_cookie"
  }

  health_check {
    path     = "/health"
    protocol = "HTTPS"
  }
}

resource "aws_lb_listener" "superset-https-clients" {
  count             = var.count_clients != "0" ? 1 : 0
  load_balancer_arn = aws_lb.clients-lb[0].arn
  port              = "8600"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_iam_server_certificate.presto-clients-cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.superset-https-clients.arn
  }
}

# Zeppelin LB configuration
resource "aws_lb_target_group" "zeppelin-https-clients" {
  name     = "zeppelin-https-clients-tg"
  port     = "8700"
  protocol = "HTTPS"
  vpc_id   = data.aws_subnet.selected.vpc_id

  stickiness {
    type = "lb_cookie"
  }
}

resource "aws_lb_listener" "zeppelin-https-clients" {
  count             = var.count_clients != "0" ? 1 : 0
  load_balancer_arn = aws_lb.clients-lb[0].arn
  port              = "8700"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_iam_server_certificate.presto-clients-cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.zeppelin-https-clients.arn
  }
}

resource "aws_lb_listener_rule" "zeppelin-https-clients-websockets-rule" {
  count        = var.count_clients != "0" ? 1 : 0
  listener_arn = aws_lb_listener.zeppelin-https-clients[0].arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.zeppelin-https-clients.arn
  }

  condition {
    path_pattern {
      values = ["/ws"]
    }
  }
}

# Clients ALB
resource "aws_lb" "clients-lb" {
  count              = var.count_clients != "0" ? 1 : 0
  load_balancer_type = "application"
  internal           = "false"
  name               = format("%s-presto-client-lb", var.environment_name)
  security_groups = concat(
    [aws_security_group.presto-clients.id],
    var.additional_security_groups,
  )

  subnets = split(",", join(",", var.clients_lb_subnets))

  idle_timeout = 400

  tags = {
    Name = format("%s-presto-client-lb", var.environment_name)
  }
}

resource "aws_launch_configuration" "clients" {
  count                       = var.count_clients != "0" ? 1 : 0
  name_prefix                 = "presto-${var.environment_name}-client"
  image_id                    = data.aws_ami.presto-clients.id
  instance_type               = var.client_instance_type
  security_groups             = [aws_security_group.presto-clients.id]
  user_data                   = data.template_file.client-userdata-script[0].rendered
  key_name                    = var.key_name
  associate_public_ip_address = false
  spot_price                  = var.clients_use_spot == "true" ? var.client_spot_hourly_price : ""

  root_block_device {
    volume_size = 15 # GB
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "clients" {
  count                = var.count_clients != "0" ? 1 : 0
  name                 = "presto-${var.environment_name}-client"
  min_size             = "0"
  max_size             = "999"
  desired_capacity     = var.count_clients
  launch_configuration = aws_launch_configuration.clients[0].id
  vpc_zone_identifier = [var.subnet_id]
  target_group_arns = [
    aws_lb_target_group.redash-https-clients.arn,
    aws_lb_target_group.superset-https-clients.arn,
    aws_lb_target_group.zeppelin-https-clients.arn,
  ]

  tag {
    key                 = "Name"
    value               = format("presto-%s-client", var.environment_name)
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
    value               = var.clients_use_spot
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

