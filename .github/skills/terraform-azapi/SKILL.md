---
name: terraform-azapi
description: Provision Azure infrastructure using the Terraform AzAPI provider. Use when agents need to create, update, or manage any Azure resource via ARM REST APIs with full API version control, preflight validation, and support for preview features.
---

# Terraform AzAPI Provider

The AzAPI provider is a thin layer on top of the Azure ARM REST APIs. It manages any Azure resource type using any API version, providing immediate access to new features and preview services without waiting for provider updates. AzAPI is a first-class Terraform provider designed for use on its own or alongside AzureRM.

## Key Concepts

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

## Installation

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

provider "azapi" {
  enable_preflight = true
}
```

## Quick Start

See [getting-started/main.tf](sample_codes/getting-started/main.tf) for a complete example deploying a resource group, VNet, and VM.

## Common Patterns

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

### Data Sources

```hcl
data "azapi_resource" "existing_vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "existing-vnet"
  parent_id = azapi_resource.rg.id
}
```

## API Reference Quick Lookup

Find the ARM template reference for any resource type to get the correct `body` structure:

`microsoft_docs_search(query="Microsoft.{Provider}/{resourceType} terraform azapi")`

Or navigate directly:

`microsoft_docs_fetch(url="https://learn.microsoft.com/azure/templates/microsoft.compute/2024-11-01/virtualmachines")`

## Best Practices

- **Do**: Use the latest stable API version for each resource type
- **Do**: Enable preflight validation during development
- **Do**: Use `identity` block (not body) for managed identity configuration
- **Do**: Reference ARM template docs for correct `body` property structure
- **Do**: Use `for_each` over `count` for stable resource addresses
- **Avoid**: Mixing AzAPI and AzureRM for the same resource (choose one)
- **Avoid**: Hardcoding resource IDs; use references and interpolation

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
