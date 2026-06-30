terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Recommended for real usage — uncomment and point at your own backend.
  # backend "s3" {
  #   bucket         = "your-tfstate-bucket"
  #   key            = "aws-cicd-ecs/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-tflock-table"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 15 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}

module "vpc" {
  source = "../../modules/vpc"

  project_name          = var.project_name
  environment            = var.environment
  vpc_cidr               = var.vpc_cidr
  availability_zones     = var.availability_zones
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  tags                   = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  tags              = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  alb_security_group_id  = module.alb.alb_security_group_id
  blue_target_group_arn  = module.alb.blue_target_group_arn
  container_image        = "${aws_ecr_repository.app.repository_url}:initial"
  task_cpu                = var.task_cpu
  task_memory             = var.task_memory
  desired_count           = var.desired_count
  tags                    = local.common_tags
}

module "codepipeline" {
  source = "../../modules/codepipeline"

  project_name             = var.project_name
  environment              = var.environment
  branch_name              = var.branch_name
  use_codecommit           = var.use_codecommit
  ecr_repository_url       = aws_ecr_repository.app.repository_url
  task_definition_family   = module.ecs.task_definition_family
  task_cpu                 = tostring(var.task_cpu)
  task_memory              = tostring(var.task_memory)
  task_execution_role_arn  = module.ecs.task_execution_role_arn
  task_role_arn            = module.ecs.task_role_arn
  log_group_name           = module.ecs.log_group_name
  deployment_config_name   = var.deployment_config_name
  ecs_cluster_name         = module.ecs.cluster_name
  ecs_service_name         = module.ecs.service_name
  prod_listener_arn        = module.alb.prod_listener_arn
  test_listener_arn        = module.alb.test_listener_arn
  blue_target_group_name   = module.alb.blue_target_group_name
  green_target_group_name  = module.alb.green_target_group_name
  tags                     = local.common_tags
}
