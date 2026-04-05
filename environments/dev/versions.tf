terraform {
  required_version = ">= 1.6.0"

  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.20.0"
    }
  }
}

provider "btp" {
  globalaccount = var.global_account_subdomain
  # Credentials come from environment variables:
  # BTP_USERNAME and BTP_PASSWORD
  # OR via CLI_SERVER_URL + token
}