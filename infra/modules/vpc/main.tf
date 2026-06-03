resource "aws_vpc" "eks-vpc" {
  cidr_block = ""

  tags = {
    Name = "eks-vpc ${var.environment}"
    Project = "terraform-eks"
  }
}