output "uami_id" {
  description = "Full resource ID of the user assigned managed identity"
  value       = azapi_resource.main.id
}

output "uami_principal_id" {
  description = "Service principal object ID of the managed identity"
  value       = azapi_resource.main.output.properties.principalId
}

output "uami_client_id" {
  description = "Application (client) ID of the managed identity"
  value       = azapi_resource.main.output.properties.clientId
}
