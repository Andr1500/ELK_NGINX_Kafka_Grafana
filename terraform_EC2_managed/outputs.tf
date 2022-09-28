output "RHEL8_Linux_Server_elkstack_public_ip" {
  value = {
    for droplet in aws_instance.ansible_RHEL8_stack :
    droplet.tags.Name => droplet.public_ip
  }
}

output "RHEL8_Linux_Server_elkstack_private_ip" {
  value = {
    for droplet in aws_instance.ansible_RHEL8_stack :
    droplet.tags.Name => droplet.private_ip
  }
}

output "RHEL8_Linux_Server_worker_public_ip" {
  value = {
    for droplet in aws_instance.ansible_RHEL8_worker :
    droplet.tags.Name => droplet.public_ip
  }
}

output "RHEL8_Linux_Server_worker_private_ip" {
  value = {
    for droplet in aws_instance.ansible_RHEL8_worker :
    droplet.tags.Name => droplet.private_ip
  }
}

output "vpc_id" {
  value = data.aws_vpc.vpc.id
}

output "subnets_id_1" {
  value = element([for s in data.aws_subnet.subnet : s.id], 0)
}

output "subnets_ids" {
  value = [for s in data.aws_subnet.subnet : s.id]
}
