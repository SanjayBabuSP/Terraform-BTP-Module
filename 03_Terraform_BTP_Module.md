# Project 3: Terraform BTP Module (Plan-Only Showcase)

## What You'll Learn

- HashiCorp Terraform with the SAP BTP provider
- Writing reusable Terraform modules for BTP resources
- `terraform plan` output as documentation (no `apply` needed on trial)
- GitHub Actions that validate HCL on every push
- Infrastructure-as-Code best practices for BTP

## The Trial Trick

`terraform apply` often fails on trial due to service quota limits. But `terraform plan` works perfectly — it validates your HCL, calls the BTP API to check state, and outputs a detailed execution plan. **Committing plan outputs to your repo is a valid and respected practice.** Recruiters and engineers see that you understand what the infrastructure would do.

## Prerequisites

- Terraform CLI 1.6+
- SAP BTP Trial account
- Git
- A text editor (VS Code with HashiCorp Terraform extension is recommended)

## BTP Trial Compatibility

- **`terraform plan` is free** and works with trial accounts — it calls the BTP API in read-only mode.
- **`terraform apply` will likely fail** on trial due to resource/quota limits. This is expected and documented as the approach.
- Committing `terraform plan` output is a valid practice that demonstrates IaC competency.
- You need `BTP_USERNAME` and `BTP_PASSWORD` env vars set. Note: SAP Universal ID may cause auth issues — use your S-user or P-user ID instead of email (see SAP Note 3085908).

---

## Step 1: Install Terraform

```bash
# Mac (Homebrew)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform --version

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform --version

# Windows (Chocolatey)
choco install terraform
```

---

## Step 2: Project Structure

```bash
mkdir terraform-btp-modules
cd terraform-btp-modules

mkdir -p modules/subaccount
mkdir -p modules/entitlements
mkdir -p modules/cloud-foundry
mkdir -p modules/security
mkdir -p environments/dev
mkdir -p environments/prod
mkdir -p .github/workflows
mkdir -p plan-outputs

touch README.md
touch .gitignore
touch .terraform.lock.hcl
```

Create `.gitignore`:

```gitignore
# Terraform state — never commit state files
*.tfstate
*.tfstate.backup
.terraform/
*.tfvars
!*.tfvars.example

# Sensitive outputs
*.tfplan.binary

# OS
.DS_Store
```

---

## Step 3: Create the BTP Provider Configuration

Create `environments/dev/versions.tf`:

```hcl
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
```

---

## Step 4: Create the Subaccount Module

Create `modules/subaccount/main.tf`:

```hcl
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
```

Create `modules/subaccount/variables.tf`:

```hcl
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
```

Create `modules/subaccount/outputs.tf`:

```hcl
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
```

---

## Step 5: Create the Security Module

Create `modules/security/main.tf`:

```hcl
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
```

Create `modules/security/variables.tf`:

```hcl
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
```

---

## Step 6: Create the Dev Environment Root Module

Create `environments/dev/main.tf`:

```hcl
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
```

Create `environments/dev/variables.tf`:

```hcl
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
```

Create `environments/dev/terraform.tfvars.example`:

```hcl
global_account_subdomain = "your-global-account-subdomain"
region                   = "us10"
subdomain_prefix         = "mycompany"
admin_users              = ["admin@company.com"]
developer_users          = ["dev1@company.com", "dev2@company.com"]
```

---

## Step 7: Initialize and Plan

```bash
cd environments/dev

# Copy and fill in your tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values

# Initialize (downloads BTP provider)
terraform init

# Validate the HCL syntax
terraform validate

# Format all files consistently
terraform fmt -recursive ../../

# Plan — this is the main showcase command
# Set credentials via env vars (never commit credentials)
export BTP_USERNAME="sanjaybabusp@gmail.com"
export BTP_PASSWORD="Sanjay@2003"

terraform plan -out=plan.tfplan

# Save plan output as text (commit this to the repo)
terraform show plan.tfplan > ../../plan-outputs/dev-plan.txt
```

---

## Step 8: Commit Plan Outputs

Plan outputs are safe to commit — they contain no secrets, just resource definitions. This is what you showcase:

```bash
# Add plan output to git
git add plan-outputs/dev-plan.txt
git commit -m "feat: add dev environment terraform plan output"
```

The plan output in your repo should look like:

```
Terraform will perform the following actions:

  # module.dev_subaccount.btp_subaccount.this will be created
  + resource "btp_subaccount" "this" {
      + description = "Development environment for platform team"
      + id          = (known after apply)
      + name        = "dev-platform"
      + region      = "us10"
      + subdomain   = "mycompany-dev"
      ...
    }

  # module.dev_security.btp_subaccount_role_collection.this["Dev-Developers"] will be created
  + resource "btp_subaccount_role_collection" "this" {
      + description   = "Developer access to dev subaccount"
      + id            = (known after apply)
      + name          = "Dev-Developers"
      ...
    }

Plan: 5 to add, 0 to change, 0 to destroy.
```

---

## Step 9: GitHub Actions Validation Pipeline

Create `.github/workflows/terraform-validate.yml`:

```yaml
name: Terraform BTP Validation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    name: Validate Terraform HCL

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.6"

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: .

      - name: Init dev environment
        run: terraform init -backend=false
        working-directory: environments/dev
        env:
          TF_VAR_global_account_subdomain: "placeholder"
          TF_VAR_subdomain_prefix: "placeholder"

      - name: Terraform Validate
        run: terraform validate
        working-directory: environments/dev

      - name: tflint (module lint)
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: latest

      - name: Run tflint
        run: |
          tflint --init
          tflint --recursive
```

---

## Step 10: README for GitHub

```markdown
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
terraform plan

## Plan output

See `plan-outputs/` for committed plan outputs showing what this
configuration would provision in a real BTP global account.

## Design decisions

- Modules use `for_each` for idempotent multi-resource creation
- All inputs have validation rules to catch mistakes before apply
- Labels follow a standard convention: managed-by, environment, team
- Credentials are never committed — use env vars BTP_USERNAME / BTP_PASSWORD
```

---

## Prompt to Copy-Paste for Follow-Up Help

```
I am building a Terraform module for SAP BTP using the SAP/btp provider (~> 1.20.0).
My module structure: modules/subaccount, modules/security, modules/entitlements.
Root environment is at environments/dev/main.tf.

Issue / question: [DESCRIBE YOUR SPECIFIC PROBLEM HERE]

Current error from terraform plan or terraform validate:
[PASTE FULL ERROR OUTPUT]

Relevant HCL snippet:
[PASTE YOUR .tf FILE CONTENT]
```

---

## What This Showcases on GitHub

- Real HCL module design with variables, outputs, validation rules
- BTP-specific Terraform provider knowledge
- Professional IaC patterns (for_each, locals, module composition)
- CI validation with format check + tflint
- Committed plan outputs as living documentation

---

## 📚 Documentation & Reference Links

| Topic                                 | Link                                                                                                                        |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| SAP BTP Terraform Provider (Registry) | https://registry.terraform.io/providers/SAP/btp/latest/docs                                                                 |
| BTP Terraform Provider GitHub         | https://github.com/SAP/terraform-provider-btp                                                                               |
| Get Started with Terraform for BTP    | https://developers.sap.com/tutorials/btp-terraform-get-started.html                                                         |
| Terraform CLI Fundamentals            | https://developer.hashicorp.com/terraform/tutorials/cli                                                                     |
| BTP Terraform Provider Resources      | https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount                                            |
| BTP Auth Note (SAP Universal ID)      | https://me.sap.com/notes/3085908                                                                                            |
| tflint Terraform Linter               | https://github.com/terraform-linters/tflint                                                                                 |
| Terraform Best Practices              | https://developer.hashicorp.com/well-architected-framework/operational-excellence/operational-excellence-terraform-maturity |
| BTP Trial Accounts                    | https://help.sap.com/docs/btp/sap-business-technology-platform/trial-accounts-and-free-tier                                 |
