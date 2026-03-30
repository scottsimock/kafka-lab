// =====================================================
// Input Variables
// =====================================================

variable "name" {
  description = "Name of the network security group"
  type        = string
}

variable "location" {
  description = "Azure region for the network security group"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "security_rules" {
  description = "Security rules to apply to the network security group"
  type = list(object({
    name                         = string
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    source_port_range            = optional(string)
    source_port_ranges           = optional(list(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string))
    description                  = optional(string, "")
  }))
  default = []
}

variable "subnet_id" {
  description = "Resource ID of the subnet to associate the NSG with"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the network security group"
  type        = map(string)
  default     = {}
}
