variable "global_account_subdomain" {
  description = "Your BTP global account subdomain"
  type        = string
}

variable "region" {
  description = "BTP region to deploy resources in"
  type        = string
  default     = "us10"
}

variable "subdomain_prefix" {
  description = "Prefix for subaccount subdomains (e.g. your-company-name)"
  type        = string
}

variable "admin_users" {
  description = "List of admin user emails"
  type        = list(string)
  default     = []
}

variable "developer_users" {
  description = "List of developer user emails"
  type        = list(string)
  default     = []
}