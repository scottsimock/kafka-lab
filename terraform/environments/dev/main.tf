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
