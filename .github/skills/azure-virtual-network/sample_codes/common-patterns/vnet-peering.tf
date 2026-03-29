// VNet peering between two regions for cross-region connectivity

variable "vnet_primary_id" {
  description = "Resource ID of the primary VNet"
  type        = string
}

variable "vnet_secondary_id" {
  description = "Resource ID of the secondary VNet"
  type        = string
}

variable "vnet_primary_name" {
  description = "Name of the primary VNet"
  type        = string
}

variable "vnet_secondary_name" {
  description = "Name of the secondary VNet"
  type        = string
}

// Primary → Secondary peering
resource "azapi_resource" "peering_primary_to_secondary" {
  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01"
  name      = "${var.vnet_primary_name}-to-${var.vnet_secondary_name}"
  parent_id = var.vnet_primary_id

  body = {
    properties = {
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      useRemoteGateways         = false
      remoteVirtualNetwork = {
        id = var.vnet_secondary_id
      }
    }
  }
}

// Secondary → Primary peering (bidirectional required)
resource "azapi_resource" "peering_secondary_to_primary" {
  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01"
  name      = "${var.vnet_secondary_name}-to-${var.vnet_primary_name}"
  parent_id = var.vnet_secondary_id

  body = {
    properties = {
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      useRemoteGateways         = false
      remoteVirtualNetwork = {
        id = var.vnet_primary_id
      }
    }
  }
}
