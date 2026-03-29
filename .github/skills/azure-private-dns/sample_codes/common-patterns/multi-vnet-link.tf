// Link a Private DNS Zone to multiple VNets across regions

variable "dns_zone_id" {
  description = "Resource ID of the Private DNS Zone"
  type        = string
}

variable "vnets" {
  description = "Map of VNets to link (key = link name, value = VNet resource ID)"
  type        = map(string)
  default = {
    "link-scus" = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/klc-vnet-kafkalab-scus"
    "link-mxc"  = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/klc-vnet-kafkalab-mxc"
    "link-cae"  = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/klc-vnet-kafkalab-cae"
  }
}

resource "azapi_resource" "vnet_link" {
  for_each = var.vnets

  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  name      = each.key
  parent_id = var.dns_zone_id
  location  = "global"

  body = {
    properties = {
      registrationEnabled = false
      virtualNetwork = {
        id = each.value
      }
    }
  }
}
