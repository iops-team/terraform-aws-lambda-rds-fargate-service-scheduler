provider "aws" {
  region = "eu-west-1"
}

module "rds_fargate_scheduler" {
  source = "../../"

  lambda_function_name = "ecs_rds_scheduler"
  timeout              = 90

  events = {
    start = {
      desired_count            = 3
      tag_key                  = "Lambda"
      tag_value                = "On"
      cron_schedule_expression = "cron(0/2 * ? * * *)"
      rds_action               = "start"
    },
    stop = {
      desired_count            = 0
      tag_key                  = "Lambda"
      tag_value                = "Off"
      cron_schedule_expression = "cron(0/15 * ? * * *)"
      rds_action               = "stop"
    }
  }

  event_description = "Manage ECS and RDS based on tags and schedule"

  tags = {
    Environment = "Production"
    Terraform   = "True"
  }
}
