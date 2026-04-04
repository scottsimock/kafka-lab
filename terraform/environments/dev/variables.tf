// =====================================================
// Root Module Input Variables
// =====================================================

variable "subscription_id" {
  description = "Azure subscription ID for resource deployment"
  type        = string
}

variable "environment" {
  description = "Environment name used for resource naming and tagging"
  type        = string
  default     = "dev"
}

variable "primary_location" {
  description = "Primary Azure region for resource deployment"
  type        = string
  default     = "southcentralus"
}

variable "resource_group_name" {
  description = "Name of the existing resource group for all resources"
  type        = string
  default     = "klc-rg-kafkalab-scus"
}

variable "ssh_public_key" {
  description = "SSH public key for VM authentication"
  type        = string
  sensitive   = true
}

// =====================================================
// Remote State Backend Configuration
// =====================================================

variable "backend_resource_group" {
  description = "Resource group containing the Terraform state storage account"
  type        = string
  default     = "klc-rg-kafkalab-scus"
}

variable "backend_storage_account" {
  description = "Storage account name for Terraform remote state"
  type        = string
  default     = "klcstgtfstatescus"
}

variable "backend_container" {
  description = "Blob container name for Terraform remote state"
  type        = string
  default     = "tfstate"
}
