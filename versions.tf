terraform {
  required_version = ">= 0.12"

  required_providers {
    aws      = "~> 2.7"
    external = "~> 1.0"
    local    = "~> 1.0"
  }

  experiments = [variable_validation]
}
