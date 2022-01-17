terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.72"
    }
  }

  required_version = ">= 1.1.3"

  backend "s3" {
    region         = "us-east-1"
    bucket         = "chad-saac02-playground-tfstate"
    key            = "kubernetes-the-hard-way-aws"
    dynamodb_table = "chad-saac02-playground-tfstate"
  }
}

provider "aws" {
  region  = "us-east-1"
}

locals {
  ami_id       = "ami-001e76b3918fba080" # Amazon Linux 2022 AMI 2022.0.20211222.0 x86_64 HVM kernel-5.10
  project_name = "k8s"
  instance_count = {
    controllers = 3
    workers     = 3
  }
  availability_zones = 3
}

output "controller_instance_ids" {
  value = [for _, instance in aws_instance.controllers : instance.id]
}
output "worker_instance_ids" {
  value = [for _, instance in aws_instance.workers : instance.id]
}
