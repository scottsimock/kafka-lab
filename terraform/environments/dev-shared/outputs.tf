// =====================================================
// Shared Layer Outputs
// =====================================================

output "resource_group_id" {
  description = "Resource ID of the existing resource group"
  value       = data.azapi_resource.resource_group.id
}

// ── Managed Identity ────────────────────────────────

output "uami_id" {
  description = "Full resource ID of the user assigned managed identity"
  value       = module.uami_kafkalab.uami_id
}

output "uami_principal_id" {
  description = "Service principal object ID of the managed identity"
  value       = module.uami_kafkalab.uami_principal_id
}

output "uami_client_id" {
  description = "Application (client) ID of the managed identity"
  value       = module.uami_kafkalab.uami_client_id
}

// ── Key Vault ───────────────────────────────────────

output "key_vault_id" {
  description = "Resource ID of the key vault"
  value       = module.key_vault.key_vault_id
}

output "key_vault_name" {
  description = "Name of the key vault"
  value       = module.key_vault.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the key vault"
  value       = module.key_vault.key_vault_uri
}

output "cmk_key_id" {
  description = "Resource ID of the CMEK encryption key"
  value       = module.key_vault.cmk_key_id
}

output "cmk_key_versionless_id" {
  description = "Versionless URI of the CMEK encryption key"
  value       = module.key_vault.cmk_key_versionless_id
}

// ── Virtual Network ─────────────────────────────────

output "vnet_id" {
  description = "Resource ID of the primary virtual network"
  value       = module.vnet_scus.vnet_id
}

output "vnet_name" {
  description = "Name of the primary virtual network"
  value       = module.vnet_scus.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet names to resource IDs"
  value       = module.vnet_scus.subnet_ids
}

// ── Private DNS Zones ───────────────────────────────

output "private_dns_zone_ids" {
  description = "Map of DNS zone key to resource ID for shared private DNS zones"
  value       = { for k, v in module.shared_dns_zones : k => v.dns_zone_id }
}

// ── Log Analytics ───────────────────────────────────

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = module.log_analytics.workspace_id
}

output "log_analytics_customer_id" {
  description = "Customer ID of the Log Analytics workspace"
  value       = module.log_analytics.workspace_customer_id
}

// ── Private Endpoints ───────────────────────────────

output "pe_key_vault_id" {
  description = "Resource ID of the key vault private endpoint"
  value       = module.pe_key_vault.private_endpoint_id
}
