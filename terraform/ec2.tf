# IAM Role for EC2 Instance
resource "aws_iam_role" "gpu_demo" {
  name_prefix = "gpu-demo-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM Policy for CloudWatch and auto-shutdown
resource "aws_iam_role_policy" "gpu_demo" {
  name_prefix = "gpu-demo-policy"
  role        = aws_iam_role.gpu_demo.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach CloudWatch Agent policy
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.gpu_demo.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "gpu_demo" {
  name_prefix = "gpu-demo-profile"
  role        = aws_iam_role.gpu_demo.name
  
  tags = local.common_tags
}

# Launch Template for GPU Demo Instance
resource "aws_launch_template" "gpu_demo" {
  name_prefix   = "gpu-demo-lt"
  image_id      = var.custom_ami_id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.gpu_demo.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.gpu_demo.name
  }
  
  key_name = var.key_name != "" ? var.key_name : null
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    region = var.aws_region
    enable_auto_shutdown = var.enable_auto_shutdown
    auto_shutdown_timeout = var.auto_shutdown_timeout
  }))
  
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type = "gp3"
      volume_size = 30
      iops        = 3000
      throughput  = 125
      encrypted   = true
      delete_on_termination = true
    }
  }
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "gpu-demo-instance"
      Type = "gpu-demo"
    })
  }
  
  tags = local.common_tags
}

# EC2 Instance
resource "aws_instance" "gpu_demo" {
  launch_template {
    id      = aws_launch_template.gpu_demo.id
    version = "$Latest"
  }
  
  subnet_id = aws_subnet.public.id
  
  # Ensure instance is replaced if AMI changes
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(local.common_tags, {
    Name = "gpu-demo-instance"
    Type = "gpu-demo"
  })
}

# Elastic IP for stable public IP
resource "aws_eip" "gpu_demo" {
  instance = aws_instance.gpu_demo.id
  domain   = "vpc"
  
  depends_on = [aws_internet_gateway.main]
  
  tags = merge(local.common_tags, {
    Name = "gpu-demo-eip"
  })
}
