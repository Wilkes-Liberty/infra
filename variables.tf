# Core project variables
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

# Network variables
variable "internal_cidr" {
  description = "Internal network CIDR block"
  type        = string
  default     = "10.10.0.0/24"
}

variable "admin_allow_cidrs" {
  description = "CIDR blocks allowed for admin access"
  type        = list(string)
  default     = []  # Define in terraform.tfvars
}

# Domain configuration
variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "wilkesliberty.com"
}

variable "internal_domain" {
  description = "Internal domain name"
  type        = string
  default     = "int.wilkesliberty.com"
}

# Provider-specific variables (uncomment and configure as needed)
# variable "aws_region" {
#   description = "AWS region"
#   type        = string
#   default     = "us-east-1"
# }

# variable "do_token" {
#   description = "DigitalOcean API token"
#   type        = string
#   sensitive   = true
# }

# variable "cloudflare_api_token" {
#   description = "Cloudflare API token"
#   type        = string
#   sensitive   = true
# }