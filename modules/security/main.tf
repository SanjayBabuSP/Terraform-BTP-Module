# ──────────────────────────────────────────────────────────────────
# Module: security
# Creates role collections and assigns them to users.
# ──────────────────────────────────────────────────────────────────

resource "btp_subaccount_role_collection" "this" {
  for_each      = { for rc in var.role_collections : rc.name => rc }
  subaccount_id = var.subaccount_id
  name          = each.value.name
  description   = each.value.description

  roles = [
    for role in each.value.roles : {
      name                 = role.name
      role_template_name   = role.role_template_name
      role_template_app_id = role.role_template_app_id
    }
  ]
}

resource "btp_subaccount_role_collection_assignment" "user_assignments" {
  for_each = {
    for assignment in local.flat_assignments :
    "${assignment.role_collection}-${assignment.user}" => assignment
  }

  subaccount_id        = var.subaccount_id
  role_collection_name = each.value.role_collection
  user_name            = each.value.user

  depends_on = [btp_subaccount_role_collection.this]
}

locals {
  flat_assignments = flatten([
    for rc in var.role_collections : [
      for user in rc.assigned_users : {
        role_collection = rc.name
        user            = user
      }
    ]
  ])
}