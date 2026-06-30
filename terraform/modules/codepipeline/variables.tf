variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "branch_name" {
  type    = string
  default = "main"
}

variable "use_codecommit" {
  type        = bool
  default     = true
  description = "If false, set external_repo_name and wire a GitHub/CodeStar connection source action instead (see docs/architecture.md)"
}

variable "external_repo_name" {
  type    = string
  default = ""
}

variable "buildspec_path" {
  type    = string
  default = "buildspecs/buildspec.yml"
}

variable "ecr_repository_url" {
  type        = string
  description = "ECR repository URL, created at root level to avoid a circular dependency with the ECS module"
}

variable "task_definition_family" {
  type        = string
  description = "ECS task definition family name (must match the family used in the ecs module)"
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "task_execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "deployment_config_name" {
  type        = string
  default     = "CodeDeployDefault.ECSLinear10PercentEvery1Minute"
  description = "Controls traffic-shift strategy: all-at-once, linear, or canary"
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "prod_listener_arn" {
  type = string
}

variable "test_listener_arn" {
  type = string
}

variable "blue_target_group_name" {
  type = string
}

variable "green_target_group_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
