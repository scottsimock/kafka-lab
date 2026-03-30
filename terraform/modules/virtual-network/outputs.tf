// =====================================================
// Outputs
// =====================================================

output "vnet_id" {
  description = "Resource ID of the virtual network"
  value       = azapi_resource.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azapi_resource.main.name
}

output "subnet_ids" {
  description = "Map of subnet names to resource IDs"
  value = {
    for subnet in azapi_resource.main.output.properties.subnets :
    subnet.name => subnet.id
  }
}
