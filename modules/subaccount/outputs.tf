output "subaccount_id" {
  description = "The GUID of the created subaccount"
  value       = btp_subaccount.this.id
}

output "subaccount_name" {
  description = "The display name of the subaccount"
  value       = btp_subaccount.this.name
}

output "subaccount_subdomain" {
  description = "The subdomain of the created subaccount"
  value       = btp_subaccount.this.subdomain
}