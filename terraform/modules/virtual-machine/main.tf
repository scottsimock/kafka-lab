// =====================================================
// Locals
// =====================================================

locals {
  data_disks = var.data_disk_size_gb > 0 ? [
    {
      lun          = 0
      name         = azapi_resource.data_disk[0].name
      createOption = "Attach"
      managedDisk = {
        id = azapi_resource.data_disk[0].id
      }
    }
  ] : []
}

// =====================================================
// Network Interface
// =====================================================

resource "azapi_resource" "nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "${var.name}-nic"
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      enableAcceleratedNetworking = true
      ipConfigurations = [
        {
          name = "internal"
          properties = {
            privateIPAllocationMethod = "Static"
            privateIPAddress          = var.private_ip_address
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
// Data Disk (conditional)
// =====================================================

resource "azapi_resource" "data_disk" {
  count = var.data_disk_size_gb > 0 ? 1 : 0

  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = "${var.name}-data"
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  body = {
    sku = {
      name = "Premium_LRS"
    }
    zones = [var.zone]
    properties = {
      diskSizeGB = var.data_disk_size_gb
      creationData = {
        createOption = "Empty"
      }
    }
  }
}

// =====================================================
// Virtual Machine
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.Compute/virtualMachines@2024-07-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.uami_id]
  }

  body = {
    zones = [var.zone]
    properties = {
      hardwareProfile = {
        vmSize = var.vm_size
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
      osProfile = {
        computerName  = var.name
        adminUsername = var.admin_username
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
      storageProfile = {
        imageReference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-server-jammy"
          sku       = "22_04-lts-gen2"
          version   = "latest"
        }
        osDisk = {
          createOption = "FromImage"
          diskSizeGB   = var.os_disk_size_gb
          managedDisk = {
            storageAccountType = "Premium_LRS"
          }
        }
        dataDisks = local.data_disks
      }
    }
  }
}

// =====================================================
// Private DNS A Record (conditional)
// =====================================================

resource "azapi_resource" "dns_record" {
  count = var.dns_zone_id != null ? 1 : 0

  type      = "Microsoft.Network/privateDnsZones/A@2020-06-01"
  name      = var.dns_record_name
  parent_id = var.dns_zone_id

  body = {
    properties = {
      ttl = 300
      aRecords = [
        {
          ipv4Address = var.private_ip_address
        }
      ]
    }
  }
}
