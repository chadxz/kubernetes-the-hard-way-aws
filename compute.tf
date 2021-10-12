data "local_file" "public_key" {
  filename = pathexpand("~/.ssh/id_rsa.pub")
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

resource "aws_network_interface" "worker_interfaces" {
  count       = local.instance_count.workers
  subnet_id   = aws_subnet.control_plane[0].id
  private_ips = [cidrhost(aws_subnet.control_plane[0].cidr_block, 20 + count.index)]
  security_groups = [
    aws_security_group.in_local.id,
    aws_security_group.out_all.id,
    aws_security_group.in_kubectl.id
  ]

  tags = {
    Name        = "${local.project_name} worker${count.index} interface"
    ForInstance = "worker-${count.index}"
  }
}

resource "aws_network_interface" "controller_interfaces" {
  count       = local.instance_count.controllers
  subnet_id   = aws_subnet.control_plane[0].id
  private_ips = [cidrhost(aws_subnet.control_plane[0].cidr_block, 10 + count.index)]
  security_groups = [
    aws_security_group.in_local.id,
    aws_security_group.out_all.id,
    aws_security_group.in_kubectl.id
  ]
  tags = {
    Name        = "${local.project_name} control${count.index} adapter"
    ForInstance = "control-${count.index}"
  }
}

resource "aws_key_pair" "ssh_key" {
  public_key = data.local_file.public_key.content
  key_name = "${local.project_name}-key"
}

resource "aws_instance" "workers" {
  for_each = { for interface in aws_network_interface.worker_interfaces : interface.tags.Name => interface }

  ami                  = local.ami_id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.k8s_instance_policy.name
  key_name = aws_key_pair.ssh_key.key_name

  network_interface {
    device_index         = 0
    network_interface_id = each.value.id
  }
  tags = {
    Name = each.value.tags.ForInstance
    Role = "worker" # used to identify these instances for certificate copy
  }
}

resource "aws_instance" "controllers" {
  for_each = { for interface in aws_network_interface.controller_interfaces : interface.tags.Name => interface }

  ami                  = local.ami_id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.k8s_instance_policy.name
  key_name = aws_key_pair.ssh_key.key_name

  network_interface {
    device_index         = 0
    network_interface_id = each.value.id
  }
  tags = {
    Name = each.value.tags.ForInstance
    Role = "controller" # used to identify these instances for certificate copy
  }
}

resource "aws_lb_target_group" "controllers-external" {
  name = "${local.project_name}-controllers-external"
  protocol = "TCP"
  port = 6443
  vpc_id = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "controllers-external" {
  for_each = { for instance in aws_instance.controllers : instance.tags.Name => instance }
  target_group_arn = aws_lb_target_group.controllers-external.arn
  target_id = each.value.id
}

resource "aws_lb" "external" {
  name = "${local.project_name}-external"
  internal = false
  load_balancer_type = "network"
  subnets = aws_subnet.aws_resources[*].id
}

resource "aws_lb_listener" "external" {
  load_balancer_arn = aws_lb.external.arn
  protocol = "TCP"
  port = 6443

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.controllers-external.arn
  }
}

resource "aws_lb_target_group" "controllers-internal" {
  name = "${local.project_name}-controllers-internal"
  protocol = "TCP"
  port = 6443
  vpc_id = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "controllers-internal" {
  for_each = { for instance in aws_instance.controllers : instance.tags.Name => instance }
  target_group_arn = aws_lb_target_group.controllers-internal.arn
  target_id = each.value.id
}

resource "aws_lb" "internal" {
  name = "${local.project_name}-internal"
  internal = true
  load_balancer_type = "network"
  subnets = aws_subnet.aws_resources[*].id
}


resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  protocol = "TCP"
  port = 6443

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.controllers-internal.arn
  }
}