# Terraform Module: ECS and RDS Manager

This Terraform module creates an AWS Lambda function that manages Amazon ECS (Elastic Container Service) and RDS (Relational Database Service) resources, including RDS Aurora, based on tags and a schedule. It provides the ability to start or stop ECS services and RDS instances based on specified criteria.

## Features

- Automatic management of ECS services and RDS instances, including RDS Aurora, based on tags and schedule.
- Supports updating the entire cluster if it has a specific tag or updating individual services if the cluster does not have a tag but the service has one.
- If the cluster has a specific tag, the Lambda function can update the entire cluster, but if the cluster does not have the specified tag, the function can update individual ECS services using their respective tags.
- Supports starting and stopping of ECS services and RDS instances, including RDS Aurora.
- Customizable scheduling using cron expressions.
- Tag-based filtering to identify the resources to be managed.
- Supports configuration of tags and other settings through module inputs.

## Example Usage

```hcl
provider "aws" {
  region = "eu-west-1"
}

module "ecs_rds_manager" {
  source  = "iops-team/lambda-rds-fargate-service-scheduler/aws"

  lambda_function_name = "ecs_rds_scheduler"

  events = {
    start = {
      desired_count            = "3"
      tag_key                  = "Lambda"
      tag_value                = "True"
      cron_schedule_expression = "cron(0/15 * ? * * *)"
      rds_action               = "start"
    },
    stop = {
      desired_count            = "0"
      tag_key                  = "Lambda"
      tag_value                = "True"
      cron_schedule_expression = "cron(0/30 * ? * * *)"
      rds_action               = "stop"
    }
  }

  event_description = "Manage ECS and RDS based on tags and schedule"

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.12.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.0.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.0.0 |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.lambda_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [local_file.lambda_function](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_event_description"></a> [event\_description](#input\_event\_description) | Cloudwatch event description | `string` | `null` | no |
| <a name="input_events"></a> [events](#input\_events) | Map of event objects | <pre>map(object({<br>    desired_count            = string<br>    tag_key                  = string<br>    tag_value                = string<br>    cron_schedule_expression = string<br>    rds_action               = string<br>    timeout                  = number<br>  }))</pre> | `{}` | yes |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Lambda function timeout in seconds | `number` | `60` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_event_rules"></a> [cloudwatch\_event\_rules](#output\_cloudwatch\_event\_rules) | The names of the Cloudwatch Event rules |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | The ARN of the Lambda Functions |
| <a name="output_lambda_iam_roles"></a> [lambda\_iam\_roles](#output\_lambda\_iam\_roles) | The ARN of the IAM roles for the Lambda Functions |

## License

This Terraform module is licensed under the [MIT License](https://opensource.org/licenses/MIT).