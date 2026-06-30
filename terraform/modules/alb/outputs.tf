output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "blue_target_group_name" {
  value = aws_lb_target_group.blue.name
}

output "blue_target_group_arn" {
  value = aws_lb_target_group.blue.arn
}

output "green_target_group_name" {
  value = aws_lb_target_group.green.name
}

output "green_target_group_arn" {
  value = aws_lb_target_group.green.arn
}

output "prod_listener_arn" {
  value = aws_lb_listener.prod.arn
}

output "test_listener_arn" {
  value = aws_lb_listener.test.arn
}
