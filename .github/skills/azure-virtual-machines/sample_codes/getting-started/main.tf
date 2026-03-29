// Azure Virtual Machine with AzAPI provider
// Deploys a Linux VM with UAMI, Trusted Launch, and Premium SSD OS disk

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
  description = "Azure region for the VM"
  type        = string
  default     = "southcentralus"
}

variable "subnet_id" {
  description = "Resource ID of the subnet for the VM NIC"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_E4as_v5"
}

variable "zone" {
  description = "Availability zone for the VM"
  type        = string
  default     = "1"
}

variable "admin_username" {
  description = "Admin username for SSH access"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for VM authentication"
  type        = string
  sensitive   = true
}

variable "user_assigned_identity_id" {
  description = "Resource ID of the User Assigned Managed Identity"
  type        = string
}

// =====================================================
// Network Interface
// =====================================================

resource "azapi_resource" "nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "${var.vm_name}-nic"
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    properties = {
      ipConfigurations = [
        {
          name = "ipconfig1"
          properties = {
            privateIPAllocationMethod = "Dynamic"
            subnet = {
              id = var.subnet_id
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
  name      = var.vm_name
  parent_id = var.resource_group_id
  location  = var.location
  tags = {
    environment = "lab"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  body = {
    zones = [var.zone]
    properties = {
      hardwareProfile = {
        vmSize = var.vm_size
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
          diskSizeGB = 64
        }
      }
      osProfile = {
        computerName  = var.vm_name
        adminUsername  = var.admin_username
        linuxConfiguration = {
          disablePasswordAuthentication = true
          ssh = {
            publicKeys = [
              {
                path    = "/home/${var.admin_username}/.ssh/authorized_keys"
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

output "vm_id" {
  description = "Resource ID of the virtual machine"
  value       = azapi_resource.vm.id
}

output "private_ip_address" {
  description = "Private IP address of the VM NIC"
  value       = azapi_resource.nic.output.properties.ipConfigurations[0].properties.privateIPAddress
}
