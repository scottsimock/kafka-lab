// Subnet layout for a multi-tier Kafka deployment

variable "vnet_address_space" {
  description = "VNet CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

locals {
  subnets = {
    "snet-kafka-brokers" = {
      index   = 0
      newbits = 8
    }
    "snet-kafka-zookeeper" = {
      index   = 1
      newbits = 8
    }
    "snet-kafka-connect" = {
      index   = 2
      newbits = 8
    }
    "snet-web-app" = {
      index   = 3
      newbits = 8
    }
    "snet-management" = {
      index   = 4
      newbits = 8
    }
    "snet-private-endpoints" = {
      index   = 5
      newbits = 8
    }
  }

  subnet_configs = [
    for name, config in local.subnets : {
      name = name
      properties = {
        addressPrefix = cidrsubnet(var.vnet_address_space, config.newbits, config.index)
      }
    }
  ]
}

// Use local.subnet_configs in the VNet body.properties.subnets array
output "subnet_layout" {
  description = "Computed subnet CIDR allocations"
  value = {
    for name, config in local.subnets :
    name => cidrsubnet(var.vnet_address_space, config.newbits, config.index)
  }
}
