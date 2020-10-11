//data "aws_vpc" "selected" {
//  id = var.vpc_id
//}
//
data "aws_subnet" "selected" {
  id = var.subnet_id
}

