// =====================================================
// Root Module Outputs
// =====================================================

output "resource_group_id" {
  description = "Resource ID of the existing resource group"
  value       = data.azapi_resource.resource_group.id
}

output "vnet_id" {
  description = "Resource ID of the primary virtual network"
  value       = module.vnet_scus.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet names to resource IDs"
  value       = module.vnet_scus.subnet_ids
}
