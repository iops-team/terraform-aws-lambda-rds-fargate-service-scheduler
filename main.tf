data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


resource "local_file" "lambda_function" {
  content  = <<EOF
import boto3
import os

def lambda_handler(event, context):
    ecs_client = boto3.client('ecs')
    rds_client = boto3.client('rds')
    
    ecs_actions = []  # To store ECS actions
    rds_actions = []  # To store RDS actions

    tag_key = event['tag_key']
    tag_value = event['tag_value']
    desired_count = int(event['desired_count'])
    rds_action = event['rds_action']

    # Collect information about ECS and RDS resources with the corresponding tags
    clusters = ecs_client.list_clusters()['clusterArns']
    for cluster in clusters:
        cluster_tags = ecs_client.list_tags_for_resource(resourceArn=cluster)['tags']
        cluster_has_tag = False
        for tag in cluster_tags:
            if tag['key'] == tag_key and tag['value'] == tag_value:
                cluster_has_tag = True
                break

        services = ecs_client.list_services(cluster=cluster)['serviceArns']
        for service in services:
            service_tags = ecs_client.list_tags_for_resource(resourceArn=service)['tags']
            for tag in service_tags:
                if tag['key'] == tag_key and tag['value'] == tag_value or cluster_has_tag:
                    ecs_actions.append({'cluster': cluster, 'service': service, 'desiredCount': desired_count})
                    break

    instances = rds_client.describe_db_instances()['DBInstances']
    for instance in instances:
        tags = rds_client.list_tags_for_resource(ResourceName=instance['DBInstanceArn'])['TagList']
        for tag in tags:
            if tag['Key'] == tag_key and tag['Value'] == tag_value:
                if rds_action == 'start' and instance['DBInstanceStatus'] == 'stopped':
                    rds_actions.append({'action': 'start', 'instanceIdentifier': instance['DBInstanceIdentifier']})
                elif rds_action == 'stop' and instance['DBInstanceStatus'] == 'available':
                    rds_actions.append({'action': 'stop', 'instanceIdentifier': instance['DBInstanceIdentifier']})
                break

    # Execute the collected ECS actions
    for action in ecs_actions:
        ecs_client.update_service(cluster=action['cluster'], service=action['service'], desiredCount=action['desiredCount'])
        print(f"Updated ECS service: {action['service']}")

    # Execute the collected RDS actions
    for action in rds_actions:
        instance_id = action['instanceIdentifier']
        if action['action'] == 'start':
            rds_client.start_db_instance(DBInstanceIdentifier=instance_id)
            print(f"Started RDS instance: {instance_id}")
        elif action['action'] == 'stop':
            rds_client.stop_db_instance(DBInstanceIdentifier=instance_id)
            print(f"Stopped RDS instance: {instance_id}")

EOF
  filename = "${path.module}/lambda_files/${var.lambda_function_name}.py"
}



data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_files"
  output_path = "${path.module}/lambda_payload.zip"

  depends_on = [local_file.lambda_function]
}



resource "aws_iam_role" "lambda_role" {
  name               = "${var.lambda_function_name}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "${var.lambda_function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_function_name}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:ListTagsForResource",
          "ecs:UpdateService"
        ],
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/*",
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:service/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource",
          "rds:StartDBInstance",
          "rds:StopDBInstance"
        ],
        Resource = "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:*"
      }
    ]
  })
}




resource "aws_lambda_function" "lambda_function" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "${var.lambda_function_name}.lambda_handler"
  timeout       = var.timeout

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.8"

  tags = var.tags

  depends_on = [local_file.lambda_function]
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  for_each = var.events

  name                = each.key
  description         = var.event_description
  schedule_expression = each.value.cron_schedule_expression

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "event_target" {
  for_each = var.events

  rule      = aws_cloudwatch_event_rule.event_rule[each.key].name
  target_id = "lambda_target"
  arn       = aws_lambda_function.lambda_function.arn

  input = jsonencode({
    "rds_action"    = each.value.rds_action,
    "tag_key"       = each.value.tag_key,
    "tag_value"     = each.value.tag_value,
    "desired_count" = each.value.desired_count
  })
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  for_each = var.events

  statement_id  = "${each.key}_AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule[each.key].arn
}
