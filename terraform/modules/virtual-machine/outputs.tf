// =====================================================
// Outputs
// =====================================================

output "vm_id" {
  description = "Resource ID of the virtual machine"
  value       = azapi_resource.main.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azapi_resource.main.name
}

output "private_ip_address" {
  description = "Static private IP address of the NIC"
  value       = var.private_ip_address
}

output "nic_id" {
  description = "Resource ID of the network interface"
  value       = azapi_resource.nic.id
}

output "data_disk_id" {
  description = "Resource ID of the data disk, or null when no data disk"
  value       = var.data_disk_size_gb > 0 ? azapi_resource.data_disk[0].id : null
}
