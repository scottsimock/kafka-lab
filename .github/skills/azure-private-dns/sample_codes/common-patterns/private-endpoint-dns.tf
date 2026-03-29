// Automatic DNS registration for Private Endpoints using privateDnsZoneGroups

variable "private_endpoint_name" {
  description = "Name of the private endpoint"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the target resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the private endpoint"
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet for the private endpoint"
  type        = string
}

variable "target_resource_id" {
  description = "Resource ID of the service to connect to (e.g., Key Vault, Storage Account)"
  type        = string
}

variable "group_id" {
  description = "Sub-resource group ID (e.g., vault, blob, namespace)"
  type        = string
}

variable "private_dns_zone_id" {
  description = "Resource ID of the Private DNS Zone"
  type        = string
}

// =====================================================
// Private Endpoint
// =====================================================

resource "azapi_resource" "private_endpoint" {
  type      = "Microsoft.Network/privateEndpoints@2024-05-01"
  name      = var.private_endpoint_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    properties = {
      subnet = {
        id = var.subnet_id
      }
      privateLinkServiceConnections = [
        {
          name = "${var.private_endpoint_name}-connection"
          properties = {
            privateLinkServiceId = var.target_resource_id
            groupIds             = [var.group_id]
          }
        }
      ]
    }
  }
}

// =====================================================
// DNS Zone Group (auto-registers A record)
// =====================================================

resource "azapi_resource" "dns_zone_group" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01"
  name      = "default"
  parent_id = azapi_resource.private_endpoint.id

  body = {
    properties = {
      privateDnsZoneConfigs = [
        {
          name = "config1"
          properties = {
            privateDnsZoneId = var.private_dns_zone_id
          }
        }
      ]
    }
  }
}
