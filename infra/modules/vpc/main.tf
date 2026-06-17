resource "aws_vpc" "eks-vpc" {
  cidr_block = var.vpc_cidr

   enable_dns_hostnames = true
   enable_dns_support   = true

  tags = {
    Name = "eks-vpc ${var.environment}"
    Project = "terraform-eks"
  }
}

# =================== public subnets ===================
# Create two public subnets in different availability zones
resource "aws_subnet" "eks-public-subnet" {
  vpc_id = aws_vpc.eks-vpc.id
  cidr_block = var.public_subnet_cidr[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "eks-public-subnet ${var.environment}"
    Project = "terraform-eks"
  }
}



resource "aws_subnet" "eks-public-subnet-2" {
  vpc_id = aws_vpc.eks-vpc.id
  cidr_block = var.public_subnet_cidr[1]
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "eks-public-subnet-2 ${var.environment}"
    Project = "terraform-eks"
  }
}

# =================== private subnets ===================
# Create two private subnets in different availability zones

resource "aws_subnet" "eks-private-subnet-1" {
  vpc_id = aws_vpc.eks-vpc.id
  cidr_block = var.private_subnet_cidr[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "eks-private-subnet-1 ${var.environment}"
    Project = "terraform-eks"
  }
}



resource "aws_subnet" "eks-private-subnet-2" {
  vpc_id = aws_vpc.eks-vpc.id
  cidr_block = var.private_subnet_cidr[1]
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "eks-private-subnet-2 ${var.environment}"
    Project = "terraform-eks"
  }
}

# =================== internet gateway ===================
resource "aws_internet_gateway" "eks-igw" {
  vpc_id = aws_vpc.eks-vpc.id

  tags = {
    Name = "eks-igw ${var.environment}"
    Project = "terraform-eks"
  }
}

# =================== Public route table and association ===================
resource "aws_route_table" "eks-public-rt" {
  vpc_id = aws_vpc.eks-vpc.id

  tags = {
    Name = "eks-public-rt ${var.environment}"
    Project = "terraform-eks"
  }
}

resource "aws_route" "eks-public-route" {
  route_table_id = aws_route_table.eks-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.eks-igw.id
}



resource "aws_route_table_association" "eks-public-rt-association" {
  subnet_id = aws_subnet.eks-public-subnet.id
  route_table_id = aws_route_table.eks-public-rt.id
}



# =================== Private route tables and association ===================

resource "aws_route_table" "eks-private-rt-1" {
  vpc_id = aws_vpc.eks-vpc.id 

  tags = {
    Name = "eks-private-rt-1 ${var.environment}"
    Project = "terraform-eks"
  }
}

resource "aws_route_table_association" "eks-private-rt-1-association" {
  subnet_id = aws_subnet.eks-private-subnet-1.id
  route_table_id = aws_route_table.eks-private-rt-1.id
}



resource "aws_route_table" "eks-private-rt-2" {
  vpc_id = aws_vpc.eks-vpc.id

  tags = {
    Name = "eks-private-rt-2 ${var.environment}"
    Project = "terraform-eks"
  }
}

resource "aws_route_table_association" "eks-private-rt-2-association" {
  subnet_id = aws_subnet.eks-private-subnet-2.id
  route_table_id = aws_route_table.eks-private-rt-2.id
}



