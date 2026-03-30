// =====================================================
// Input Variables
// =====================================================

variable "name" {
  description = "VM resource name"
  type        = string
}

variable "location" {
  description = "Azure region for the virtual machine"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the target resource group"
  type        = string
}

variable "subnet_id" {
  description = "Subnet resource ID for NIC placement"
  type        = string
}

variable "private_ip_address" {
  description = "Static private IP address for the NIC"
  type        = string
}

variable "vm_size" {
  description = "Azure VM SKU size"
  type        = string
}

variable "zone" {
  description = "Availability zone for the virtual machine"
  type        = string
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 64
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB; 0 means no data disk"
  type        = number
  default     = 0
}

variable "admin_username" {
  description = "SSH admin username"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for authentication"
  type        = string
}

variable "uami_id" {
  description = "User Assigned Managed Identity resource ID"
  type        = string
}

variable "dns_zone_id" {
  description = "Optional private DNS zone resource ID for A record creation"
  type        = string
  default     = null
}

variable "dns_record_name" {
  description = "Optional DNS record hostname"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
