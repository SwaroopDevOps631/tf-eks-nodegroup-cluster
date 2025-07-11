# ===========================================
# Terraform Configuration and AWS Provider
# ===========================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"  # AWS region to deploy resources
}

# ===========================================
# VPC – Virtual Private Cloud
# This is your own private network in AWS.
# ===========================================

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"  # Defines the overall IP address range
  tags = {
    Name = "eks_nodegroup_vpc"
  }
}

# ===========================================
# Subnets – Smaller networks within the VPC
# One private subnet (internal), one public subnet (accessible from internet)
# ===========================================

resource "aws_subnet" "eks_vpc_private_subnet" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "eks_vpc_private_subnet"
  }
}

resource "aws_subnet" "eks_vpc_public_subnet" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "eks_vpc_public_subnet"
  }
}

# ===========================================
# Internet Gateway – Enables internet access for public subnet
# ===========================================

resource "aws_internet_gateway" "eks_vpc_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_vpc_igw"
  }
}

# ===========================================
# Elastic IP – Static public IP required for NAT Gateway
# ===========================================

resource "aws_eip" "eks_vpc_eip" {
  vpc = true
  tags = {
    Name = "eks_vpc_eip"
  }
}

# ===========================================
# NAT Gateway – Allows private subnet resources to access internet securely
# ===========================================

resource "aws_nat_gateway" "eks_vpc_nat_gw" {
  allocation_id = aws_eip.eks_vpc_eip.id
  subnet_id     = aws_subnet.eks_vpc_public_subnet.id
  tags = {
    Name = "eks_vpc_nat_gw"
  }
}

# ===========================================
# Route Tables – Define routing rules for subnets
# ===========================================

# Private Route Table – routes internet traffic via NAT Gateway
resource "aws_route_table" "eks_vpc_private_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_vpc_private_route_table"
  }
}

resource "aws_route" "private_nat_gateway_access" {
  route_table_id         = aws_route_table.eks_vpc_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.eks_vpc_nat_gw.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.eks_vpc_private_subnet.id
  route_table_id = aws_route_table.eks_vpc_private_route_table.id
}

# Public Route Table – routes internet traffic via Internet Gateway
resource "aws_route_table" "eks_vpc_public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_vpc_public_route_table"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.eks_vpc_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks_vpc_igw.id
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.eks_vpc_public_subnet.id
  route_table_id = aws_route_table.eks_vpc_public_route_table.id
}

# ===========================================
# Security Group – Like a firewall for EKS cluster
# Allows inbound HTTP(80) and HTTPS(443) from internet
# ===========================================

resource "aws_security_group" "eks_vpc_sg" {
  name        = "eks_vpc_sg"
  description = "Allow HTTP and HTTPS inbound traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description      = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"  # allows all outbound traffic
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks_vpc_sg"
  }
}

# ===========================================
# IAM Roles – Permissions for EKS cluster and node group
# ===========================================

# Cluster role
resource "aws_iam_role" "eks_nodegroup_cluster" {
  name = "eks_nodegroup_cluster"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_nodegroup_cluster.name
}

# Node group role
resource "aws_iam_role" "eks_nodegroup_node" {
  name = "eks_nodegroup_node"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })
}

# Attach required policies to node role
resource "aws_iam_role_policy_attachment" "eks_nodegroup_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup_node.name
}

resource "aws_iam_role_policy_attachment" "eks_nodegroup_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup_node.name
}

resource "aws_iam_role_policy_attachment" "eks_nodegroup_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup_node.name
}

# ===========================================
# EKS Cluster – Managed Kubernetes cluster
# ===========================================

resource "aws_eks_cluster" "eks_nodegroup_cluster" {
  name     = "eks_nodegroup_cluster"
  role_arn = aws_iam_role.eks_nodegroup_cluster.arn

  vpc_config {
    subnet_ids         = [aws_subnet.eks_vpc_private_subnet.id, aws_subnet.eks_vpc_public_subnet.id]
    security_group_ids = [aws_security_group.eks_vpc_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_iam_role.eks_nodegroup_cluster
  ]
}

# ===========================================
# EKS Node Group – Worker nodes that run your containers
# ===========================================

resource "aws_eks_node_group" "eks_nodegroup" {
  cluster_name    = aws_eks_cluster.eks_nodegroup_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_nodegroup_node.arn
  subnet_ids      = [aws_subnet.eks_vpc_private_subnet.id, aws_subnet.eks_vpc_public_subnet.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]  # cost-effective instance for learning

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodegroup_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_nodegroup_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_nodegroup_AmazonEC2ContainerRegistryReadOnly
  ]
}
