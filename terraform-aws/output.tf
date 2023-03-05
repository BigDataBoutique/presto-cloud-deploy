output "coordinator-lb-dns" {
  value = aws_elb.coordinator-lb.*.dns_name
}

