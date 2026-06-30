output "pipeline_name" {
  value = aws_codepipeline.main.name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.app.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.app.deployment_group_name
}

output "codecommit_clone_url_http" {
  value = var.use_codecommit ? aws_codecommit_repository.source[0].clone_url_http : null
}
