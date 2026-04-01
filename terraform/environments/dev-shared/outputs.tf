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
