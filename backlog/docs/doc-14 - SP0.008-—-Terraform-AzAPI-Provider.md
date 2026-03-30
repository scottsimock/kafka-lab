---
id: doc-14
title: SP0.008 — Terraform AzAPI Provider
type: other
created_date: '2026-03-30 16:02'
---
# SP0.008 — Terraform AzAPI Provider

## Executive Summary

The AzAPI provider is a thin layer over the Azure ARM REST APIs that enables Terraform to manage any Azure resource type using any API version. Unlike the AzureRM provider — which wraps ARM APIs in opinionated abstractions and lags behind Azure releases — AzAPI exposes the raw ARM payload directly via a small set of generic resource types (`azapi_resource`, `azapi_update_resource`, `azapi_resource_action`, `azapi_data_plane_resource`). This design means AzAPI can provision preview services, new API versions, and properties that AzureRM has not yet codified, without waiting for provider updates.

The decision between AzAPI and AzureRM follows a clear hierarchy: use AzAPI for all net-new resources, for any resource where a preview API version is needed, and for any property not yet surfaced by AzureRM. Use AzureRM only when its higher-level abstractions deliver tangible value (e.g., `azurerm_linux_virtual_machine` wrapping multiple sub-resources) and no preview or missing-property constraints apply. In practice, the two providers compose cleanly: an AzureRM resource can be the `parent_id` of an AzAPI resource, and `azapi_update_resource` can patch properties on top of an AzureRM-managed resource.

The kafka-lab project uses AzAPI exclusively for all Azure resource provisioning. This choice was made to obtain full API version control, support for preview features used by Confluent Kafka infrastructure (private endpoints, customer-managed key encryption, zone-redundant deployments), and access to properties not yet available in AzureRM. It also future-proofs the codebase: as Azure releases new capabilities, the provider never becomes the bottleneck.

---

## AzAPI Resource Syntax

### `azapi_resource` — Full Lifecycle Management

`azapi_resource` is the primary resource type. It manages the complete create-read-update-delete lifecycle of any ARM resource.

```hcl
// Virtual Network provisioned directly via ARM REST API
resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "klc-vnet-kafkalab-scus"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"
  location  = "southcentralus"

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
      subnets = [
        {
          name = "klc-snet-brokers"
          properties = {
            addressPrefix                     = "10.0.1.0/24"
            privateEndpointNetworkPolicies    = "Disabled"
            privateLinkServiceNetworkPolicies = "Disabled"
          }
        }
      ]
    }
  }

  // Export properties for use in downstream resources
  response_export_values = ["properties.subnets"]

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

Key fields:

| Field | Required | Purpose |
|---|---|---|
| `type` | Yes | `{ResourceType}@{apiVersion}` |
| `name` | Yes | Resource name within parent scope |
| `parent_id` | Yes | ARM resource ID of the parent (resource group, subscription, etc.) |
| `location` | Conditional | Required for regional resources |
| `body` | Yes | ARM properties payload as HCL object |
| `response_export_values` | No | JSON paths to extract from the API response into `output` |
| `identity` | No | Managed identity configuration block |
| `tags` | No | Azure resource tags |

**Accessing exported values:**

```hcl
// Access a response_export_values field
output "vnet_subnets" {
  description = "Subnet list returned from VNet provisioning"
  value       = azapi_resource.vnet.output.properties.subnets
}
```

**Identity block syntax:**

```hcl
resource "azapi_resource" "storage" {
  type      = "Microsoft.Storage/storageAccounts@2023-01-01"
  name      = "klcstgkafkalab001"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"
  location  = "southcentralus"

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami.id]
  }

  body = {
    sku = { name = "Standard_ZRS" }
    kind = "StorageV2"
    properties = {
      minimumTlsVersion       = "TLS1_2"
      publicNetworkAccess     = "Disabled"
      allowBlobPublicAccess   = false
      supportsHttpsTrafficOnly = true
      encryption = {
        keySource = "Microsoft.Keyvault"
        keyvaultproperties = {
          keyname     = var.cmk_key_name
          keyvaulturi = var.key_vault_uri
        }
      }
    }
  }
}
```

**Retry block for transient errors:**

```hcl
resource "azapi_resource" "example" {
  type      = "Microsoft.Network/privateEndpoints@2024-05-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location

  body = { properties = { /* ... */ } }

  retry {
    interval_seconds     = 10
    randomization_factor = 0.5
    multiplier           = 2
    error_message_regex  = ["ResourceNotFound", "RetryableError"]
  }

  timeouts {
    create = "15m"
    delete = "10m"
  }
}
```

---

### `azapi_update_resource` — Partial Updates

`azapi_update_resource` patches specific properties on an existing resource without owning its full lifecycle. Use it to add properties that AzureRM does not expose, or to set properties on pre-existing resources.

```hcl
// Enable anonymous pull on a Container Registry managed elsewhere
resource "azapi_update_resource" "acr_anonymous_pull" {
  type        = "Microsoft.ContainerRegistry/registries@2023-07-01"
  resource_id = azurerm_container_registry.main.id

  body = {
    properties = {
      anonymousPullEnabled = var.is_anonymous_pull_enabled
    }
  }
}
```

```hcl
// Update DNS SOA record TTL — SOA is a pre-created child resource
resource "azapi_update_resource" "dns_soa" {
  type        = "Microsoft.Network/privateDnsZones/SOA@2020-06-01"
  resource_id = "${azapi_resource.private_dns_zone.id}/SOA/@"

  body = {
    properties = {
      soaRecord = {
        minimumTtl = 300
      }
      ttl = 3600
    }
  }
}
```

**Important constraints:**

- `azapi_update_resource` does NOT manage the resource lifecycle (no create/delete). If the underlying resource is destroyed, the update resource produces no effect.
- Suitable only for resources already managed (by AzureRM, AzAPI, or pre-existing in Azure).
- Does not support `response_export_values`.

---

### `azapi_resource_action` — One-Shot Operations

`azapi_resource_action` triggers a single ARM action without Terraform managing the resource lifecycle. Actions are ARM-level operations that exist outside CRUD (e.g., `powerOff`, `listKeys`, `regenerateKey`, `start`).

```hcl
// Regenerate a storage account key
resource "azapi_resource_action" "regenerate_storage_key" {
  type        = "Microsoft.Storage/storageAccounts@2023-01-01"
  resource_id = azapi_resource.storage.id
  action      = "regenerateKey"
  method      = "POST"

  body = {
    keyName = "key1"
  }

  response_export_values = ["keys"]
}
```

```hcl
// Shut down a virtual machine
resource "azapi_resource_action" "vm_shutdown" {
  type        = "Microsoft.Compute/virtualMachines@2024-07-01"
  resource_id = azapi_resource.vm.id
  action      = "powerOff"
  method      = "POST"
  body        = {}
}
```

```hcl
// Use as a data source (read-only action: list keys)
data "azapi_resource_action" "list_storage_keys" {
  type        = "Microsoft.Storage/storageAccounts@2023-01-01"
  resource_id = azapi_resource.storage.id
  action      = "listKeys"
  method      = "POST"
  body        = {}

  response_export_values = ["keys"]
}

output "storage_key" {
  description = "Primary storage account key"
  value       = data.azapi_resource_action.list_storage_keys.output.keys[0].value
  sensitive   = true
}
```

---

## AzAPI Data Sources

### `data.azapi_resource` — Read an Existing Resource

Reads the current state of any ARM resource. Use this when referencing resources not managed in the current Terraform workspace (e.g., a pre-existing VNet or shared Key Vault).

```hcl
// Read an existing Key Vault not managed by this module
data "azapi_resource" "key_vault" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = var.key_vault_name
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"

  response_export_values = [
    "properties.vaultUri",
    "properties.tenantId"
  ]
}

output "key_vault_uri" {
  description = "URI of the shared Key Vault"
  value       = data.azapi_resource.key_vault.output.properties.vaultUri
}
```

```hcl
// Read an existing VNet to obtain subnet IDs
data "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "klc-vnet-kafkalab-scus"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"

  response_export_values = ["properties.subnets"]
}

locals {
  broker_subnet_id = tolist([
    for s in data.azapi_resource.vnet.output.properties.subnets :
    s.id if s.name == "klc-snet-brokers"
  ])[0]
}
```

---

### `data.azapi_resource_list` — List Child Resources

Lists all resources of a given type under a parent scope. Use it to enumerate subnets, NICs, private endpoints, or any child resource collection.

```hcl
// List all subnets in a VNet
data "azapi_resource_list" "subnets" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  parent_id = azapi_resource.vnet.id

  response_export_values = ["*"]
}

output "subnet_ids" {
  description = "All subnet IDs in the VNet"
  value = [
    for subnet in data.azapi_resource_list.subnets.output.value :
    subnet.id
  ]
}
```

```hcl
// List all private endpoints in a resource group
data "azapi_resource_list" "private_endpoints" {
  type      = "Microsoft.Network/privateEndpoints@2024-05-01"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"

  response_export_values = ["value[*].name", "value[*].id"]
}
```

---

## API Version Selection Strategy

### How to Find the Correct API Version

1. **Azure REST API Specs repository** (authoritative source): <https://github.com/Azure/azure-rest-api-specs>. Browse to `specification/{provider}/{resource-type}/` and locate the `stable/` directory.

2. **Azure Resource Manager Template reference**: <https://learn.microsoft.com/en-us/azure/templates/> — each resource type page lists all supported API versions.

3. **Azure PowerShell query** (for versions available on a specific subscription):

   ```powershell
   (Get-AzResourceProvider -ProviderNamespace Microsoft.Network).ResourceTypes |
     Where-Object ResourceTypeName -eq 'virtualNetworks' |
     Select-Object -ExpandProperty ApiVersions
   ```

4. **AzAPI VS Code Extension**: provides inline auto-complete for valid API versions per resource type.

### Stable Versions for Key Resource Types (as of 2024–2025)

| Resource Type | Recommended Stable Version | Notes |
|---|---|---|
| `Microsoft.Network/virtualNetworks` | `2024-05-01` | Stable; subnets, NSG, peering |
| `Microsoft.Network/networkSecurityGroups` | `2024-05-01` | Stable |
| `Microsoft.Network/privateEndpoints` | `2024-05-01` | Stable; private endpoint NIC |
| `Microsoft.Network/privateDnsZones` | `2020-06-01` | Stable; last stable for private DNS |
| `Microsoft.Compute/virtualMachines` | `2024-07-01` | Stable; use for VM create/update |
| `Microsoft.KeyVault/vaults` | `2023-07-01` | Latest stable for vault management |
| `Microsoft.Storage/storageAccounts` | `2023-01-01` | Latest stable; CMEK, private link |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | `2023-01-31` | Stable |

### Stable vs. Preview Versions

- **Stable versions** follow the format `YYYY-MM-DD` (e.g., `2024-05-01`). Use stable versions for all production resources.
- **Preview versions** follow the format `YYYY-MM-DD-preview` (e.g., `2024-03-01-preview`). Use only when a required property or feature is not available in any stable version.
- **Version pinning policy**: Pin every `azapi_resource` to an explicit, full API version string. Never use range specifiers. When upgrading an API version, review the ARM change log for breaking changes before applying.

### Version Upgrade Process

1. Review the ARM change log at `https://learn.microsoft.com/en-us/azure/templates/{provider}/change-log/{resource-type}`.
2. Update the `type` field version string in the HCL.
3. Run `terraform plan` and inspect the diff — API version changes may force resource replacement.
4. Test in a non-production workspace before merging.

---

## Module Patterns

### Standard Module File Structure

Every module follows the four-file convention from the project Terraform instructions:

```text
modules/
└── networking/
    ├── main.tf        // resource definitions
    ├── variables.tf   // input declarations
    ├── outputs.tf     // output declarations
    └── versions.tf    // required_providers and version constraints
```

Optional files when content is substantial:

```text
    ├── locals.tf      // local value computations
    └── data.tf        // data source lookups
```

### Example: VNet Module (`modules/networking/`)

**`versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
  }
}
```

**`variables.tf`**

```hcl
variable "resource_group_id" {
  description = "Resource ID of the target resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the VNet"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "address_prefixes" {
  description = "CIDR blocks for the VNet address space"
  type        = list(string)
}

variable "subnets" {
  description = "Map of subnet name to CIDR prefix"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

**`main.tf`**

```hcl
// =====================================================
// Virtual Network
// =====================================================

resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = var.vnet_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = var.address_prefixes
      }
    }
  }

  response_export_values = ["properties.subnets"]
  tags                   = var.tags
}

// =====================================================
// Subnets
// =====================================================

resource "azapi_resource" "subnet" {
  for_each = var.subnets

  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = each.key
  parent_id = azapi_resource.vnet.id

  body = {
    properties = {
      addressPrefix                     = each.value
      privateEndpointNetworkPolicies    = "Disabled"
      privateLinkServiceNetworkPolicies = "Disabled"
    }
  }
}
```

**`outputs.tf`**

```hcl
output "vnet_id" {
  description = "Resource ID of the Virtual Network"
  value       = azapi_resource.vnet.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azapi_resource.vnet.name
}

output "subnet_ids" {
  description = "Map of subnet name to resource ID"
  value       = { for k, v in azapi_resource.subnet : k => v.id }
}
```

### Module Call Pattern

Root modules call child modules and pass required inputs:

```hcl
module "networking_scus" {
  source = "../../modules/networking"

  resource_group_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"
  location          = "southcentralus"
  vnet_name         = "klc-vnet-kafkalab-scus"
  address_prefixes  = ["10.0.0.0/16"]

  subnets = {
    "klc-snet-brokers"    = "10.0.1.0/24"
    "klc-snet-zookeeper"  = "10.0.2.0/24"
    "klc-snet-connect"    = "10.0.3.0/24"
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    sprint      = "SP1"
  }
}
```

### Resource Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Files | kebab-case | `main.tf`, `storage-account.tf` |
| Resource logical names | snake_case | `azapi_resource.vnet`, `azapi_resource.subnet` |
| Variable names | snake_case | `resource_group_id`, `address_prefixes` |
| Local values | snake_case | `local.broker_subnet_id` |
| Single instance | `"main"` | `azapi_resource.main` |
| Multiple instances | descriptive or `for_each` | `azapi_resource.subnet["klc-snet-brokers"]` |

---

## State Management

### Azure Blob Storage Backend

Terraform state for the kafka-lab project is stored in Azure Blob Storage. The storage account must be provisioned before any Terraform workspace is initialized (bootstrapped via Azure CLI or a dedicated bootstrap module).

**Backend block (`backend.tf`):**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "klc-rg-tfstate-scus"
    storage_account_name = "klcstgtfstatescus001"
    container_name       = "tfstate"
    key                  = "networking/southcentralus.tfstate"
    use_oidc             = true
    subscription_id      = "<subscription-id>"
  }
}
```

- Use a unique blob key per workspace/environment (e.g., `networking/southcentralus.tfstate`, `compute/brokers.tfstate`).
- Set `use_oidc = true` to authenticate via Workload Identity Federation — no static access keys in configuration.
- Enable soft delete and versioning on the storage container to protect against accidental state loss.

### State Locking

Azure Blob Storage implements locking via blob leases. When `terraform plan` or `terraform apply` begins, Terraform acquires an exclusive lease on the state blob. No other operation can modify state until the lease is released on completion.

**Handling a stuck lock:**

```bash
# Break a stuck lease via Azure CLI (use only when the holding process is confirmed dead)
az storage blob lease break \
  --account-name klcstgtfstatescus001 \
  --container-name tfstate \
  --blob-name networking/southcentralus.tfstate
```

### Importing Existing Resources

When bringing pre-existing Azure resources under Terraform management:

**Option 1 — `terraform import` (CLI):**

```bash
terraform import \
  'azapi_resource.vnet' \
  '/subscriptions/<sub-id>/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Network/virtualNetworks/klc-vnet-kafkalab-scus'
```

**Option 2 — `import` block (Terraform 1.5+, preferred):**

```hcl
import {
  id = "/subscriptions/<sub-id>/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Network/virtualNetworks/klc-vnet-kafkalab-scus"
  to = azapi_resource.vnet
}
```

After import, run `terraform plan` to verify no unintended changes are pending. Align the HCL `body` with what the ARM API reports for the existing resource.

**`aztfmigrate` tool** can assist migrating resources from AzureRM to AzAPI state representation when converting legacy code.

---

## CI/CD Integration

### Authentication: OIDC Workload Identity

All GitHub Actions workflows authenticate to Azure via OIDC Workload Identity Federation. No static secrets (`ARM_CLIENT_SECRET`) are stored — only `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are needed.

Required GitHub Actions permissions:

```yaml
permissions:
  id-token: write   // request OIDC token
  contents: read
  pull-requests: write  // post plan comments
```

Required Azure App Registration federated credential:

- **Issuer**: `https://token.actions.githubusercontent.com`
- **Subject**: `repo:<org>/<repo>:environment:<env>` or `repo:<org>/<repo>:ref:refs/heads/main`

### Workflow 1 — Terraform Plan on Pull Request

```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'

permissions:
  id-token: write
  contents: read
  pull-requests: write

env:
  TF_IN_AUTOMATION: true
  ARM_USE_OIDC: "true"
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

jobs:
  plan:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform/environments/production
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.6"

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -input=false -no-color -out=tfplan 2>&1 | tee plan.txt
          echo "plan_output<<EOF" >> $GITHUB_OUTPUT
          cat plan.txt >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Comment Plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const output = `### Terraform Plan
            \`\`\`
            ${{ steps.plan.outputs.plan_output }}
            \`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });
```

### Workflow 2 — Terraform Apply on Merge to Main

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

permissions:
  id-token: write
  contents: read

env:
  TF_IN_AUTOMATION: true
  ARM_USE_OIDC: "true"
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

jobs:
  apply:
    runs-on: ubuntu-latest
    environment: production  // requires manual approval if configured
    defaults:
      run:
        working-directory: terraform/environments/production
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.6"

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Apply
        run: terraform apply -input=false -auto-approve
```

### Workflow 3 — Drift Detection (Scheduled)

```yaml
name: Terraform Drift Detection

on:
  schedule:
    - cron: '0 6 * * *'  // daily at 06:00 UTC
  workflow_dispatch:

permissions:
  id-token: write
  contents: read
  issues: write

env:
  TF_IN_AUTOMATION: true
  ARM_USE_OIDC: "true"
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

jobs:
  drift:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform/environments/production
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.6"

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Plan (Detect Drift)
        id: plan
        run: |
          terraform plan -input=false -no-color -detailed-exitcode 2>&1 | tee drift.txt
          echo "exit_code=$?" >> $GITHUB_ENV
        continue-on-error: true

      - name: Open Drift Issue
        if: env.exit_code == '2'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Terraform Drift Detected',
              body: 'Infrastructure drift was detected. Review the plan output and apply changes.',
              labels: ['terraform-drift', 'infrastructure']
            });
```

`terraform plan -detailed-exitcode` exit codes:

| Code | Meaning |
|---|---|
| 0 | No changes — no drift |
| 1 | Error |
| 2 | Changes present — drift detected |

---

## Example Module Structure

Complete directory tree for a small, self-contained Kafka broker VM module:

```text
terraform/
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── kafka-broker/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── environments/
    └── production/
        ├── main.tf        // module calls
        ├── variables.tf
        ├── outputs.tf
        ├── versions.tf
        └── backend.tf     // state backend configuration
```

**`modules/kafka-broker/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
  }
}
```

**`modules/kafka-broker/variables.tf`**

```hcl
variable "resource_group_id" {
  description = "Resource ID of the target resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the broker VM"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone number (1, 2, or 3)"
  type        = number
}

variable "vm_name" {
  description = "Name of the broker Virtual Machine"
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet for the NIC"
  type        = string
}

variable "uami_id" {
  description = "Resource ID of the User Assigned Managed Identity"
  type        = string
}

variable "vm_size" {
  description = "Azure VM SKU size"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "admin_username" {
  description = "OS admin username"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for admin access"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
```

**`modules/kafka-broker/main.tf`**

```hcl
// =====================================================
// Network Interface Card
// =====================================================

resource "azapi_resource" "nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "${var.vm_name}-nic"
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    properties = {
      ipConfigurations = [
        {
          name = "internal"
          properties = {
            privateIPAllocationMethod = "Dynamic"
            subnet = { id = var.subnet_id }
          }
        }
      ]
    }
  }

  response_export_values = ["properties.ipConfigurations[0].properties.privateIPAddress"]
  tags                   = var.tags
}

// =====================================================
// Virtual Machine
// =====================================================

resource "azapi_resource" "vm" {
  type      = "Microsoft.Compute/virtualMachines@2024-07-01"
  name      = var.vm_name
  parent_id = var.resource_group_id
  location  = var.location

  identity {
    type         = "UserAssigned"
    identity_ids = [var.uami_id]
  }

  body = {
    zones = [tostring(var.availability_zone)]
    properties = {
      hardwareProfile = { vmSize = var.vm_size }
      osProfile = {
        computerName  = var.vm_name
        adminUsername = var.admin_username
        linuxConfiguration = {
          disablePasswordAuthentication = true
          ssh = {
            publicKeys = [
              {
                path    = "/home/${var.admin_username}/.ssh/authorized_keys"
                keyData = var.ssh_public_key
              }
            ]
          }
        }
      }
      storageProfile = {
        imageReference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-server-jammy"
          sku       = "22_04-lts-gen2"
          version   = "latest"
        }
        osDisk = {
          createOption            = "FromImage"
          managedDisk             = { storageAccountType = "Premium_LRS" }
          deleteOption            = "Delete"
        }
      }
      networkProfile = {
        networkInterfaces = [
          { id = azapi_resource.nic.id, properties = { primary = true } }
        ]
      }
    }
  }

  tags = var.tags

  depends_on = [azapi_resource.nic]
}
```

**`modules/kafka-broker/outputs.tf`**

```hcl
output "vm_id" {
  description = "Resource ID of the Kafka broker Virtual Machine"
  value       = azapi_resource.vm.id
}

output "vm_name" {
  description = "Name of the Kafka broker Virtual Machine"
  value       = azapi_resource.vm.name
}

output "private_ip" {
  description = "Private IP address of the broker NIC"
  value       = azapi_resource.nic.output.properties.ipConfigurations[0].properties.privateIPAddress
}

output "nic_id" {
  description = "Resource ID of the NIC attached to the broker VM"
  value       = azapi_resource.nic.id
}
```

**Calling the module in `environments/production/main.tf`:**

```hcl
module "kafka_broker_1" {
  source = "../../modules/kafka-broker"

  resource_group_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"
  location          = "southcentralus"
  availability_zone = 1
  vm_name           = "klc-vm-broker-scus-001"
  subnet_id         = module.networking_scus.subnet_ids["klc-snet-brokers"]
  uami_id           = module.uami_broker.uami_id
  vm_size           = "Standard_D8s_v5"
  admin_username    = "azureuser"
  ssh_public_key    = var.broker_ssh_public_key

  tags = {
    role        = "kafka-broker"
    environment = "production"
    managed_by  = "terraform"
  }
}
```

---

## References

| Title | URL |
|---|---|
| AzAPI Provider Overview — Microsoft Learn | <https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider> |
| AzAPI Provider — Terraform Registry | <https://registry.terraform.io/providers/azure/azapi/latest/docs> |
| AzAPI `azapi_resource` getting started — Microsoft Learn | <https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-azapi-resource> |
| AzAPI `azapi_resource_action` getting started — Microsoft Learn | <https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-azapi-resource-action> |
| AzAPI Provider GitHub Repository | <https://github.com/Azure/terraform-provider-azapi> |
| Choosing AzAPI Resource Types Guide | <https://registry.terraform.io/providers/Azure/azapi/2.8.0/docs/guides/choosing_resource_types> |
| AzAPI OIDC Authentication Guide | <https://registry.terraform.io/providers/Azure/azapi/1.15.0/docs/guides/service_principal_oidc> |
| Store Terraform state in Azure Storage — Microsoft Learn | <https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage> |
| Terraform Backend: azurerm — HashiCorp Developer | <https://developer.hashicorp.com/terraform/language/backend/azurerm> |
| Azure REST API Specs — GitHub | <https://github.com/Azure/azure-rest-api-specs> |
| Azure REST API Specs Latest Releases | <https://azure.github.io/azure-sdk/releases/latest/all/specs.html> |
| ARM change log: Microsoft.Network/virtualNetworks | <https://learn.microsoft.com/en-us/azure/templates/microsoft.network/change-log/virtualnetworks> |
| Virtual Machines REST API — Microsoft Learn | <https://learn.microsoft.com/en-us/rest/api/compute/virtual-machines/create-or-update> |
| GitHub Actions OIDC with Terraform and Azure (Azure Samples) | <https://learn.microsoft.com/en-us/samples/azure-samples/github-terraform-oidc-ci-cd/github-terraform-oidc-ci-cd/> |
| Terraform Drift Detection with GitHub Actions | <https://dev.to/rosesecurity/terraform-drift-detection-powered-by-github-actions-3akm> |
| Implementing Terraform Drift Detection with GitHub Actions | <https://terrateam.io/blog/terraform-drift-detection-github-actions> |
