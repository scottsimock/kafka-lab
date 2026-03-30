// =====================================================
// Private Endpoint
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.Network/privateEndpoints@2024-05-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  response_export_values = ["properties.networkInterfaces"]

  body = {
    properties = {
      subnet = {
        id = var.subnet_id
      }
      privateLinkServiceConnections = [
        {
          name = var.name
          properties = {
            privateLinkServiceId = var.target_resource_id
            groupIds             = var.group_ids
          }
        }
      ]
    }
  }
}

// =====================================================
// DNS Zone Group
// =====================================================

resource "azapi_resource" "dns_zone_group" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01"
  name      = "default"
  parent_id = azapi_resource.main.id

  body = {
    properties = {
      privateDnsZoneConfigs = [for group_name, zone_id in var.dns_zone_ids : {
        name = group_name
        properties = {
          privateDnsZoneId = zone_id
        }
      }]
    }
  }

  depends_on = [azapi_resource.main]
}
