variable "name" {
  description = "Name of the key vault"
  type        = string
}

variable "location" {
  description = "Azure region for the key vault"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID for the key vault"
  type        = string
}

variable "uami_principal_id" {
  description = "Principal ID of the user assigned managed identity for crypto access"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the key vault"
  type        = map(string)
  default     = {}
}
