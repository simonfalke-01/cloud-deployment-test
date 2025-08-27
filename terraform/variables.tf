variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "custom_ami_id" {
  description = "Custom AMI ID built by Packer"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for GPU workloads"
  type        = string
  default     = "g4dn.xlarge"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access (optional)"
  type        = string
  default     = ""
}

variable "auto_shutdown_timeout" {
  description = "Auto shutdown timeout in minutes"
  type        = number
  default     = 30
}

variable "enable_auto_shutdown" {
  description = "Enable automatic shutdown based on inactivity"
  type        = bool
  default     = true
}