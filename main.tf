terraform {
  required_version = ">= 1.0"

  required_providers {
    njalla = {
      source  = "Sighery/njalla"
      version = "0.10.0"
    }

    # Additional providers as needed for your infrastructure
    # Example providers that might be relevant:

    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 5.0"
    # }

    # digitalocean = {
    #   source  = "digitalocean/digitalocean"
    #   version = "~> 2.0"
    # }

    # cloudflare = {
    #   source  = "cloudflare/cloudflare"
    #   version = "~> 4.0"
    # }
  }
}

# Configure providers
provider "njalla" {
  api_token = var.njalla_api_token
}

# Example AWS provider configuration:
# provider "aws" {
#   region = var.aws_region
# }


# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

