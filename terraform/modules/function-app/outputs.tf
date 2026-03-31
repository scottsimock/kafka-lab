output "function_app_id" {
  description = "Resource ID of the function app"
  value       = azapi_resource.function_app.id
}

output "function_app_name" {
  description = "Name of the function app"
  value       = azapi_resource.function_app.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the function app"
  value       = azapi_resource.function_app.output.properties.defaultHostName
}

output "app_service_plan_id" {
  description = "Resource ID of the App Service Plan"
  value       = azapi_resource.app_service_plan.id
}

output "storage_account_id" {
  description = "Resource ID of the storage account"
  value       = azapi_resource.storage.id
}
