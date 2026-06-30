variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "blue_target_group_arn" {
  type = string
}

variable "container_image" {
  type        = string
  description = "Full ECR image URI, e.g. <account>.dkr.ecr.<region>.amazonaws.com/repo:tag"
}

variable "app_version" {
  type    = string
  default = "initial"
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
