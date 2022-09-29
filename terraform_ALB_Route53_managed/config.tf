#This script is creatng necessary servers with the necessary OS (Ubuntu or CentOS)
#for Ansible work. SSH keys added during creation and we need only correct inventory file.
#
# For using ssh keys in this script we need to do:
#
# 1. Go to the necessary dir and generate keys:
# ssh-keygen -t rsa -b 2048
#
# 2. Upload the public key into AWS console -> Key Pairs:
# AWS console -> Key Pairs -> Actions -> Import key pair ->
#   ->(put the name "aws_key" and download the key) -> Import

# describe provider
provider "aws" {
  region = var.region
}

# get RHEL AMI image
data "aws_ami" "rhel8" {
  most_recent = true
  filter {
    name   = "name"
    values = ["RHEL-8*HVM-*Hourly*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  owners = ["309956199498"] # Red Hat
}

data "aws_vpc" "vpc" {
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "subnet" {
  for_each = toset(data.aws_subnets.subnets.ids)
  id       = each.value
}

#ELK stack instances
resource "aws_instance" "ansible_RHEL8_stack" {
  # for_each               = toset(data.aws_subnets.subnets.ids)
  count                  = var.count_stack_instances
  ami                    = data.aws_ami.rhel8.id
  instance_type          = var.stack_instance_type #for ELK minimum is  t2.medium
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.ansible_sg_stack.id]
  subnet_id              = element([for s in data.aws_subnet.subnet : s.id], 0)

  tags = {
    Name        = "Server_RHEL8_stack_${count.index + 1}"
    Owner       = var.owner
    Environment = "ELK_stack"
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = pathexpand("~/.ssh/id_rsa")
  }
}

# worker instances
resource "aws_instance" "ansible_RHEL8_worker" {
  # for_each               = toset(data.aws_subnets.subnets.ids)
  count                  = var.count_worker_instances
  ami                    = data.aws_ami.rhel8.id
  instance_type          = var.worker_instance_type
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.ansible_sg_worker.id]
  subnet_id              = element([for s in data.aws_subnet.subnet : s.id], 0)

  tags = {
    Name        = "Server_RHEL8_worker_${count.index + 1}"
    Owner       = var.owner
    Environment = "ELK_worker"
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = pathexpand("~/.ssh/id_rsa")
  }
}

# Security group for ELK stack instances
resource "aws_security_group" "ansible_sg_stack" {
  name = "ansible-SG-ELK-stack"

  dynamic "ingress" {
    for_each = ["80", "8080", "443", "22", "8200", "9200", "5601", "5044", "3000", "2181", "9092"]
    content {
      description = "Allow ingress traffic"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for worker instances
resource "aws_security_group" "ansible_sg_worker" {
  name = "ansible-SG-worker"

  dynamic "ingress" {
    for_each = ["22", "9092"]
    content {
      description = "Allow ingress traffic"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# create a target group
resource "aws_lb_target_group" "front" {
  name     = "app-front"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc.id
  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 10
    matcher             = 200
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# get data about already created ELKstack instances
data "aws_instances" "get_instances" {
  instance_tags = {
    Environment = "ELK_stack"
    Owner       = var.owner
  }
  instance_state_names = ["running", "stopped"]
  depends_on = [
    aws_instance.ansible_RHEL8_stack
  ]
}

# attach the target group to the aws instances
resource "aws_lb_target_group_attachment" "attach-app" {
  target_group_arn = aws_lb_target_group.front.arn
  count            = 1
  target_id        = data.aws_instances.get_instances.ids[count.index]
  port             = 80
}

# create the app LB
resource "aws_lb" "front" {
  name               = "front"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ansible_sg.id]
  subnets            = [for s in data.aws_subnet.subnet : s.id]

  tags = {
    Environment = "front"
  }
}

# get certificate data
data "aws_acm_certificate" "issued" {
  domain   = "*.${var.route53_hosted_zone_name}"
  statuses = ["ISSUED"]
}

# create a HTTPS listener
resource "aws_alb_listener" "listener_https" {
  load_balancer_arn = aws_lb.front.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.issued.arn
  default_action {
    target_group_arn = aws_lb_target_group.front.arn
    type             = "forward"
  }
}

# create a HTTP listener
resource "aws_alb_listener" "listenet_http" {
  load_balancer_arn = aws_lb.front.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    target_group_arn = aws_lb_target_group.front.arn
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# fetch data about DNS zone ID
data "aws_route53_zone" "zone" {
  name = var.route53_hosted_zone_name
}

# create Route 53 A record
resource "aws_route53_record" "a_record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "elk_stack.${var.route53_hosted_zone_name}"
  type    = "A"
  alias {
    name                   = aws_lb.front.dns_name
    zone_id                = aws_lb.front.zone_id
    evaluate_target_health = true
  }
}

# create ansible host file(locally)
resource "local_file" "public_ips" {
  filename = pathexpand("~/ELK_stack/hosts.txt")
  content  = <<-EOT
%{for ip in aws_instance.ansible_RHEL8_stack.*.public_ip~}
[elk_stack]
${ip}
%{endfor~}

[worker]
%{for ip_worker in aws_instance.ansible_RHEL8_worker.*.public_ip~}
${ip_worker}
%{endfor~}
  EOT
}
