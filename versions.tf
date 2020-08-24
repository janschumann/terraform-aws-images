terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
    external = {
      source = "hashicorp/external"
      version = "~> 1.0"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 1.0"
    }
  }
}
