// Complete AzAPI example: Resource Group, UAMI, VNet, and Linux VM
// Demonstrates the primary AzAPI patterns for Azure infrastructure

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

provider "azapi" {
  enable_preflight = true
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "southcentralus"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

locals {
  resource_group_name = "klc-rg-kafkalab-scus"
  rg_parent_id        = "/subscriptions/${var.subscription_id}"
}

// =====================================================
// Resource Group
// =====================================================

resource "azapi_resource" "rg" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = local.resource_group_name
  parent_id = local.rg_parent_id
  location  = var.location
}

// =====================================================
// User Assigned Managed Identity
// =====================================================

resource "azapi_resource" "uami" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "klc-uami-kafkalab-scus"
  parent_id = azapi_resource.rg.id
  location  = var.location
}

// =====================================================
// Virtual Network with Subnet
// =====================================================

resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "klc-vnet-kafkalab-scus"
  parent_id = azapi_resource.rg.id
  location  = var.location

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
      subnets = [
        {
          name = "snet-compute"
          properties = {
            addressPrefix = "10.0.0.0/24"
          }
        }
      ]
    }
  }
}

// =====================================================
// Network Interface
// =====================================================

resource "azapi_resource" "nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "klc-vm-kafka-01-nic"
  parent_id = azapi_resource.rg.id
  location  = var.location

  body = {
    properties = {
      ipConfigurations = [
        {
          name = "ipconfig1"
          properties = {
            privateIPAllocationMethod = "Dynamic"
            subnet = {
              id = "${azapi_resource.vnet.id}/subnets/snet-compute"
            }
          }
        }
      ]
    }
  }
}

// =====================================================
// Virtual Machine
// =====================================================

resource "azapi_resource" "vm" {
  type      = "Microsoft.Compute/virtualMachines@2024-11-01"
  name      = "klc-vm-kafka-01"
  parent_id = azapi_resource.rg.id
  location  = var.location

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami.id]
  }

  body = {
    zones = ["1"]
    properties = {
      hardwareProfile = {
        vmSize = "Standard_E4as_v5"
      }
      securityProfile = {
        securityType = "TrustedLaunch"
        uefiSettings = {
          secureBootEnabled = true
          vTpmEnabled       = true
        }
      }
      storageProfile = {
        imageReference = {
          publisher = "Canonical"
          offer     = "ubuntu-24_04-lts"
          sku       = "server"
          version   = "latest"
        }
        osDisk = {
          createOption = "FromImage"
          managedDisk = {
            storageAccountType = "Premium_LRS"
          }
        }
      }
      osProfile = {
        computerName  = "klc-vm-kafka-01"
        adminUsername  = "azureuser"
        linuxConfiguration = {
          disablePasswordAuthentication = true
          ssh = {
            publicKeys = [
              {
                path    = "/home/azureuser/.ssh/authorized_keys"
                keyData = var.ssh_public_key
              }
            ]
          }
        }
      }
      networkProfile = {
        networkInterfaces = [
          {
            id = azapi_resource.nic.id
            properties = {
              primary = true
            }
          }
        ]
      }
    }
  }
}

// =====================================================
// Outputs
// =====================================================

output "resource_group_id" {
  description = "Resource group ID"
  value       = azapi_resource.rg.id
}

output "vm_id" {
  description = "Virtual machine resource ID"
  value       = azapi_resource.vm.id
}

output "uami_id" {
  description = "User Assigned Managed Identity resource ID"
  value       = azapi_resource.uami.id
}
