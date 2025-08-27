resource "aws_cloudwatch_log_group" "gpu_demo_app" {
  name              = "gpu-demo-app"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "gpu_demo_nginx_access" {
  name              = "gpu-demo-nginx-access"
  retention_in_days = 3

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "gpu_demo_nginx_error" {
  name              = "gpu-demo-nginx-error"
  retention_in_days = 7

  tags = local.common_tags
}

# CloudWatch Alarms for Auto-Shutdown
resource "aws_cloudwatch_metric_alarm" "high_cpu_usage" {
  count = var.enable_auto_shutdown ? 1 : 0

  alarm_name          = "gpu-demo-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.gpu_demo.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "low_network_activity" {
  count = var.enable_auto_shutdown ? 1 : 0

  alarm_name          = "gpu-demo-low-network-activity"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = "600"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "Low network activity indicating potential idle state"

  dimensions = {
    InstanceId = aws_instance.gpu_demo.id
  }

  tags = local.common_tags
}

# Lambda function for auto-shutdown
resource "aws_lambda_function" "auto_shutdown" {
  count = var.enable_auto_shutdown ? 1 : 0

  filename      = data.archive_file.auto_shutdown_zip[0].output_path
  function_name = "gpu-demo-auto-shutdown"
  role          = aws_iam_role.lambda_auto_shutdown[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      INSTANCE_ID     = aws_instance.gpu_demo.id
      TIMEOUT_MINUTES = var.auto_shutdown_timeout
    }
  }

  tags = local.common_tags
}

resource "local_file" "auto_shutdown_lambda" {
  count = var.enable_auto_shutdown ? 1 : 0

  filename = "${path.module}/lambda_function.py"
  content  = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    cloudwatch = boto3.client('cloudwatch')
    logs = boto3.client('logs')

    instance_id = os.environ['INSTANCE_ID']
    timeout_minutes = int(os.environ['TIMEOUT_MINUTES'])

    try:
        # Check instance state
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance_state = response['Reservations'][0]['Instances'][0]['State']['Name']

        if instance_state != 'running':
            logger.info(f"Instance {instance_id} is not running (state: {instance_state})")
            return {
                'statusCode': 200,
                'body': json.dumps(f'Instance is not running: {instance_state}')
            }

        # Check for recent nginx access logs
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=timeout_minutes)

        try:
            log_response = logs.filter_log_events(
                logGroupName='gpu-demo-nginx-access',
                startTime=int(start_time.timestamp() * 1000),
                endTime=int(end_time.timestamp() * 1000),
                limit=1
            )

            recent_requests = len(log_response.get('events', []))

        except Exception as e:
            logger.warning(f"Could not check nginx logs: {e}")
            recent_requests = 1  # Assume activity if we can't check logs

        # Check CloudWatch metrics for network activity
        try:
            metrics_response = cloudwatch.get_metric_statistics(
                Namespace='AWS/EC2',
                MetricName='NetworkIn',
                Dimensions=[
                    {'Name': 'InstanceId', 'Value': instance_id}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )

            network_activity = sum([point['Sum'] for point in metrics_response['Datapoints']])

        except Exception as e:
            logger.warning(f"Could not check network metrics: {e}")
            network_activity = 1000  # Assume activity if we can't check metrics

        logger.info(f"Recent requests: {recent_requests}, Network activity: {network_activity} bytes")

        # Shutdown if no activity detected
        if recent_requests == 0 and network_activity < 1000:
            logger.info(f"No activity detected in the last {timeout_minutes} minutes. Stopping instance {instance_id}")

            ec2.stop_instances(InstanceIds=[instance_id])

            return {
                'statusCode': 200,
                'body': json.dumps(f'Instance {instance_id} stopped due to inactivity')
            }
        else:
            logger.info(f"Activity detected. Instance {instance_id} will continue running")
            return {
                'statusCode': 200,
                'body': json.dumps(f'Instance {instance_id} has recent activity, continuing to run')
            }

    except Exception as e:
        logger.error(f"Error in auto-shutdown function: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
EOF
}

# Create ZIP file for Lambda
data "archive_file" "auto_shutdown_zip" {
  count = var.enable_auto_shutdown ? 1 : 0

  type        = "zip"
  source_file = local_file.auto_shutdown_lambda[0].filename
  output_path = "${path.module}/auto_shutdown.zip"

  depends_on = [local_file.auto_shutdown_lambda]
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_auto_shutdown" {
  count = var.enable_auto_shutdown ? 1 : 0

  name_prefix = "gpu-demo-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_auto_shutdown" {
  count = var.enable_auto_shutdown ? 1 : 0

  name_prefix = "gpu-demo-lambda-policy"
  role        = aws_iam_role.lambda_auto_shutdown[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge Rule for Lambda trigger
resource "aws_cloudwatch_event_rule" "auto_shutdown_schedule" {
  count = var.enable_auto_shutdown ? 1 : 0

  name_prefix         = "gpu-demo-auto-shutdown"
  description         = "Trigger auto-shutdown check every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  tags = local.common_tags
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  count = var.enable_auto_shutdown ? 1 : 0

  rule      = aws_cloudwatch_event_rule.auto_shutdown_schedule[0].name
  target_id = "gpu-demo-auto-shutdown-target"
  arn       = aws_lambda_function.auto_shutdown[0].arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.enable_auto_shutdown ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_shutdown[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.auto_shutdown_schedule[0].arn
}
