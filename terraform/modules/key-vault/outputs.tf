output "key_vault_id" {
  description = "Resource ID of the key vault"
  value       = azapi_resource.main.id
}

output "key_vault_uri" {
  description = "URI of the key vault"
  value       = azapi_resource.main.output.properties.vaultUri
}

output "key_vault_name" {
  description = "Name of the key vault"
  value       = azapi_resource.main.name
}

output "cmk_key_id" {
  description = "Full resource ID of the CMEK encryption key"
  value       = azapi_resource.cmk_key.id
}

output "cmk_key_versionless_id" {
  description = "Versionless URI of the CMEK encryption key for resource references"
  value       = try(azapi_resource.cmk_key.output.properties.keyUri, null)
}
