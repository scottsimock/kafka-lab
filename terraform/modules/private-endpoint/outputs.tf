// =====================================================
// Outputs
// =====================================================

output "private_endpoint_id" {
  description = "Resource ID of the private endpoint"
  value       = azapi_resource.main.id
}

output "private_endpoint_name" {
  description = "Name of the private endpoint"
  value       = azapi_resource.main.name
}

output "network_interface_id" {
  description = "Resource ID of the private endpoint network interface"
  value       = try(azapi_resource.main.output.properties.networkInterfaces[0].id, null)
}
