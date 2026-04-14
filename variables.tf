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
  default     = [] # Define in terraform.tfvars
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

# DNS provider
variable "njalla_api_token" {
  description = "DNS provider API token"
  type        = string
  sensitive   = true
}

# VPS configuration
variable "vps_ipv4" {
  description = "Cloud VPS public IPv4 address"
  type        = string
  # Set this in terraform.tfvars after provisioning VPS
}

variable "vps_ipv6" {
  description = "Njalla VPS public IPv6 address"
  type        = string
  default     = "" # Optional
}

# Proton Mail configuration
variable "proton_dkim1_target" {
  description = "Proton DKIM 1 target value"
  type        = string
}

variable "proton_dkim2_target" {
  description = "Proton DKIM 2 target value"
  type        = string
}

variable "proton_dkim3_target" {
  description = "Proton DKIM 3 target value"
  type        = string
}

variable "proton_verification_token" {
  description = "Proton Mail verification token"
  type        = string
  sensitive   = true
}

# Postmark DKIM — fill in after adding the wilkesliberty.com domain in Postmark.
# Get values from Postmark > Sender Signatures > Domains > wilkesliberty.com > DNS.
variable "postmark_dkim_selector" {
  type        = string
  description = "DKIM selector hostname (e.g., '20240414._domainkey')"
  default     = ""
}

variable "postmark_dkim_value" {
  type        = string
  description = "DKIM TXT record value (k=rsa; p=...)"
  default     = ""
  sensitive   = true
}
