# ──────────────────────────────────────────────────────────────────
# Module: subaccount
# Creates a BTP subaccount with standard labeling conventions.
# ──────────────────────────────────────────────────────────────────

resource "btp_subaccount" "this" {
  name        = var.name
  subdomain   = var.subdomain
  region      = var.region
  description = var.description

  labels = merge(
    {
      "managed-by"  = ["terraform"]
      "environment" = [var.environment]
      "team"        = [var.team]
    },
    var.additional_labels
  )
}

# ── Default entitlements for every subaccount ──────────────────────
resource "btp_subaccount_entitlement" "destination" {
  subaccount_id = btp_subaccount.this.id
  service_name  = "destination"
  plan_name     = "lite"
}

resource "btp_subaccount_entitlement" "connectivity" {
  subaccount_id = btp_subaccount.this.id
  service_name  = "connectivity"
  plan_name     = "lite"
}