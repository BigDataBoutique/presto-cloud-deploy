data "template_file" "coordinator-userdata-script" {
  template = "${file("${path.module}/../assets/user_data.sh")}"

  vars {
    cloud_provider              = "aws"
    mode_presto                 = "${var.count_workers == "0" ? "coordinator-worker" : "coordinator"}"
    worker_heap_size            = "${var.worker_heap_size}"
    environment_name            = "${var.environment_name}"
    security_groups             = "${aws_security_group.presto.id}"
    http_port                   = "${var.http_port}"
    address_presto_coordinator  = ""
  }
}

resource "aws_launch_configuration" "coordinator" {
  name_prefix = "presto-${var.environment_name}-coordinator"
  image_id = "${data.aws_ami.presto.id}"
  instance_type = "${var.coordinator_instance_type}"
  security_groups = ["${aws_security_group.presto.id}"]
  associate_public_ip_address = "${var.public_facing}"
  user_data = "${data.template_file.coordinator-userdata-script.rendered}"
  key_name = "${var.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "coordinator" {
  name = "presto-${var.environment_name}-coordinator"
  min_size = "0"
  max_size = "1"
  desired_capacity = "1"
  default_cooldown = 30
  force_delete = true
  launch_configuration = "${aws_launch_configuration.coordinator.id}"

  vpc_zone_identifier = ["${data.aws_subnet_ids.selected.ids}"]

  tag {
    key = "Name"
    value = "${format("%s-presto", var.environment_name)}"
    propagate_at_launch = true
  }
  tag {
    key = "Environment"
    value = "${var.environment_name}"
    propagate_at_launch = true
  }
  tag {
    key = "Role"
    value = "coordinator"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
