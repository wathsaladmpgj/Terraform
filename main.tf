terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------- VPCs ----------------
resource "aws_vpc" "app" {
  cidr_block           = var.app_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "app-vpc" }
}

resource "aws_vpc" "shared" {
  cidr_block           = var.shared_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "shared-vpc" }
}

# ------------- Internet Gateways -------------
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app.id
  tags   = { Name = "app-igw" }
}

resource "aws_internet_gateway" "shared_igw" {
  vpc_id = aws_vpc.shared.id
  tags   = { Name = "shared-igw" }
}

# ---------------- Subnets ----------------
# App VPC
resource "aws_subnet" "app_public" {
  vpc_id                 = aws_vpc.app.id
  cidr_block             = "10.10.1.0/24"
  availability_zone      = var.az
  map_public_ip_on_launch = true
  tags = { Name = "app-public" }
}

resource "aws_subnet" "app_private" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "10.10.101.0/24"
  availability_zone = var.az
  tags = { Name = "app-private" }
}

# Shared VPC
resource "aws_subnet" "shared_public" {
  vpc_id                 = aws_vpc.shared.id
  cidr_block             = "10.20.1.0/24"
  availability_zone      = var.az
  map_public_ip_on_launch = true
  tags = { Name = "shared-public" }
}

resource "aws_subnet" "shared_private" {
  vpc_id            = aws_vpc.shared.id
  cidr_block        = "10.20.101.0/24"
  availability_zone = var.az
  tags = { Name = "shared-private" }
}

# ---------------- Route Tables ----------------
# App Public RT -> IGW
resource "aws_route_table" "app_public_rt" {
  vpc_id = aws_vpc.app.id
  tags   = { Name = "app-public-rt" }
}

resource "aws_route" "app_public_default" {
  route_table_id         = aws_route_table.app_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.app_igw.id
}

resource "aws_route_table_association" "app_public_assoc" {
  subnet_id      = aws_subnet.app_public.id
  route_table_id = aws_route_table.app_public_rt.id
}

# App Private RT -> NAT instance (created later)
resource "aws_route_table" "app_private_rt" {
  vpc_id = aws_vpc.app.id
  tags   = { Name = "app-private-rt" }
}

resource "aws_route_table_association" "app_private_assoc" {
  subnet_id      = aws_subnet.app_private.id
  route_table_id = aws_route_table.app_private_rt.id
}

# Shared Public RT -> IGW
resource "aws_route_table" "shared_public_rt" {
  vpc_id = aws_vpc.shared.id
  tags   = { Name = "shared-public-rt" }
}

resource "aws_route" "shared_public_default" {
  route_table_id         = aws_route_table.shared_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.shared_igw.id
}

resource "aws_route_table_association" "shared_public_assoc" {
  subnet_id      = aws_subnet.shared_public.id
  route_table_id = aws_route_table.shared_public_rt.id
}

# Shared Private RT (no internet by default)
resource "aws_route_table" "shared_private_rt" {
  vpc_id = aws_vpc.shared.id
  tags   = { Name = "shared-private-rt" }
}

resource "aws_route_table_association" "shared_private_assoc" {
  subnet_id      = aws_subnet.shared_private.id
  route_table_id = aws_route_table.shared_private_rt.id
}

# ---------------- NAT Instance (Free-tier style) ----------------
# SG allows traffic from App VPC and allows outbound internet
resource "aws_security_group" "nat_sg" {
  name   = "nat-sg"
  vpc_id = aws_vpc.app.id

  ingress {
    description = "Allow from App VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.app.cidr_block]
  }

  egress {
    description = "Allow to Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "nat-sg" }
}

# NAT instance must do IP forwarding + masquerade
resource "aws_instance" "nat_instance" {
  ami                    = "ami-0ff5003538b60d5ec" # Amazon Linux 2 in ap-south-1 (confirm if needed)
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.app_public.id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.nat_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

              yum -y install iptables-services || true
              iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
              service iptables save || true
              systemctl enable iptables || true
              EOF

  tags = { Name = "nat-instance" }
}

# Route private subnet outbound via NAT instance
resource "aws_route" "app_private_default" {
  route_table_id         = aws_route_table.app_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id
}

# ---------------- VPC Peering (App <-> Shared) ----------------
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.app.id
  peer_vpc_id = aws_vpc.shared.id
  auto_accept = true
  tags        = { Name = "peer-app-shared" }
}

# App private -> Shared CIDR via peering
resource "aws_route" "app_to_shared" {
  route_table_id              = aws_route_table.app_private_rt.id
  destination_cidr_block      = aws_vpc.shared.cidr_block
  vpc_peering_connection_id   = aws_vpc_peering_connection.peer.id
}

# Shared private -> App CIDR via peering (THIS was wrong in your code)
resource "aws_route" "shared_to_app" {
  route_table_id              = aws_route_table.shared_private_rt.id
  destination_cidr_block      = aws_vpc.app.cidr_block
  vpc_peering_connection_id   = aws_vpc_peering_connection.peer.id
}
