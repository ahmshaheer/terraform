terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82.2"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  default = "vpc-01ce324ede0cc2843"
}

# Fetch the latest Ubuntu AMI
data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id
}

# Create Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table with the Subnet
resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id      = "subnet-0f800311f3e44ffa2" # Your custom subnet ID
  route_table_id = aws_route_table.public_rt.id
}

# Update Subnet to Assign Public IPs Automatically
resource "aws_subnet" "public_subnet" {
  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.2.0/24"  # New CIDR block
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"    # Adjust for your region
}

# Security Group for EC2 Instance
resource "aws_security_group" "ec2_security_group" {
  name_prefix = "ec2-sg-"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "ec2_instance" {
  ami                         = data.aws_ami.latest_ubuntu.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.ec2_security_group.id]
  subnet_id                   = "subnet-0f800311f3e44ffa2" # Updated public subnet ID
  associate_public_ip_address = true

  tags = {
    Name = "Terraform-EC2-Ubuntu"
  }
}

output "ec2_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.ec2_instance.public_ip
}

