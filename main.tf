terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.62"
    }
  }

  required_version = ">= 1.0.8"

  backend "s3" {
    bucket = "chad-saac02-playground-tfstate"
    key = "kubernetes-the-hard-way-aws"
    dynamodb_table = "chad-saac02-playground-tfstate"
  }
}

provider "aws" {
  profile = "default"
  region = "us-east-1"
}

resource "aws_instance" "control0" {
  ami = "ami-09e67e426f25ce0d7" # ubuntu 20.04
  # ami = "ami-02e136e904f3da870" # al2
  instance_type = "t2.micro"

  tags = {
    Name = var.instance_name
  }
}