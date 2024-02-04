terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.32.1"
    }
  }
  backend "s3" {
    bucket         = "roboshop-jenkins-dev"
    key            = "catalogue"
    region         = "us-east-1"
    dynamodb_table = "roboshop-jenkins-dev"
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}
