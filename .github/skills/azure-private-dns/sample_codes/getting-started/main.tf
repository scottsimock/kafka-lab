// Azure Private DNS Zone with VNet link and A record using AzAPI provider

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
  }
}

variable "resource_group_id" {
  description = "Resource ID of the target resource group"
  type        = string
}

variable "zone_name" {
  description = "Private DNS zone name (e.g., privatelink.vaultcore.azure.net)"
  type        = string
  default     = "privatelink.vaultcore.azure.net"
}

variable "vnet_id" {
  description = "Resource ID of the VNet to link"
  type        = string
}

variable "vnet_name" {
  description = "Name of the VNet (used in link name)"
  type        = string
}

// =====================================================
// Private DNS Zone
// =====================================================

resource "azapi_resource" "dns_zone" {
  type      = "Microsoft.Network/privateDnsZones@2024-06-01"
  name      = var.zone_name
  parent_id = var.resource_group_id
  location  = "global"

  body = {
    properties = {}
  }
}

// =====================================================
// Virtual Network Link
// =====================================================

resource "azapi_resource" "vnet_link" {
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  name      = "link-${var.vnet_name}"
  parent_id = azapi_resource.dns_zone.id
  location  = "global"

  body = {
    properties = {
      registrationEnabled = false
      virtualNetwork = {
        id = var.vnet_id
      }
    }
  }
}

// =====================================================
// Manual A Record (when not using privateDnsZoneGroups)
// =====================================================

variable "record_name" {
  description = "DNS record name (e.g., mykeyvault)"
  type        = string
  default     = null
}

variable "record_ip" {
  description = "Private IP address for the A record"
  type        = string
  default     = null
}

resource "azapi_resource" "a_record" {
  count = var.record_name != null ? 1 : 0

  type      = "Microsoft.Network/privateDnsZones/A@2024-06-01"
  name      = var.record_name
  parent_id = azapi_resource.dns_zone.id

  body = {
    properties = {
      ttl = 300
      aRecords = [
        {
          ipv4Address = var.record_ip
        }
      ]
    }
  }
}

output "dns_zone_id" {
  description = "Resource ID of the Private DNS Zone"
  value       = azapi_resource.dns_zone.id
}
