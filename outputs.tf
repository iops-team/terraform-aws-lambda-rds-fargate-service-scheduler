output "lambda_functions" {
  description = "The ARN of the Lambda Functions"
  value       = aws_lambda_function.lambda_function
}

output "lambda_iam_roles" {
  description = "The ARN of the IAM roles for the Lambda Functions"
  value       = aws_iam_role.lambda_role
}

output "cloudwatch_event_rules" {
  description = "The names of the Cloudwatch Event rules"
  value       = aws_cloudwatch_event_rule.event_rule
}
