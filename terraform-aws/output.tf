output "coordinator-lb-dns" {
  value = aws_elb.coordinator-lb.*.dns_name
}

output "clients-lb-dns" {
  value = aws_lb.clients-lb.*.dns_name
}

output "clients-admin-password" {
  value = random_string.clients-admin-password.*.result
}

