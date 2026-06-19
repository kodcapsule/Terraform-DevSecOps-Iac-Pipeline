resource "aws_vpc" "eks-vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    Name    = "eks-vpc ${var.environment}"
    Project = "terraform-eks"
  }
}
# ====================================================
# VPC flow logs configuration
resource "aws_flow_log" "eks-vpc-flow-log" {
  iam_role_arn         = aws_iam_role.eks-vpc-flow-log-role.arn
  log_destination      = aws_cloudwatch_log_group.eks-vpc-flow-log.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.eks-vpc.id

  tags = {
    Name    = "eks-vpc-flow-log ${var.environment}"
    Project = "terraform-eks"
  }
}

#trivy:ignore:AWS-0017
resource "aws_cloudwatch_log_group" "eks-vpc-flow-log" {
  name              = "/aws/vpc/eks-vpc-flow-log-${var.environment}"
  retention_in_days = 30

  tags = {
    Name    = "eks-vpc-flow-log ${var.environment}"
    Project = "terraform-eks"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "eks-vpc-flow-log-role" {
  name               = "eks-vpc-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "eks-vpc-flow-log-policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = [
      aws_cloudwatch_log_group.eks-vpc-flow-log.arn,
      "${aws_cloudwatch_log_group.eks-vpc-flow-log.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "eks-vpc-flow-log-policy" {
  name   = "eks-vpc-flow-log-policy"
  role   = aws_iam_role.eks-vpc-flow-log-role.id
  policy = data.aws_iam_policy_document.eks-vpc-flow-log-policy.json
}


# ====================================================



data "aws_availability_zones" "available" {
  state = "available"
}

# =================== public subnets ===================
# Create two public subnets in different availability zones
resource "aws_subnet" "eks-public-subnet" {
  vpc_id            = aws_vpc.eks-vpc.id
  cidr_block        = var.public_subnet_cidr[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name    = "eks-public-subnet ${var.environment}"
    Project = "terraform-eks"
  }
}



resource "aws_subnet" "eks-public-subnet-2" {
  vpc_id            = aws_vpc.eks-vpc.id
  cidr_block        = var.public_subnet_cidr[1]
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name    = "eks-public-subnet-2 ${var.environment}"
    Project = "terraform-eks"
  }
}

# =================== private subnets ===================
# Create two private subnets in different availability zones

resource "aws_subnet" "eks-private-subnet-1" {
  vpc_id            = aws_vpc.eks-vpc.id
  cidr_block        = var.private_subnet_cidr[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name    = "eks-private-subnet-1 ${var.environment}"
    Project = "terraform-eks"
  }
}



resource "aws_subnet" "eks-private-subnet-2" {
  vpc_id            = aws_vpc.eks-vpc.id
  cidr_block        = var.private_subnet_cidr[1]
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name    = "eks-private-subnet-2 ${var.environment}"
    Project = "terraform-eks"
  }
}

# =================== internet gateway ===================
resource "aws_internet_gateway" "eks-igw" {
  vpc_id = aws_vpc.eks-vpc.id

  tags = {
    Name    = "eks-igw ${var.environment}"
    Project = "terraform-eks"
  }
}

# =================== Public route table and association ===================
resource "aws_route_table" "eks-public-rt" {
  vpc_id = aws_vpc.eks-vpc.id

  tags = {
    Name    = "eks-public-rt ${var.environment}"
    Project = "terraform-eks"
  }
}

resource "aws_route" "eks-public-route" {
  route_table_id         = aws_route_table.eks-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks-igw.id
}



resource "aws_route_table_association" "eks-public-rt-association" {
  subnet_id      = aws_subnet.eks-public-subnet.id
  route_table_id = aws_route_table.eks-public-rt.id
}



# =================== Private route tables and association ===================
# Create two private route tables and associate them with the private subnets

resource "aws_route_table" "eks-private-rt-1" {
  vpc_id = aws_vpc.eks-vpc.id

  tags = {
    Name    = "eks-private-rt-1 ${var.environment}"
    Project = "terraform-eks"
  }
}

resource "aws_route_table_association" "eks-private-rt-1-association" {
  subnet_id      = aws_subnet.eks-private-subnet-1.id
  route_table_id = aws_route_table.eks-private-rt-1.id
}



resource "aws_route_table" "eks-private-rt-2" {
  vpc_id = aws_vpc.eks-vpc.id

  tags = {
    Name    = "eks-private-rt-2 ${var.environment}"
    Project = "terraform-eks"
  }
}

resource "aws_route_table_association" "eks-private-rt-2-association" {
  subnet_id      = aws_subnet.eks-private-subnet-2.id
  route_table_id = aws_route_table.eks-private-rt-2.id
}



