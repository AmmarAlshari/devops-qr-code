# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "devops-capstone-vpc"
  }
}

# Subnets
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "subnet-1" }
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
  tags = { Name = "subnet-2" }
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.32.0/20"
  availability_zone       = "eu-north-1c"
  map_public_ip_on_launch = true
  tags = { Name = "subnet-3" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "devops-capstone-igw" }
}

# Public Route Table
resource "aws_route_table" "public_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = { Name = "public-route-table" }
}

# Associate route table to subnets
resource "aws_route_table_association" "subnet_assoc" {
  count          = 3
  subnet_id      = element([aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id], count.index)
  route_table_id = aws_route_table.public_table.id
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "devops-capstone-project"
  cluster_version = "1.33"

  cluster_endpoint_public_access = true

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  control_plane_subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]

  eks_managed_node_groups = {
    green = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.micro"] # Free Tier
    }
  }

  tags = {
    Environment = "dev"
    Project     = "capstone"
  }
}