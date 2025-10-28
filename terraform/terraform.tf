terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "chainomi-eks-testing2023"
    key     = "dev/java-lambda/terraform.tfstate"
    region  = "us-west-1"
    encrypt = true

  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}