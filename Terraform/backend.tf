terraform {
  required_version = ">= 1.9"

  backend "s3" {
    bucket       = "lacrei-desafio-terraform-state"
    key          = "lacrei-desafio/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
