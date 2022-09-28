variable "region" {
  default = "eu-central-1"
}

variable "stack_instance_type" {
  type    = string
  default = "t3.large"
}

variable "worker_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "owner" {
  default = "qwerty"
}

variable "count_stack_instances" {
  default = "1"
}

variable "count_worker_instances" {
  default = "1"
}
