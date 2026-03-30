// =====================================================
// Private DNS Zone
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.Network/privateDnsZones@2020-06-01"
  name      = var.zone_name
  parent_id = var.resource_group_id
  location  = "global" // Private DNS zones are global resources
  tags      = var.tags

  body = {} // No additional properties needed for basic zone
}

// =====================================================
// VNet Links
// =====================================================

resource "azapi_resource" "vnet_link" {
  for_each = var.vnet_links

  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  name      = each.key
  parent_id = azapi_resource.main.id
  location  = "global"
  tags      = var.tags

  body = {
    properties = {
      virtualNetwork = {
        id = each.value
      }
      registrationEnabled = false
    }
  }

  depends_on = [azapi_resource.main]
}
