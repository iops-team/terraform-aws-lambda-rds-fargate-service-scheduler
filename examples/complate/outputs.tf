output "ecs_rds_manager_lambda_functions" {
  description = "The ARN of the Lambda Functions in the ECS RDS Manager module"
  value       = module.rds_fargate_scheduler.lambda_functions
}

output "ecs_rds_manager_lambda_iam_roles" {
  description = "The ARN of the IAM roles for the Lambda Functions in the ECS RDS Manager module"
  value       = module.rds_fargate_scheduler.lambda_iam_roles
}

output "ecs_rds_manager_cloudwatch_event_rules" {
  description = "The names of the Cloudwatch Event rules in the ECS RDS Manager module"
  value       = module.rds_fargate_scheduler.cloudwatch_event_rules
}
