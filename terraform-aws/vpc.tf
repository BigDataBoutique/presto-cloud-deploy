data "aws_subnet" "subnets" {
  for_each = toset(var.subnet_ids)
  id = each.value
}

data "aws_subnet" "main_subnet" {
  id = var.subnet_ids[0]
}

data "aws_vpc" "main_vpc" {
  id = data.aws_subnet.main_subnet.vpc_id
}
