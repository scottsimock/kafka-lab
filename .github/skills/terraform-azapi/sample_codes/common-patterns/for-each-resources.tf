// Dynamic resource creation with for_each
// Demonstrates creating multiple resources from a map variable

variable "kafka_brokers" {
  description = "Kafka broker configurations"
  type = map(object({
    zone    = string
    vm_size = string
  }))
  default = {
    "klc-vm-kafka-01" = { zone = "1", vm_size = "Standard_E4as_v5" }
    "klc-vm-kafka-02" = { zone = "2", vm_size = "Standard_E4as_v5" }
    "klc-vm-kafka-03" = { zone = "1", vm_size = "Standard_E4as_v5" }
  }
}

resource "azapi_resource" "broker_nic" {
  for_each = var.kafka_brokers

  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "${each.key}-nic"
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

resource "azapi_resource" "broker_vm" {
  for_each = var.kafka_brokers

  type      = "Microsoft.Compute/virtualMachines@2024-11-01"
  name      = each.key
  parent_id = azapi_resource.rg.id
  location  = var.location

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami.id]
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
            id = azapi_resource.broker_nic[each.key].id
            properties = {
              primary = true
            }
          }
        ]
      }
    }
  }
}
