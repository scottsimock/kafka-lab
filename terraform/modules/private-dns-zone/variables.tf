// =====================================================
// Input Variables
// =====================================================

variable "zone_name" {
  description = "Name of the private DNS zone (e.g., privatelink.blob.core.windows.net)"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "vnet_links" {
  description = "Map of VNet link name to VNet resource ID"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to the DNS zone"
  type        = map(string)
  default     = {}
}
