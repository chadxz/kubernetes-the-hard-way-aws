terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.62"
    }
  }

  required_version = ">= 1.0.8"

  backend "s3" {
    bucket         = "chad-saac02-playground-tfstate"
    key            = "kubernetes-the-hard-way-aws"
    dynamodb_table = "chad-saac02-playground-tfstate"
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

locals {
  ami_id = "ami-02e136e904f3da870" # Amazon Linux 2 in us-east-1
  project_name = "k8s"
  instance_count = {
    controllers = 3
    workers = 3
  }
  availability_zones = 3
}

output "controller_instance_ids" {
  value = [for _, instance in aws_instance.controllers : instance.id]
}
output "worker_instance_ids" {
  value = [for _, instance in aws_instance.workers : instance.id]
}
