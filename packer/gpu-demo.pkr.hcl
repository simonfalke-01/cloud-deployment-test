packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
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

variable "ami_name" {
  description = "Name for the AMI"
  type        = string
  default     = "gpu-demo-${legacy_isotime("2006-01-02-1504")}"
}

source "amazon-ebs" "gpu-demo" {
  ami_name      = var.ami_name
  instance_type = var.instance_type
  region        = var.aws_region

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
    volume_size           = 30
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
    Timestamp   = "${legacy_isotime("2006-01-02 15:04:05")}"
  }
}

build {
  name = "gpu-demo"
  sources = [
    "source.amazon-ebs.gpu-demo"
  ]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl wget gnupg2 software-properties-common"
    ]
  }

  # Install NVIDIA drivers and CUDA toolkit
  provisioner "shell" {
    script = "packer/scripts/install-cuda.sh"
  }

  provisioner "shell" {
    script = "packer/scripts/install-python.sh"
  }

  provisioner "shell" {
    script = "packer/scripts/install-nginx.sh"
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
