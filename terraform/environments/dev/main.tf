// =====================================================
// Provider Configuration
// =====================================================

provider "azapi" {}

// =====================================================
// Existing Resource Group Reference
// =====================================================

data "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2023-07-01"
  name      = var.resource_group_name
  parent_id = "/subscriptions/${var.subscription_id}"
}

// =====================================================
// Managed Identity
// =====================================================

module "uami_kafkalab" {
  source = "../../modules/managed-identity"

  name              = "klc-id-kafkalab-scus"
  location          = var.primary_location
  resource_group_id = data.azapi_resource.resource_group.id
  tags              = local.common_tags
}

// =====================================================
// Key Vault
// =====================================================

data "azapi_client_config" "current" {}

module "key_vault" {
  source = "../../modules/key-vault"

  name              = "klc-kv-kafkalab-scus"
  location          = var.primary_location
  resource_group_id = data.azapi_resource.resource_group.id
  tenant_id         = data.azapi_client_config.current.tenant_id
  uami_principal_id = module.uami_kafkalab.uami_principal_id
  tags              = local.common_tags
}

// =====================================================
// Virtual Network
// =====================================================

module "vnet_scus" {
  source = "../../modules/virtual-network"

  name              = "klc-vnet-scus"
  location          = var.primary_location
  resource_group_id = data.azapi_resource.resource_group.id
  address_space     = ["10.1.0.0/16"]
  tags              = local.common_tags

  subnets = {
    "snet-kafka-brokers" = {
      address_prefix = "10.1.1.0/24"
    }
    "snet-zookeeper" = {
      address_prefix = "10.1.2.0/24"
    }
    "snet-schema-registry" = {
      address_prefix = "10.1.3.0/24"
    }
    "snet-connect" = {
      address_prefix = "10.1.4.0/24"
    }
    "snet-web-app" = {
      address_prefix = "10.1.5.0/24"
    }
    "snet-private-endpoints" = {
      address_prefix                    = "10.1.6.0/24"
      private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
    }
    "snet-management" = {
      address_prefix = "10.1.7.0/24"
    }
  }
}
