variable "name" {
  description = "Name of the function app"
  type        = string
}

variable "location" {
  description = "Azure region for the function app"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "web_app_subnet_id" {
  description = "Subnet ID for VNet integration (snet-web-app)"
  type        = string
}

variable "user_assigned_identity_id" {
  description = "Resource ID of the user assigned managed identity"
  type        = string
}

variable "user_assigned_identity_principal_id" {
  description = "Principal ID of the user assigned managed identity for RBAC"
  type        = string
}

variable "user_assigned_identity_client_id" {
  description = "Client ID of the user assigned managed identity"
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault name for secret references"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID for RBAC assignments"
  type        = string
}

variable "storage_account_name" {
  description = "Optional override for storage account name"
  type        = string
  default     = null
}

variable "schema_registry_url" {
  description = "Schema Registry URL (e.g., http://schema-registry:8081)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
