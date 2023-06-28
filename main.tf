resource "local_file" "lambda_function" {
  content  = <<EOF
import boto3
import os

def lambda_handler(event, context):
    ecs_client = boto3.client('ecs')
    rds_client = boto3.client('rds')

    tag_key = event['tag_key']
    tag_value = event['tag_value']
    desired_count = int(event['desired_count'])
    rds_action = event['rds_action']

    # Update ECS services
    clusters = ecs_client.list_clusters()['clusterArns']
    for cluster in clusters:
        services = ecs_client.list_services(cluster=cluster)['serviceArns']
        for service in services:
            tags = ecs_client.list_tags_for_resource(resourceArn=service)['tags']
            for tag in tags:
                if tag['key'] == tag_key and tag['value'] == tag_value:
                    ecs_client.update_service(cluster=cluster, service=service, desiredCount=desired_count)
                    print(f"Updated ECS service: {service}")
                else:
                    print(f"Skipped ECS service: {service} - Does not match tag criteria")

    # Update RDS instances
    instances = rds_client.describe_db_instances()['DBInstances']
    for instance in instances:
        tags = rds_client.list_tags_for_resource(ResourceName=instance['DBInstanceArn'])['TagList']
        for tag in tags:
            if tag['Key'] == tag_key and tag['Value'] == tag_value:
                if rds_action == 'start' and instance['DBInstanceStatus'] == 'stopped':
                    rds_client.start_db_instance(DBInstanceIdentifier=instance['DBInstanceIdentifier'])
                    print(f"Started RDS instance: {instance['DBInstanceIdentifier']}")
                elif rds_action == 'stop' and instance['DBInstanceStatus'] == 'available':
                    rds_client.stop_db_instance(DBInstanceIdentifier=instance['DBInstanceIdentifier'])
                    print(f"Stopped RDS instance: {instance['DBInstanceIdentifier']}")
                else:
                    if rds_action == 'start' and instance['DBInstanceStatus'] != 'stopped':
                        print(f"Skipped RDS instance: {instance['DBInstanceIdentifier']} - Not in 'stopped' state")
                    elif rds_action == 'stop' and instance['DBInstanceStatus'] != 'available':
                        print(f"Skipped RDS instance: {instance['DBInstanceIdentifier']} - Not in 'available' state")
                    else:
                        print(f"Skipped RDS instance: {instance['DBInstanceIdentifier']} - Invalid action")
            else:
                print(f"Skipped RDS instance: {instance['DBInstanceIdentifier']} - Does not match tag criteria")

EOF
  filename = "${path.module}/lambda_files/lambda_function.py"
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

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:ListTagsForResource",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances",
        "rds:ListTagsForResource",
        "rds:StartDBInstance",
        "rds:StopDBInstance"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_lambda_function" "lambda_function" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

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
