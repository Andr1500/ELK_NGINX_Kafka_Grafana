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


provider "aws" {
  region = var.region
}

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

resource "aws_instance" "ansible_RHEL8_stack" {
  count                  = var.count_stack_instances
  ami                    = data.aws_ami.rhel8.id
  instance_type          = var.stack_instance_type #for ELK minimum is  t3.large
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  subnet_id              = element([for s in data.aws_subnet.subnet : s.id], 0)


  tags = {
    Name  = "Server_RHEL8_elkstack_${count.index + 1}"
    Owner = var.owner
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = pathexpand("~/.ssh/id_rsa")
  }
}

resource "aws_instance" "ansible_RHEL8_worker" {
  count                  = var.count_worker_instances
  ami                    = data.aws_ami.rhel8.id
  instance_type          = var.worker_instance_type
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  subnet_id              = element([for s in data.aws_subnet.subnet : s.id], 0)


  tags = {
    Name  = "Server_RHEL8_worker_${count.index + 1}"
    Owner = var.owner
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = pathexpand("~/.ssh/id_rsa")
  }
}

resource "aws_security_group" "ansible_sg" {
  name = "ansible-SG"

  dynamic "ingress" {
    for_each = ["80", "8080", "443", "22", "8200", "9200", "5601", "5044", "3000", "2181", "9092"]
    content {
      description = "Allow port HTTP"
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

#create ansible host file(locally)
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
