packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

variable "aws_region" {
  description = "The AWS region to build the AMI in"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "Instance type for building the AMI"
  type        = string
  default     = "g4dn.xlarge"
}

variable "vpc_id" {
  description = "VPC ID where Packer will launch the build instance"
  type        = string
  default     = "vpc-0ba01294b113ce3e1"
}

variable "subnet_id" {
  description = "Subnet ID where Packer will launch the build instance"
  type        = string
  default     = "subnet-0ec48ccbbea8abb74"
}

source "amazon-ebs" "gpu-demo" {
  ami_name      = "gpu-demo-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.aws_region
  vpc_id        = var.vpc_id != "" ? var.vpc_id : null
  subnet_id     = var.subnet_id != "" ? var.subnet_id : null

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"

  # Storage configuration for CUDA and ML dependencies
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  tags = {
    Name        = "GPU Demo AMI"
    Environment = "development"
    Purpose     = "CUDA ML Demo"
    CreatedBy   = "Packer"
    Timestamp   = "${local.timestamp}"
  }
}

build {
  name = "gpu-demo"
  sources = [
    "source.amazon-ebs.gpu-demo"
  ]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init and fixing time sync issues'",
      "sudo cloud-init status --wait",
      "sudo timedatectl set-ntp true",
      "sleep 10",
      "echo 'Fixing APT GPG issues by clearing cache and re-importing keys'",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo mkdir -p /var/lib/apt/lists/partial",
      "echo 'Re-importing Ubuntu GPG keys'",
      "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C",
      "echo 'Running apt-get update with retry logic'",
      "for i in 1 2 3 4 5; do sudo apt-get update && break || (echo 'apt-get update failed, retrying...' && sleep 5); done",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl wget gnupg2 software-properties-common"
    ]
  }

  # Install Python and ML dependencies first (fails faster)
  provisioner "shell" {
    script = "packer/scripts/install-python.sh"
  }

  # Install NVIDIA drivers and CUDA toolkit
  provisioner "shell" {
    script = "packer/scripts/install-cuda.sh"
  }

  provisioner "shell" {
    script = "packer/scripts/install-nginx.sh"
  }

  # Create directory for app files before upload
  provisioner "shell" {
    inline = [
      "mkdir -p /tmp/app"
    ]
  }

  provisioner "file" {
    source      = "app/"
    destination = "/tmp/app"
  }

  provisioner "shell" {
    script = "packer/scripts/setup-app.sh"
  }

  provisioner "shell" {
    script = "packer/scripts/install-cloudwatch.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c && history -w"
    ]
  }
}
