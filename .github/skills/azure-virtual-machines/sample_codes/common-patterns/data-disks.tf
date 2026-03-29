// Managed data disk attachment for Kafka log directories

variable "data_disk_size_gb" {
  description = "Size of each data disk in GB"
  type        = number
  default     = 256
}

variable "data_disk_count" {
  description = "Number of data disks per VM"
  type        = number
  default     = 2
}

locals {
  disk_assignments = flatten([
    for vm_key, vm_config in var.vm_configs : [
      for i in range(var.data_disk_count) : {
        key     = "${vm_key}-data-${i}"
        vm_key  = vm_key
        lun     = i
        zone    = vm_config.zone
      }
    ]
  ])
  disk_map = { for d in local.disk_assignments : d.key => d }
}

resource "azapi_resource" "data_disk" {
  for_each = local.disk_map

  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = each.key
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    zones = [each.value.zone]
    sku = {
      name = "Premium_LRS"
    }
    properties = {
      creationData = {
        createOption = "Empty"
      }
      diskSizeGB = var.data_disk_size_gb
    }
  }
}
