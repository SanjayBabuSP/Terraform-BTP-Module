# Terraform BTP Modules

Reusable Terraform modules for SAP BTP subaccount provisioning,
security configuration, and entitlement management.

## Modules

| Module                 | Description                                |
| ---------------------- | ------------------------------------------ |
| `modules/subaccount`   | Subaccount creation with label conventions |
| `modules/security`     | Role collections and user assignments      |
| `modules/entitlements` | Service entitlement management             |

## Usage

cd environments/dev
cp terraform.tfvars.example terraform.tfvars # fill in your values
terraform init
terraform validate

Set environment variables - create .env file using .env.example as reference

export BTP_USERNAME="your-btp-username"
export BTP_PASSWORD="your-btp-password"

source .env
terraform plan

## Plan output

See `plan-outputs/` for committed plan outputs showing what this
configuration would provision in a real BTP global account.

## Design decisions

- Modules use `for_each` for idempotent multi-resource creation
- All inputs have validation rules to catch mistakes before apply
- Labels follow a standard convention: managed-by, environment, team
- Credentials are never committed — use env vars BTP_USERNAME / BTP_PASSWORD
