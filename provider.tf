terraform {
  required_providers {
    njalla = {
      source  = "njal-la/njalla"
      version = "~> 1.0"
    }
  }
}

provider "njalla" {
  token = var.njalla_api_token
}

variable "njalla_api_token" {
  type      = string
  sensitive = true
}

# Proton DKIM targets (paste your exact values from Proton)
variable "proton_dkim1_target" { type = string }
variable "proton_dkim2_target" { type = string }
variable "proton_dkim3_target" { type = string }
