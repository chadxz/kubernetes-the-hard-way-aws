resource "aws_vpc" "main" {
  cidr_block = "10.240.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = local.project_name
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

data "aws_availability_zones" "us-east-1" {
  state = "available"
}

resource "aws_subnet" "control_plane" {
  count = min(local.availability_zones, length(data.aws_availability_zones.us-east-1))
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.us-east-1.names[count.index]

  tags = {
    Name = "${local.project_name} control plane ${data.aws_availability_zones.us-east-1.names[count.index]}"
  }
}

resource "aws_subnet" "aws_resources" {
  count = min(local.availability_zones, length(data.aws_availability_zones.us-east-1))
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, 240 + count.index)
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.us-east-1.names[count.index]

  tags = {
    Name = "${local.project_name} aws resources ${data.aws_availability_zones.us-east-1.names[count.index]}"
  }
}

resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_security_group" "in_local" {
  name        = "${local.project_name} in_local"
  description = "Allow all inbound traffic from within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${local.project_name} in_local"
  }
}

resource "aws_security_group" "in_kubectl" {
  name        = "${local.project_name} in_kubectl"
  description = "Allow inbound traffic on kubectl management port 6443"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_name} in_kubectl"
  }
}

resource "aws_security_group" "out_all" {
  name        = "${local.project_name} out_all"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.main.id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_name} out_all"
  }
}
