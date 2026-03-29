// Conditional resource creation and data source lookups

// =====================================================
// Conditional Resource (deploy only when enabled)
// =====================================================

variable "should_deploy_bastion" {
  description = "Whether to deploy Azure Bastion for VM management"
  type        = bool
  default     = false
}

resource "azapi_resource" "bastion_pip" {
  count = var.should_deploy_bastion ? 1 : 0

  type      = "Microsoft.Network/publicIPAddresses@2024-05-01"
  name      = "klc-pip-bastion-scus"
  parent_id = azapi_resource.rg.id
  location  = var.location

  body = {
    sku = {
      name = "Standard"
    }
    properties = {
      publicIPAllocationMethod = "Static"
    }
  }
}

// =====================================================
// Data Source: Read Existing Resource
// =====================================================

data "azapi_resource" "existing_rg" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = "klc-rg-kafkalab-scus"
  parent_id = "/subscriptions/${var.subscription_id}"
}

// =====================================================
// Data Source: Read Resource with Response Export
// =====================================================

data "azapi_resource" "existing_vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "klc-vnet-kafkalab-scus"
  parent_id = data.azapi_resource.existing_rg.id

  response_export_values = ["properties.addressSpace", "properties.subnets"]
}

output "existing_vnet_address_space" {
  description = "Address space of the existing VNet"
  value       = data.azapi_resource.existing_vnet.output.properties.addressSpace
}
