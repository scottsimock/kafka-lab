// Azure Virtual Network with subnets and NSG using AzAPI provider

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

variable "location" {
  description = "Azure region for the VNet"
  type        = string
  default     = "southcentralus"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "klc-vnet-kafkalab-scus"
}

variable "address_space" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

// =====================================================
// Network Security Group
// =====================================================

resource "azapi_resource" "nsg_compute" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  name      = "${var.vnet_name}-nsg-compute"
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    properties = {
      securityRules = [
        {
          name = "AllowSSHFromVNet"
          properties = {
            priority                 = 100
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "Tcp"
            sourceAddressPrefix      = "VirtualNetwork"
            sourcePortRange          = "*"
            destinationAddressPrefix = "*"
            destinationPortRange     = "22"
          }
        },
        {
          name = "AllowKafkaBroker"
          properties = {
            priority                 = 200
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "Tcp"
            sourceAddressPrefix      = "VirtualNetwork"
            sourcePortRange          = "*"
            destinationAddressPrefix = "*"
            destinationPortRange     = "9092-9094"
          }
        },
        {
          name = "DenyAllInbound"
          properties = {
            priority                 = 4096
            direction                = "Inbound"
            access                   = "Deny"
            protocol                 = "*"
            sourceAddressPrefix      = "*"
            sourcePortRange          = "*"
            destinationAddressPrefix = "*"
            destinationPortRange     = "*"
          }
        }
      ]
    }
  }
}

// =====================================================
// Virtual Network
// =====================================================

resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = var.vnet_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = [var.address_space]
      }
      subnets = [
        {
          name = "snet-compute"
          properties = {
            addressPrefix = cidrsubnet(var.address_space, 8, 0)
            networkSecurityGroup = {
              id = azapi_resource.nsg_compute.id
            }
          }
        },
        {
          name = "snet-data"
          properties = {
            addressPrefix = cidrsubnet(var.address_space, 8, 1)
            networkSecurityGroup = {
              id = azapi_resource.nsg_compute.id
            }
          }
        },
        {
          name = "snet-management"
          properties = {
            addressPrefix = cidrsubnet(var.address_space, 8, 2)
          }
        },
        {
          name = "snet-private-endpoints"
          properties = {
            addressPrefix = cidrsubnet(var.address_space, 8, 3)
          }
        }
      ]
    }
  }
}

output "vnet_id" {
  description = "Resource ID of the virtual network"
  value       = azapi_resource.vnet.id
}

output "subnet_compute_id" {
  description = "Resource ID of the compute subnet"
  value       = "${azapi_resource.vnet.id}/subnets/snet-compute"
}

output "subnet_data_id" {
  description = "Resource ID of the data subnet"
  value       = "${azapi_resource.vnet.id}/subnets/snet-data"
}

output "subnet_private_endpoints_id" {
  description = "Resource ID of the private endpoints subnet"
  value       = "${azapi_resource.vnet.id}/subnets/snet-private-endpoints"
}
