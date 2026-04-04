// =====================================================
// Root Module Outputs
// =====================================================

output "resource_group_id" {
  description = "Resource ID of the existing resource group"
  value       = data.azapi_resource.resource_group.id
}

output "vnet_id" {
  description = "Resource ID of the primary virtual network (from shared layer)"
  value       = data.terraform_remote_state.shared.outputs.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet names to resource IDs (from shared layer)"
  value       = data.terraform_remote_state.shared.outputs.subnet_ids
}

output "key_vault_id" {
  description = "Resource ID of the key vault"
  value       = data.azapi_resource.key_vault.id
}

output "cmk_key_id" {
  description = "Resource ID of the CMEK encryption key"
  value       = data.azapi_resource.cmk_key.id
}

output "storage_account_id" {
  description = "Resource ID of the Terraform state storage account"
  value       = azapi_resource.storage_account.id
}

output "zookeeper_vm_ids" {
  description = "Map of ZooKeeper VM name to resource ID"
  value       = { for k, v in module.zookeeper_vms : k => v.vm_id }
}

output "zookeeper_private_ips" {
  description = "Map of ZooKeeper VM name to private IP address"
  value       = { for k, v in module.zookeeper_vms : k => v.private_ip_address }
}

output "kafka_broker_vm_ids" {
  description = "Map of Kafka broker VM name to resource ID"
  value       = { for k, v in module.kafka_broker_vms : k => v.vm_id }
}

output "kafka_broker_private_ips" {
  description = "Map of Kafka broker VM name to private IP address"
  value       = { for k, v in module.kafka_broker_vms : k => v.private_ip_address }
}

output "schema_registry_vm_ids" {
  description = "Map of Schema Registry VM name to resource ID"
  value       = { for k, v in module.schema_registry_vms : k => v.vm_id }
}

output "schema_registry_private_ips" {
  description = "Map of Schema Registry VM name to private IP address"
  value       = { for k, v in module.schema_registry_vms : k => v.private_ip_address }
}

output "kafka_connect_vm_ids" {
  description = "Map of Kafka Connect VM name to resource ID"
  value       = { for k, v in module.kafka_connect_vms : k => v.vm_id }
}

output "kafka_connect_private_ips" {
  description = "Map of Kafka Connect VM name to private IP address"
  value       = { for k, v in module.kafka_connect_vms : k => v.private_ip_address }
}

output "function_app_id" {
  description = "Resource ID of the Function App"
  value       = module.function_app.function_app_id
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = module.function_app.function_app_name
}

output "function_app_hostname" {
  description = "Default hostname of the Function App"
  value       = module.function_app.function_app_default_hostname
}

output "app_service_plan_id" {
  description = "Resource ID of the App Service Plan"
  value       = module.function_app.app_service_plan_id
}
