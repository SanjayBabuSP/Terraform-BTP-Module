variable "subaccount_id" {
  description = "The GUID of the subaccount to configure security for"
  type        = string
}

variable "role_collections" {
  description = "List of role collections to create and assign"
  type = list(object({
    name           = string
    description    = string
    roles = list(object({
      name                 = string
      role_template_name   = string
      role_template_app_id = string
    }))
    assigned_users = list(string)
  }))
  default = []
}