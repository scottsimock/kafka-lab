variable "name" {
  description = "Name of the user assigned managed identity"
  type        = string
}

variable "location" {
  description = "Azure region for the managed identity"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the managed identity"
  type        = map(string)
  default     = {}
}
