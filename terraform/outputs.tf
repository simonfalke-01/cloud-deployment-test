output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.gpu_demo.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.gpu_demo.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.gpu_demo.private_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.gpu_demo.id
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.gpu_demo.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.gpu_demo.id
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.gpu_demo.arn
}

output "auto_shutdown_function_arn" {
  description = "ARN of the auto-shutdown Lambda function"
  value       = var.enable_auto_shutdown ? aws_lambda_function.auto_shutdown[0].arn : null
}

output "ssh_command" {
  description = "SSH command to connect to the instance (if key provided)"
  value       = var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.gpu_demo.public_ip}" : "SSH key not configured"
}

output "app_url" {
  description = "Direct URL to access the application"
  value       = "http://${aws_instance.gpu_demo.public_ip}"
}

output "status_check_url" {
  description = "Health check URL"
  value       = "http://${aws_instance.gpu_demo.public_ip}/health"
}