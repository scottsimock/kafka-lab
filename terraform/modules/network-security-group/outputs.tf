// =====================================================
// Outputs
// =====================================================

output "nsg_id" {
  description = "Resource ID of the network security group"
  value       = azapi_resource.main.id
}

output "nsg_name" {
  description = "Name of the network security group"
  value       = azapi_resource.main.name
}
