terraform {
  required_version = ">= 1.0"
  
  required_providers {
    # Add providers as needed for your infrastructure
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
# Example AWS provider configuration:
# provider "aws" {
#   region = var.aws_region
# }

# Variables
variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "wilkes-liberty"
}

# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  
  # Network configuration matching your Ansible setup
  internal_network = "10.10.0.0/24"
  
  hosts = {
    app       = "10.10.0.2"
    db        = "10.10.0.3"
    search    = "10.10.0.4"
    analytics = "10.10.0.7"
    sso       = "10.10.0.8"  # Assuming based on your architecture
  }
}

# Outputs
output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "internal_network" {
  description = "Internal network CIDR"
  value       = local.internal_network
}

output "host_ips" {
  description = "Internal host IP addresses"
  value       = local.hosts
}