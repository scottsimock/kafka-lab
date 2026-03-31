---
name: terraform-azapi
description: Provision Azure infrastructure using the Terraform AzAPI provider. Use when agents need to create, update, or manage any Azure resource via ARM REST APIs with full API version control, preflight validation, and support for preview features.
---

# Terraform AzAPI Provider

The AzAPI provider is a thin layer on top of the Azure ARM REST APIs. It manages any Azure resource type using any API version, providing immediate access to new features and preview services without waiting for provider updates. AzAPI is a first-class Terraform provider designed for use on its own or alongside AzureRM.

This skill is the single reference for all Terraform conventions in this codebase, covering both general Terraform practices and AzAPI-specific guidance. Terraform files deploy cloud resources declaratively through the HashiCorp Configuration Language (HCL).

> [!NOTE]
> These instructions target Terraform 1.6+ and include features through January 2026. For Azure deployments, use AzureRM provider 4.0+ or AzAPI for latest resource support.

## Project Structure

Organize Terraform files following a modular architecture:

```text
terraform/
├── modules/                      # Reusable modules for specific resource groupings
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── storage/
│   └── compute/
└── README.md
```

## File Organization

Every Terraform configuration follows a consistent file structure:

| File                   | Purpose                                              |
|------------------------|------------------------------------------------------|
| `main.tf`              | Primary resource definitions and module calls        |
| `variables.tf`         | Input variable declarations                          |
| `outputs.tf`           | Output value declarations                            |
| `versions.tf`          | Required providers and Terraform version constraints |
| `backend.tf`           | State backend configuration (root modules only)      |
| `locals.tf`, `data.tf` | Local values and data sources (when numerous)        |

Within each file, order content as: terraform/provider blocks, variables, locals, data sources, resources, module calls, outputs.

## Naming Conventions

File and folder names use `kebab-case` (e.g., `storage-account.tf`, `modules/web-app/`).

Resource names, variable names, local values, and output names use `snake_case` (e.g., `azurerm_storage_account.main_storage`, `resource_group_name`, `local.computed_name`).

### Resource Logical Names

Resource logical names (the label after the resource type) follow these patterns:

* Single instance of a resource type: use `"main"` (e.g., `azurerm_resource_group.main`)
* Multiple instances with distinct purposes: use descriptive names (e.g., `azurerm_storage_account.data`, `azurerm_storage_account.logs`)
* Dynamic instances: use `for_each` with descriptive keys from `each.key`

## Variables and Outputs

### Variable Declarations

Variable conventions:

* Every variable includes a `description` without trailing periods
* Boolean variables start with `should_` or `is_` (e.g., `should_enable_https`, `is_production`)
* Sensitive variables include `sensitive = true`
* Required variables omit the `default` attribute; optional variables include sensible defaults
* Use `null` for optional defaults instead of empty strings
* Avoid adding `validation` blocks unless explicitly requested

```hcl
variable "storage_account_tier" {
  description = "Performance tier for the storage account"
  type        = string
  default     = "Standard"
  sensitive   = false  // Set true for secrets
}
```

### Output Declarations

Every output includes a meaningful `description` without trailing periods. Sensitive outputs include `sensitive = true`. Conditional resources require conditional output expressions.

```hcl
output "storage_account_id" {
  description = "Resource ID of the deployed storage account"
  value       = var.should_deploy ? azurerm_storage_account.main[0].id : null
  sensitive   = true  // Set true for secrets
}
```

## Comment Style

Use `//` for single-line and `/* */` for multi-line comments. Do not use `#` for comments in this codebase.

Section headers use visual separators for organization:

```hcl
// =====================================================
// Networking Resources
// =====================================================
```

## Module Conventions

Child modules in `modules/{name}/` inherit providers and state from the calling root module.

### Module Calls

Use `count = var.condition ? 1 : 0` for conditional module deployment. Prefer `for_each` over `count` for multiple instances with stable resource addresses:

```hcl
module "workload" {
  source   = "../../modules/workload"
  for_each = var.workload_configurations

  name                = each.key
  resource_group_name = azurerm_resource_group.main.name
  configuration       = each.value
}
```

## Expression Functions

### coalesce()

Returns the first non-null and non-empty value. Prefer over ternary operators for default value selection:

```hcl
location = coalesce(var.override_location, var.primary_location, "eastus")
```

Note: `coalesce()` treats empty strings as falsy. Use ternary when empty string is a valid value.

### try()

Returns the value of an expression or a fallback when the expression fails. Prefer over ternary operators for optional attribute access:

```hcl
endpoint = try(var.network.private_endpoint.ip, null)
database_id = try(module.database[0].id, null)
subnet_id = try(each.value.subnet_id, var.default_subnet_id)
```

### Combining coalesce() and try()

Combine these functions for complex optional configuration patterns:

```hcl
// try() inside coalesce(): safe attribute access with simple fallback
nsg_name = coalesce(try(var.network_security_group.name, null), "${var.subnet_name}-nsg")

// coalesce() inside try(): computed default that might fail (Azure Verified Modules pattern)
nsg_name = try(coalesce(var.new_nsg.name, "${var.subnet_name}-nsg"), "${var.subnet_name}-nsg")
```

### When to Use Ternary Operators

Ternary operators remain appropriate for boolean conditions (`var.is_production ? "Premium" : "Standard"`), conditional counts (`count = var.enable_feature ? 1 : 0`), and complex multi-factor logic.

## Data Sources and Deferred Lookups

Use standard Terraform data source syntax for existing resource lookups (e.g., `data "azurerm_resource_group"`, `data "azurerm_client_config"`).

### Deferred Data Resources

Use `terraform_data` for values computed at apply time or CI compatibility:

```hcl
resource "terraform_data" "deployment_timestamp" {
  triggers_replace = [var.storage_account_name]
  input            = timestamp()

  provisioner "local-exec" {
    command = "az storage account show --name ${var.storage_account_name} --query id -o tsv"
  }
}
```

### AzAPI Data Sources

Use AzAPI data sources to read existing Azure resources directly via ARM:

```hcl
data "azapi_resource" "existing_vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "existing-vnet"
  parent_id = azapi_resource.rg.id
}
```

## Azure Resource Naming

Resource names follow [Azure naming conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming):

* Hyphens allowed: `${var.prefix}-{abbrev}-${var.environment}-${var.instance}`
* No hyphens: `${var.prefix}{abbrev}${var.environment}${var.instance}`
* Length restricted: `substr("${var.prefix}{abbrev}${random_id.suffix.hex}", 0, 24)`

## Provider Configuration

### Required Providers Block

Every module includes a `versions.tf` with required providers:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}
```

### AzAPI Provider Block

Configure the AzAPI provider with preflight validation enabled:

```hcl
provider "azapi" {
  enable_preflight = true
}
```

### Provider Features

Root modules configure provider features explicitly:

```hcl
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}
```

## State Management

### Backend Configuration

Root modules include explicit backend configuration:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateaccount"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
  }
}
```

### State Management Practices

State files can be stored locally or in remote backends. Do not commit state files to the repository. When using remote backends, enable state locking and protect sensitive values through backend encryption.

## Validation and Formatting

### Pre-commit Checks

Run `terraform fmt -recursive`, `terraform validate`, and `terraform plan` before commits.

### Linting Tools

Use `terraform fmt` for formatting, `terraform validate` for configuration validation, `tflint` for extended linting, and `checkov` or `tfsec` for security scanning.

## Lifecycle Management

Use lifecycle blocks for resources requiring special handling:

```hcl
resource "azurerm_storage_account" "main" {
  // ...

  lifecycle {
    prevent_destroy       = true   // Protect critical resources
    create_before_destroy = true   // Zero-downtime replacement
    ignore_changes        = [tags] // Ignore external tag changes
  }
}
```

## Documentation Requirements

Every Terraform module includes a README.md documenting module purpose, required and optional inputs, outputs, usage examples, and prerequisites.

## AzAPI Key Concepts

### Resource Types

| Resource | Purpose | When to Use |
|---|---|---|
| `azapi_resource` | Full CRUD lifecycle management | Primary resource for any Azure resource |
| `azapi_update_resource` | Patch properties on existing resources | Add properties to AzureRM-managed resources |
| `azapi_resource_action` | Perform one-off operations | VM power off, Key Vault secret add |
| `azapi_data_plane_resource` | Manage data plane resources | Synapse, Key Vault certificates |

### Usage Hierarchy

1. Start with `azapi_resource` for all new resources
2. Use `azapi_data_plane_resource` for data plane resources not supported by `azapi_resource`
3. Use `azapi_update_resource` to patch properties on existing AzureRM resources
4. Use `azapi_resource_action` for non-CRUD operations

### Resource Type Format

Azure resource types follow: `Microsoft.{Provider}/{resourceType}@{apiVersion}`

Examples:
- `Microsoft.Compute/virtualMachines@2024-11-01`
- `Microsoft.Network/virtualNetworks@2024-05-01`
- `Microsoft.Network/privateDnsZones@2024-06-01`
- `Microsoft.Web/sites@2024-04-01`

### Body Structure

The `body` attribute accepts a map matching the ARM REST API request body. Properties go inside `body.properties`. Top-level fields like `sku`, `kind`, and `zones` sit directly in `body`.

### Preflight Validation

Enable with `enable_preflight = true` on the provider block. Catches invalid configurations during `terraform plan` before any resources are created.

## AzAPI Quick Start

See [getting-started/main.tf](sample_codes/getting-started/main.tf) for a complete example deploying a resource group, VNet, and VM.

## AzAPI Common Patterns

### Basic Resource

```hcl
resource "azapi_resource" "example" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "example-vnet"
  parent_id = azapi_resource.rg.id
  location  = "southcentralus"

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
    }
  }
}
```

### Patching Existing Resources

```hcl
resource "azapi_update_resource" "enable_feature" {
  type        = "Microsoft.ContainerRegistry/registries@2023-07-01"
  resource_id = azurerm_container_registry.main.id

  body = {
    properties = {
      anonymousPullEnabled = true
    }
  }
}
```

### Resource Actions

```hcl
resource "azapi_resource_action" "vm_shutdown" {
  type        = "Microsoft.Compute/virtualMachines@2024-11-01"
  resource_id = azapi_resource.vm.id
  action      = "powerOff"
}
```

### Identity Block

```hcl
resource "azapi_resource" "example" {
  type      = "Microsoft.Compute/virtualMachines@2024-11-01"
  name      = "example-vm"
  parent_id = azapi_resource.rg.id
  location  = "southcentralus"

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami.id]
  }

  body = { ... }
}
```

## AzAPI Best Practices

- **Do**: Use the latest stable API version for each resource type
- **Do**: Enable preflight validation during development
- **Do**: Use `identity` block (not body) for managed identity configuration
- **Do**: Reference ARM template docs for correct `body` property structure
- **Avoid**: Mixing AzAPI and AzureRM for the same resource (choose one)
- **Avoid**: Hardcoding resource IDs; use references and interpolation

## API Reference Quick Lookup

Find the ARM template reference for any resource type to get the correct `body` structure:

`microsoft_docs_search(query="Microsoft.{Provider}/{resourceType} terraform azapi")`

Or navigate directly:

`microsoft_docs_fetch(url="https://learn.microsoft.com/azure/templates/microsoft.compute/2024-11-01/virtualmachines")`

## Finding API Versions

Each Azure resource type has multiple API versions. Use the ARM template reference to find available versions:

| Method | How |
|---|---|
| Microsoft Docs | `microsoft_docs_search(query="Microsoft.Compute virtualMachines terraform azapi")` |
| Azure CLI | `az provider show --namespace Microsoft.Compute --query "resourceTypes[?resourceType=='virtualMachines'].apiVersions" -o tsv` |
| VS Code Extension | Install `azapi-vscode.azapi` for IntelliSense |

## Learn More

| Topic | How to Find |
|---|---|
| Provider overview | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/developer/terraform/azapi/overview-azapi-provider")` |
| Resource reference | `microsoft_docs_search(query="azure templates {resource type} terraform")` |
| AzAPI vs AzureRM | `microsoft_docs_search(query="terraform azapi vs azurerm provider comparison")` |
| Authentication | `microsoft_docs_search(query="terraform azure authentication managed identity")` |
| Terraform Registry | `microsoft_docs_fetch(url="https://registry.terraform.io/providers/Azure/azapi/latest/docs")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
