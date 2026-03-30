// =====================================================
// Virtual Network
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  response_export_values = ["properties.subnets"]

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = var.address_space
      }
      subnets = [for subnet_name, subnet_config in var.subnets : {
        name = subnet_name
        properties = {
          addressPrefix                  = subnet_config.address_prefix
          privateEndpointNetworkPolicies = coalesce(subnet_config.private_endpoint_network_policies, "Disabled")
        }
      }]
    }
  }
}
