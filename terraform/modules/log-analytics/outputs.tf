// =====================================================
// Outputs
// =====================================================

output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = azapi_resource.main.id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azapi_resource.main.name
}

output "workspace_customer_id" {
  description = "Customer ID (workspace ID) for diagnostic settings integration"
  value       = azapi_resource.main.output.properties.customerId
}
