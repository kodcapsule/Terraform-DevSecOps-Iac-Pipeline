# output the vpc id
output "vpc_id" {
  value = aws_vpc.eks-vpc.id
}

# output the public subnet ids
output "public_subnet_ids" {
  value = [aws_subnet.eks-public-subnet.id, aws_subnet.eks-public-subnet-2.id]
}

#  output the public Ips of the public subnets
output "public_subnet_public_ips" {
  value = [aws_subnet.eks-public-subnet.map_public_ip_on_launch, aws_subnet.eks-public-subnet-2.map_public_ip_on_launch]
}

# output the availability zones
output "availability_zones" {
  value = data.aws_availability_zones.available.names
}

# output the private subnet ids
output "private_subnet_ids" {
  value = [aws_subnet.eks-private-subnet-1.id, aws_subnet.eks-private-subnet-2.id]
}