// =====================================================
// Input Variables
// =====================================================

variable "name" {
  description = "Name of the private endpoint"
  type        = string
}

variable "location" {
  description = "Azure region for the private endpoint"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet for the private endpoint NIC"
  type        = string
}

variable "target_resource_id" {
  description = "Resource ID of the target Azure resource"
  type        = string
}

variable "group_ids" {
  description = "Sub-resource group IDs for the private link connection (e.g., [\"blob\"], [\"vault\"])"
  type        = list(string)
}

variable "dns_zone_ids" {
  description = "Map of group name to private DNS zone resource ID for DNS registration"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to the private endpoint"
  type        = map(string)
  default     = {}
}
