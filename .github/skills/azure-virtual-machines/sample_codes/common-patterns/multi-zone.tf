// Multi-zone VM deployment using for_each
// Distributes VMs across availability zones for high availability

variable "vm_configs" {
  description = "Map of VM configurations with zone assignments"
  type = map(object({
    zone    = string
    vm_size = string
  }))
  default = {
    "kafka-broker-1" = { zone = "1", vm_size = "Standard_E4as_v5" }
    "kafka-broker-2" = { zone = "2", vm_size = "Standard_E4as_v5" }
    "kafka-broker-3" = { zone = "1", vm_size = "Standard_E4as_v5" }
  }
}

resource "azapi_resource" "vm_nic" {
  for_each = var.vm_configs

  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "${each.key}-nic"
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

resource "azapi_resource" "vm" {
  for_each = var.vm_configs

  type      = "Microsoft.Compute/virtualMachines@2024-11-01"
  name      = each.key
  parent_id = var.resource_group_id
  location  = var.location

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  body = {
    zones = [each.value.zone]
    properties = {
      hardwareProfile = {
        vmSize = each.value.vm_size
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
        computerName  = each.key
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
            id = azapi_resource.vm_nic[each.key].id
            properties = {
              primary = true
            }
          }
        ]
      }
    }
  }
}
