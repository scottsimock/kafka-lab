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

output "storage_account_id" {
  description = "Resource ID of the Terraform state storage account"
  value       = azapi_resource.storage_account.id
}

output "pe_storage_blob_id" {
  description = "Resource ID of the storage account blob private endpoint"
  value       = module.pe_storage_blob.private_endpoint_id
}

output "pe_key_vault_id" {
  description = "Resource ID of the key vault private endpoint"
  value       = module.pe_key_vault.private_endpoint_id
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
