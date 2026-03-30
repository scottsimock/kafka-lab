// =====================================================
// Input Variables
// =====================================================

variable "name" {
  description = "Name of the virtual network"
  type        = string
}

variable "location" {
  description = "Azure region for the virtual network"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "address_space" {
  description = "Address space CIDR blocks for the virtual network"
  type        = list(string)
}

variable "subnets" {
  description = "Map of subnet name to subnet configuration"
  type = map(object({
    address_prefix                    = string
    private_endpoint_network_policies = optional(string, null)
  }))
}

variable "tags" {
  description = "Tags to apply to the virtual network"
  type        = map(string)
  default     = {}
}
