---
id: doc-5
title: Terraform AzAPI Provider Research
type: other
created_date: '2026-03-28 18:24'
---
# Terraform AzAPI Provider Research

## Summary

The Terraform AzAPI provider (v2.x) is a thin wrapper over the Azure Resource Manager REST API that enables day-zero support for any Azure resource type and API version. For the Kafka Lab project, AzAPI is the recommended primary provider because it gives direct control over API versions, supports CMEK encryption workflows via Disk Encryption Sets, and covers all required resource types (VMs, VNets, NSGs, Route Tables, Key Vault, UAMI, Managed Disks, Proximity Placement Groups) without waiting for azurerm feature parity. Terraform state will be stored in Azure Blob Storage with the `azurerm` backend, using Entra ID authentication and state locking via blob leases.

## Key Findings

- **AzAPI v2.0+ uses native HCL for `body` blocks** — `jsonencode()` is no longer required. Properties are written as standard HCL maps, improving readability and enabling Terraform type checking.
- **API version pinning is explicit per resource** via the `type` attribute format `"Microsoft.{Provider}/{ResourceType}@{api-version}"`. This is both a strength (predictability) and a maintenance obligation (manual version bumps).
- **`response_export_values`** enables fine-grained output extraction from API responses using JMESPath, critical for wiring cross-resource dependencies (e.g., extracting a Disk Encryption Set's `principalId`).
- **`azapi_resource_id` data source** parses or constructs Azure resource IDs, enabling dynamic cross-module references without hardcoded ID strings.
- **`azapi_resource_list` data source** enumerates resources of a given type under a scope, useful for discovery-based patterns with `for_each`.
- **`azapi_update_resource`** patches properties on existing resources without full lifecycle management — useful for enabling features not yet exposed by other providers. Deleting the block does NOT revert changes.
- **`azapi_resource_action`** invokes non-CRUD operations (e.g., key rotation, VM restart) but is fire-and-forget with no state tracking.
- **`retry` block** in v2.0+ supports configurable exponential backoff with regex-based error matching, improving resilience against transient Azure API failures.
- **`identity` block** natively supports system-assigned and user-assigned managed identities on resources.
- **Preflight validation** (`enable_preflight = true` in provider config) validates configurations against Azure resource schemas before apply.
- **Provider functions** (Terraform 1.8+) enable resource ID parsing and manipulation at the provider level.
- **Azure Blob Storage backend** supports state locking via blob leases and Entra ID (Azure AD) authentication — storage account access keys are not required.

## Architecture / Design Decisions

### Decision 1: AzAPI as Primary Provider

**Chosen:** Use AzAPI as the sole infrastructure provider for all Azure resources.

**Rationale:** The Kafka Lab requires CMEK encryption, UAMI authentication, private networking, and multi-region deployment across `southcentralus`, `mexicocentral`, and `canadaeast`. AzAPI provides:

- Immediate access to the latest API versions for all resource types
- Consistent resource definition patterns (ARM-compatible `body` blocks)
- No dependency on azurerm release cadence for new features
- Direct control over API version pinning per resource

**Trade-off:** AzAPI requires deeper ARM API knowledge and offers less validation than azurerm. Mitigated by enabling preflight validation and using Azure resource reference documentation for schema guidance.

### Decision 2: API Version Pinning Strategy

**Chosen:** Pin all resources to the latest stable (GA) API version at the time of initial deployment. Review and update API versions quarterly or when new features are needed.

**Rationale:** Pinning prevents unexpected behavior from API changes. Using GA versions (not preview) ensures production stability. The explicit `type` attribute makes version auditing straightforward via grep.

**Recommended API versions for Kafka Lab resources:**

| Resource Type | AzAPI Type | Recommended API Version |
|---|---|---|
| Virtual Machine | `Microsoft.Compute/virtualMachines` | `2024-07-01` |
| Virtual Network | `Microsoft.Network/virtualNetworks` | `2024-03-01` |
| Network Security Group | `Microsoft.Network/networkSecurityGroups` | `2024-03-01` |
| Route Table | `Microsoft.Network/routeTables` | `2024-03-01` |
| Key Vault | `Microsoft.KeyVault/vaults` | `2023-07-01` |
| Key Vault Key | `Microsoft.KeyVault/vaults/keys` | `2023-07-01` |
| User Assigned Managed Identity | `Microsoft.ManagedIdentity/userAssignedIdentities` | `2023-01-31` |
| Managed Disk | `Microsoft.Compute/disks` | `2024-03-02` |
| Disk Encryption Set | `Microsoft.Compute/diskEncryptionSets` | `2024-03-02` |
| Proximity Placement Group | `Microsoft.Compute/proximityPlacementGroups` | `2024-07-01` |
| Network Interface | `Microsoft.Network/networkInterfaces` | `2024-03-01` |
| Public IP Address | `Microsoft.Network/publicIPAddresses` | `2024-03-01` |
| Private Endpoint | `Microsoft.Network/privateEndpoints` | `2024-03-01` |
| Private DNS Zone | `Microsoft.Network/privateDnsZones` | `2024-06-01` |
| Storage Account (state backend) | Provisioned outside Terraform | N/A |

### Decision 3: Terraform State Backend

**Chosen:** Azure Blob Storage with `azurerm` backend, Entra ID authentication, and blob lease-based state locking.

**Rationale:** The backend storage account is provisioned outside Terraform (via Azure CLI) to avoid circular dependency. Entra ID auth eliminates storage account key management. State locking prevents concurrent writes from CI/CD or multiple operators.

### Decision 4: Resource Group Reference Strategy

**Chosen:** Use `azapi_resource_id` data source to reference the pre-existing resource group `klc-rg-kafkalab-scus` rather than managing it via Terraform.

**Rationale:** The resource group is shared infrastructure and should not be subject to `terraform destroy`. Using a data source for the `parent_id` ensures all child resources deploy to the correct scope.

## Configuration Reference

### Provider Configuration (`versions.tf`)

```hcl
terraform {
  required_version = ">= 1.8.0"

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

### State Backend (`backend.tf`)

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "klc-rg-kafkalab-scus"
    storage_account_name = "klcstterraformscus"
    container_name       = "tfstate"
    key                  = "kafkalab.terraform.tfstate"
    use_azuread_auth     = true
  }
}
```

### Resource Group Data Source

```hcl
data "azapi_resource_id" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  parent_id = "/subscriptions/${var.subscription_id}"
  name      = "klc-rg-kafkalab-scus"
}
```

### User Assigned Managed Identity

```hcl
resource "azapi_resource" "uami_kafka" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "klc-id-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"
  body      = {}

  tags = {
    environment = "production"
    component   = "kafka"
  }
}
```

### Key Vault with CMEK Support

```hcl
resource "azapi_resource" "key_vault" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = "klc-kv-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  body = {
    properties = {
      tenantId                     = var.tenant_id
      sku                          = { family = "A", name = "premium" }
      enableRbacAuthorization      = true
      enabledForDiskEncryption     = true
      enableSoftDelete             = true
      softDeleteRetentionInDays    = 90
      enablePurgeProtection        = true
      publicNetworkAccess          = "Disabled"
      networkAcls = {
        defaultAction = "Deny"
        bypass        = "AzureServices"
      }
    }
  }

  tags = {
    environment = "production"
    component   = "kafka"
  }
}

resource "azapi_resource" "cmek_key" {
  type      = "Microsoft.KeyVault/vaults/keys@2023-07-01"
  name      = "klc-key-disk-scus"
  parent_id = azapi_resource.key_vault.id

  body = {
    properties = {
      kty     = "RSA"
      keySize = 4096
      keyOps  = ["wrapKey", "unwrapKey"]
      rotationPolicy = {
        lifetimeActions = [
          {
            action  = { type = "Rotate" }
            trigger = { timeAfterCreate = "P90D" }
          }
        ]
        attributes = {
          expiryTime = "P1Y"
        }
      }
    }
  }
}
```

### Disk Encryption Set (CMEK)

```hcl
resource "azapi_resource" "disk_encryption_set" {
  type      = "Microsoft.Compute/diskEncryptionSets@2024-03-02"
  name      = "klc-des-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami_kafka.id]
  }

  body = {
    properties = {
      activeKey = {
        keyUrl = azapi_resource.cmek_key.output.properties.keyUriWithVersion
        sourceVault = {
          id = azapi_resource.key_vault.id
        }
      }
      encryptionType                    = "EncryptionAtRestWithCustomerKey"
      rotationToLatestKeyVersionEnabled = true
    }
  }
}
```

### Virtual Network (Multi-Region Pattern)

```hcl
resource "azapi_resource" "vnet_primary" {
  type      = "Microsoft.Network/virtualNetworks@2024-03-01"
  name      = "klc-vnet-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.1.0.0/16"]
      }
      subnets = [
        {
          name = "snet-kafka-brokers"
          properties = {
            addressPrefix = "10.1.1.0/24"
            networkSecurityGroup = {
              id = azapi_resource.nsg_kafka.id
            }
            routeTable = {
              id = azapi_resource.route_table_kafka.id
            }
          }
        },
        {
          name = "snet-zookeeper"
          properties = {
            addressPrefix = "10.1.2.0/24"
            networkSecurityGroup = {
              id = azapi_resource.nsg_zookeeper.id
            }
          }
        },
        {
          name = "snet-private-endpoints"
          properties = {
            addressPrefix = "10.1.3.0/24"
          }
        }
      ]
    }
  }
}
```

### Network Security Group

```hcl
resource "azapi_resource" "nsg_kafka" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-03-01"
  name      = "klc-nsg-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  body = {
    properties = {
      securityRules = [
        {
          name = "AllowKafkaBrokerInternal"
          properties = {
            protocol                 = "Tcp"
            sourcePortRange          = "*"
            destinationPortRange     = "9092-9094"
            sourceAddressPrefix      = "10.1.0.0/16"
            destinationAddressPrefix = "10.1.1.0/24"
            access                   = "Allow"
            priority                 = 100
            direction                = "Inbound"
          }
        },
        {
          name = "AllowZookeeperClient"
          properties = {
            protocol                 = "Tcp"
            sourcePortRange          = "*"
            destinationPortRange     = "2181"
            sourceAddressPrefix      = "10.1.1.0/24"
            destinationAddressPrefix = "10.1.2.0/24"
            access                   = "Allow"
            priority                 = 200
            direction                = "Inbound"
          }
        },
        {
          name = "DenyAllInbound"
          properties = {
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "*"
            destinationAddressPrefix = "*"
            access                   = "Deny"
            priority                 = 4096
            direction                = "Inbound"
          }
        }
      ]
    }
  }
}
```

### Route Table

```hcl
resource "azapi_resource" "route_table_kafka" {
  type      = "Microsoft.Network/routeTables@2024-03-01"
  name      = "klc-rt-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  body = {
    properties = {
      disableBgpRoutePropagation = false
      routes = [
        {
          name = "route-to-secondary"
          properties = {
            addressPrefix    = "10.2.0.0/16"
            nextHopType      = "VirtualNetworkGateway"
          }
        }
      ]
    }
  }
}
```

### Proximity Placement Group

```hcl
resource "azapi_resource" "ppg_kafka_scus" {
  type      = "Microsoft.Compute/proximityPlacementGroups@2024-07-01"
  name      = "klc-ppg-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  body = {
    properties = {
      proximityPlacementGroupType = "Standard"
      intent = {
        vmSizes = ["Standard_D8ds_v5"]
      }
    }
  }
}
```

### Virtual Machine (Kafka Broker)

```hcl
resource "azapi_resource" "vm_kafka_broker" {
  type      = "Microsoft.Compute/virtualMachines@2024-07-01"
  name      = "klc-vm-kafka01-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami_kafka.id]
  }

  body = {
    properties = {
      hardwareProfile = {
        vmSize = "Standard_D8ds_v5"
      }
      proximityPlacementGroup = {
        id = azapi_resource.ppg_kafka_scus.id
      }
      osProfile = {
        computerName  = "kafka01"
        adminUsername  = "kafkaadmin"
        linuxConfiguration = {
          disablePasswordAuthentication = true
          ssh = {
            publicKeys = [
              {
                path    = "/home/kafkaadmin/.ssh/authorized_keys"
                keyData = var.ssh_public_key
              }
            ]
          }
        }
      }
      storageProfile = {
        imageReference = {
          publisher = "Canonical"
          offer     = "ubuntu-24_04-lts"
          sku       = "server"
          version   = "latest"
        }
        osDisk = {
          name         = "klc-osdisk-kafka01-scus"
          caching      = "ReadWrite"
          createOption = "FromImage"
          managedDisk = {
            storageAccountType = "Premium_LRS"
            diskEncryptionSet = {
              id = azapi_resource.disk_encryption_set.id
            }
          }
          diskSizeGB = 64
        }
      }
      networkProfile = {
        networkInterfaces = [
          { id = azapi_resource.nic_kafka_broker.id }
        ]
      }
    }
    zones = ["1"]
  }

  tags = {
    environment = "production"
    component   = "kafka-broker"
    region      = "southcentralus"
  }
}
```

### Managed Data Disk (CMEK-encrypted)

```hcl
resource "azapi_resource" "data_disk_kafka01" {
  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = "klc-datadisk-kafka01-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  body = {
    properties = {
      creationData = { createOption = "Empty" }
      diskSizeGB   = 1024
      encryption = {
        diskEncryptionSetId = azapi_resource.disk_encryption_set.id
        type                = "EncryptionAtRestWithCustomerKey"
      }
    }
    sku   = { name = "Premium_LRS" }
    zones = ["1"]
  }
}
```

### Dynamic Resource Discovery Example

```hcl
// List all VNets in the resource group
data "azapi_resource_list" "vnets" {
  type      = "Microsoft.Network/virtualNetworks@2024-03-01"
  parent_id = data.azapi_resource_id.resource_group.id
}

// Parse a resource ID into components
data "azapi_resource_id" "parsed_vault" {
  type        = "Microsoft.KeyVault/vaults@2023-07-01"
  resource_id = azapi_resource.key_vault.id
}

output "vault_name" {
  value = data.azapi_resource_id.parsed_vault.name
}
```

### Retry Configuration (Provider-Level)

```hcl
resource "azapi_resource" "example_with_retry" {
  type      = "Microsoft.Compute/virtualMachines@2024-07-01"
  name      = "example"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"

  body = { /* ... */ }

  retry {
    interval_seconds     = 5
    randomization_factor = 0.5
    multiplier           = 2
    error_message_regex  = ["ResourceNotFound", "Conflict", "RetryableError"]
  }
}
```

### Extracting Outputs with response_export_values

```hcl
resource "azapi_resource" "uami_kafka" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "klc-id-kafka-scus"
  parent_id = data.azapi_resource_id.resource_group.id
  location  = "southcentralus"
  body      = {}

  response_export_values = {
    principal_id = "properties.principalId"
    client_id    = "properties.clientId"
    tenant_id    = "properties.tenantId"
  }
}

output "uami_principal_id" {
  value = azapi_resource.uami_kafka.output.principal_id
}
```

## Risks and Open Questions

### Risks

1. **ARM API knowledge required** — AzAPI requires authors to know the Azure REST API schema for each resource. Mitigated by using the [Azure resource reference](https://learn.microsoft.com/en-us/azure/templates/) which documents every resource type and API version in Bicep/ARM format that maps directly to AzAPI `body` blocks.

2. **Weaker validation than azurerm** — AzAPI performs minimal client-side validation. Schema errors surface at `terraform apply` time, not `plan`. Mitigated by enabling `enable_preflight = true` in the provider block and running `terraform validate` in CI.

3. **API version drift** — Pinned API versions may become deprecated over time. Requires a quarterly review process to check for deprecation notices and update versions.

4. **No automatic rollback for `azapi_update_resource`** — Removing an `azapi_update_resource` block does NOT revert the change on the Azure resource. Manual cleanup is required.

5. **`azapi_resource_action` is not idempotent** — Repeated `terraform apply` may re-trigger actions (e.g., VM restart). Use sparingly and with guards.

6. **State file contains sensitive data** — The Terraform state for this project will contain UAMI client IDs, Key Vault URIs, and network configurations. The state backend storage account must enforce CMEK encryption, private endpoint access, and RBAC-only authorization.

### Open Questions

1. **Cross-region VNet peering via AzAPI** — Need to validate the exact `body` schema for `Microsoft.Network/virtualNetworks/virtualNetworkPeerings` across the three regions. The peering resource is a child resource of the VNet; confirm `parent_id` uses the VNet ID.

2. **Let's Encrypt ACME integration** — The public ingress TLS certificate automation (Application Gateway + Let's Encrypt) may require a hybrid approach with `azapi_resource_action` for DNS challenge automation. This needs further investigation in the networking research task.

3. **Terraform import for pre-existing resources** — If the resource group or storage account already exists, `terraform import` with AzAPI uses the format `terraform import azapi_resource.<name> <azure-resource-id>`. Need to confirm import works cleanly for all resource types.

4. **azapi_resource vs azurerm for the state backend storage account** — The backend storage account must be provisioned before Terraform runs, so it cannot be managed by the same Terraform configuration. Confirm whether a separate bootstrap Terraform config or Azure CLI script is preferred.

5. **Private DNS Zone linking** — Need to confirm AzAPI schema for `Microsoft.Network/privateDnsZones/virtualNetworkLinks` to link private DNS zones to VNets across all three regions.

## References

- [Overview of the Terraform AzAPI provider — Microsoft Learn](https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider)
- [AzAPI provider documentation — Terraform Registry](https://registry.terraform.io/providers/azure/azapi/latest/docs)
- [azapi_resource reference — Terraform Registry](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource)
- [AzAPI 2.0 Upgrade Guide — Terraform Registry](https://registry.terraform.io/providers/Azure/azapi/2.7.0/docs/guides/2.0-upgrade-guide)
- [Announcing AzAPI 2.0 — Microsoft Tech Community](https://techcommunity.microsoft.com/blog/azuretoolsblog/announcing-azapi-2-0/4275733)
- [AzAPI Best Practices — Matt White](https://matt-ffffff.github.io/azapi-best-practices/docs/chapter01/azapi_resource/)
- [Enhancing Azure deployments with AzureRM and AzAPI — HashiCorp Blog](https://www.hashicorp.com/en/blog/enhancing-azure-deployments-with-azurerm-and-azapi-terraform-providers)
- [Azure resource reference (Bicep/ARM/Terraform) — Microsoft Learn](https://learn.microsoft.com/en-us/azure/templates/)
- [Store Terraform state in Azure Storage — Microsoft Learn](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage)
- [Backend Type: azurerm — HashiCorp Developer](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [AzAPI Provider GitHub Repository](https://github.com/Azure/terraform-provider-azapi)
- [azapi_resource_id data source — Terraform Registry](https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/resource_id)
- [AzAPI data sources and outputs — Azure Citadel](https://www.azurecitadel.com/terraform/azapi/azapi_outputs/)
