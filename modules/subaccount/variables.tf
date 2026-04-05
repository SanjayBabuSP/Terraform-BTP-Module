variable "name" {
  description = "Display name of the subaccount"
  type        = string
  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 255
    error_message = "Subaccount name must be between 3 and 255 characters."
  }
}

variable "subdomain" {
  description = "Unique subdomain identifier (lowercase letters, numbers, hyphens)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.subdomain))
    error_message = "Subdomain must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "BTP region (e.g., us10, eu10, ap10)"
  type        = string
  default     = "us10"
}

variable "description" {
  description = "Human-readable description of the subaccount's purpose"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "team" {
  description = "Owning team label"
  type        = string
}

variable "additional_labels" {
  description = "Additional labels to merge with defaults"
  type        = map(list(string))
  default     = {}
}