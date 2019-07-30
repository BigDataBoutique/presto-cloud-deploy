data "template_file" "client-userdata-script" {
  count     = "${var.count_clients != "0" ? 1 : 0}"
  template  = "${file("${path.module}/../assets/client_user_data.sh")}"

  vars {
    presto_coordinator_host  = "${aws_elb.coordinator-lb.dns_name}"
    admin_password           = "${var.count_clients != "0" ? random_string.clients-admin-password.result : ""}"
    cert_pem                 = "${tls_self_signed_cert.presto-clients-cert.cert_pem}"
    key_pem                  = "${tls_private_key.presto-clients-private-key.private_key_pem}"
    nginx_conf               = "${file("../assets/nginx.conf")}"
    presto_zeppelin_interp   = "${file("../assets/zeppelin-interpreter.json")}"
  }
}

resource "random_string" "clients-admin-password" {
  count   = "${var.count_clients != "0" ? 1 : 0}"
  length  = 16
  special = false
}

resource "tls_private_key" "presto-clients-private-key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "presto-clients-cert" {
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.presto-clients-private-key.private_key_pem}"

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
  certificate_body = "${tls_self_signed_cert.presto-clients-cert.cert_pem}"
  private_key      = "${tls_private_key.presto-clients-private-key.private_key_pem}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "clients-lb" {
  count           = "${var.count_clients != "0" ? 1 : 0}"
  name            = "${format("%s-presto-clients-lb", var.environment_name)}"
  security_groups = ["${concat(list(aws_security_group.presto-clients.id), var.additional_security_groups)}"]
  subnets         = ["${var.subnet_id}"]
  internal        = "false" 

  cross_zone_load_balancing   = false
  idle_timeout                = 400

  listener {
    instance_port     = "10000"
    instance_protocol = "http"
    lb_port           = "10000"
    lb_protocol       = "http"
  }

  listener {
    instance_port     = "10001"
    instance_protocol = "https"
    lb_port           = "10001"
    lb_protocol         = "https"
    ssl_certificate_id  = "${aws_iam_server_certificate.presto-clients-cert.arn}"
  }
  
  listener {
    instance_port     = "20000"
    instance_protocol = "http"
    lb_port           = "20000"
    lb_protocol       = "http"
  }

  listener {
    instance_port     = "20001"
    instance_protocol = "https"
    lb_port           = "20001"
    lb_protocol         = "https"
    ssl_certificate_id  = "${aws_iam_server_certificate.presto-clients-cert.arn}"
  }

  listener {
    instance_port     = "30000"
    instance_protocol = "http"
    lb_port           = "30000"
    lb_protocol       = "http"
  }

  listener {
    instance_port     = "30001"
    instance_protocol = "https"
    lb_port           = "30001"
    lb_protocol         = "https"
    ssl_certificate_id  = "${aws_iam_server_certificate.presto-clients-cert.arn}"
  }
  
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/health"
    interval            = 6
  }
  
  tags {
    Name = "${format("%s-presto-client-lb", var.environment_name)}"
  }
}

resource "aws_app_cookie_stickiness_policy" "redash-stickiness-policy" {
  count                    = "${var.count_clients != "0" ? 1 : 0}"
  name                     = "redash-stickiness-policy"
  load_balancer            = "${aws_elb.clients-lb.id}"
  lb_port                  = 10000
  cookie_name              = "session"
}

resource "aws_app_cookie_stickiness_policy" "redash-https-stickiness-policy" {
  count                    = "${var.count_clients != "0" ? 1 : 0}"
  name                     = "redash-stickiness-policy"
  load_balancer            = "${aws_elb.clients-lb.id}"
  lb_port                  = 10001
  cookie_name              = "session"
}

resource "aws_app_cookie_stickiness_policy" "superset-stickiness-policy" {
  count                    = "${var.count_clients != "0" ? 1 : 0}"
  name                     = "superset-stickiness-policy"
  load_balancer            = "${aws_elb.clients-lb.id}"
  lb_port                  = 20000
  cookie_name              = "session"
}

resource "aws_app_cookie_stickiness_policy" "superset-https-stickiness-policy" {
  count                    = "${var.count_clients != "0" ? 1 : 0}"
  name                     = "superset-stickiness-policy"
  load_balancer            = "${aws_elb.clients-lb.id}"
  lb_port                  = 20001
  cookie_name              = "session"
}

resource "aws_launch_configuration" "clients" {
  count                       = "${var.count_clients != "0" ? 1 : 0}"
  name_prefix                 = "presto-${var.environment_name}-client"
  image_id                    = "${data.aws_ami.presto-clients.id}"
  instance_type               = "${var.client_instance_type}"
  security_groups             = ["${aws_security_group.presto-clients.id}"]
  user_data                   = "${data.template_file.client-userdata-script.rendered}"
  key_name                    = "${var.key_name}"
  associate_public_ip_address = false
  spot_price                  = "${var.clients_use_spot == "true" ? var.client_spot_hourly_price : ""}"

  root_block_device {
    volume_size = 15 # GB
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "clients" {
  count                 = "${var.count_clients != "0" ? 1 : 0}"
  name                  = "presto-${var.environment_name}-client"
  min_size              = "0"
  max_size              = "999"
  desired_capacity      = "${var.count_clients}"
  launch_configuration  = "${aws_launch_configuration.clients.id}"

  vpc_zone_identifier   = ["${var.subnet_id}"]
  availability_zones    = ["${data.aws_subnet.selected.availability_zone}"]
  load_balancers        = ["${aws_elb.clients-lb.id}"]

  tag {
    key = "Name"
    value = "${format("presto-%s-client", var.environment_name)}"
    propagate_at_launch = true
  }
  tag {
    key = "Environment"
    value = "${var.environment_name}"
    propagate_at_launch = true
  }
  tag {
    key = "Role"
    value = "worker"
    propagate_at_launch = true
  }
  tag {
    key = "Spot"
    value = "${var.clients_use_spot}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
