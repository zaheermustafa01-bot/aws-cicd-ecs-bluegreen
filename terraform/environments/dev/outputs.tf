output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Public URL of the application (http://<this>)"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "codecommit_clone_url_http" {
  value = module.codepipeline.codecommit_clone_url_http
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "pipeline_name" {
  value = module.codepipeline.pipeline_name
}
