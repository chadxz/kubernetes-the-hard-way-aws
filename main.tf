locals {
  ami_id = "ami-02e136e904f3da870" # Amazon Linux 2 in us-east-1
  project_name = "k8s"
  instance_count = {
    workers = 3
    controllers = 3
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.240.0.0/24"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = local.project_name
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k8s_instance_role" {
  name               = "K8sInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ssm_attachment" {
  role       = aws_iam_role.k8s_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k8s_instance_policy" {
  name = "K8sInstanceRole"
  role = aws_iam_role.k8s_instance_role.name
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = aws_vpc.main.cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = local.project_name
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

resource "aws_network_interface" "controller_interfaces" {
  count       = local.instance_count.controllers
  subnet_id   = aws_subnet.main.id
  private_ips = ["10.240.0.${10 + count.index}"]
  security_groups = [
    aws_security_group.in_local.id,
    aws_security_group.out_all.id,
    aws_security_group.in_kubectl.id
  ]
  tags = {
    Name        = "${local.project_name} control${count.index} adapter"
    ForInstance = "control${count.index}"
  }
}

resource "aws_instance" "controllers" {
  for_each = { for interface in aws_network_interface.controller_interfaces : interface.tags.Name => interface }

  ami                  = local.ami_id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.k8s_instance_policy.name

  network_interface {
    device_index         = 0
    network_interface_id = each.value.id
  }
  tags = {
    Name = "${local.project_name} ${each.value.tags.ForInstance}"
  }
}


resource "aws_network_interface" "worker_interfaces" {
  count       = local.instance_count.workers
  subnet_id   = aws_subnet.main.id
  private_ips = ["10.240.0.${20 + count.index}"]
  security_groups = [
    aws_security_group.in_local.id,
    aws_security_group.out_all.id,
    aws_security_group.in_kubectl.id
  ]

  tags = {
    Name        = "${local.project_name} worker${count.index} interface"
    ForInstance = "worker${count.index}"
  }
}

resource "aws_instance" "workers" {
  for_each = { for interface in aws_network_interface.worker_interfaces : interface.tags.Name => interface }

  ami                  = local.ami_id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.k8s_instance_policy.name

  network_interface {
    device_index         = 0
    network_interface_id = each.value.id
  }
  tags = {
    Name = "${local.project_name} ${each.value.tags.ForInstance}"
  }
}

output "controller_instance_ids" {
  value = [for _, instance in aws_instance.controllers : instance.id]
}
output "worker_instance_ids" {
  value = [for _, instance in aws_instance.workers : instance.id]
}