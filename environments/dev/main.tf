# ──────────────────────────────────────────────────────────────────
# Environment: Development
# Uses shared modules to provision a consistent dev subaccount.
# ──────────────────────────────────────────────────────────────────

module "dev_subaccount" {
  source = "../../modules/subaccount"

  name        = "dev-platform"
  subdomain   = "${var.subdomain_prefix}-dev"
  region      = var.region
  description = "Development environment for platform team"
  environment = "dev"
  team        = "platform"

  additional_labels = {
    "cost-center" = ["CC-1234"]
  }
}

module "dev_security" {
  source = "../../modules/security"

  subaccount_id = module.dev_subaccount.subaccount_id

  role_collections = [
    {
      name           = "Dev-Administrators"
      description    = "Full admin access for dev team leads"
      roles = [
        {
          name                 = "Subaccount-Administrator"
          role_template_name   = "Subaccount Administrator"
          role_template_app_id = "sap-core-development-security"
        }
      ]
      assigned_users = var.admin_users
    },
    {
      name           = "Dev-Developers"
      description    = "Developer access to dev subaccount"
      roles = [
        {
          name                 = "Developer"
          role_template_name   = "Developer"
          role_template_app_id = "sap-core-development-security"
        }
      ]
      assigned_users = var.developer_users
    }
  ]
}