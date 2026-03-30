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

output "key_vault_id" {
  description = "Resource ID of the key vault"
  value       = module.key_vault.key_vault_id
}

output "cmk_key_id" {
  description = "Resource ID of the CMEK encryption key"
  value       = module.key_vault.cmk_key_id
}

output "private_dns_zone_ids" {
  description = "Map of DNS zone key to resource ID for each private DNS zone"
  value       = { for k, v in module.private_dns_zones : k => v.dns_zone_id }
}
