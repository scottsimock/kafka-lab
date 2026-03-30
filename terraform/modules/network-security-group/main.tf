// =====================================================
// Network Security Group
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      securityRules = concat(
        [for rule in var.security_rules : {
          name = rule.name
          properties = {
            priority                   = rule.priority
            direction                  = rule.direction
            access                     = rule.access
            protocol                   = rule.protocol
            sourcePortRange            = rule.source_port_range
            sourcePortRanges           = rule.source_port_ranges
            destinationPortRange       = rule.destination_port_range
            destinationPortRanges      = rule.destination_port_ranges
            sourceAddressPrefix        = rule.source_address_prefix
            sourceAddressPrefixes      = rule.source_address_prefixes
            destinationAddressPrefix   = rule.destination_address_prefix
            destinationAddressPrefixes = rule.destination_address_prefixes
            description                = rule.description
          }
        }],
        [{
          name = "DenyAllInbound"
          properties = {
            priority                 = 4096
            direction                = "Inbound"
            access                   = "Deny"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "*"
            destinationAddressPrefix = "*"
            description              = "Deny all inbound traffic"
          }
        }]
      )
    }
  }
}

// =====================================================
// Subnet NSG Association
// =====================================================

resource "azapi_update_resource" "subnet_nsg_association" {
  type        = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  resource_id = var.subnet_id

  body = {
    properties = {
      networkSecurityGroup = {
        id = azapi_resource.main.id
      }
    }
  }

  depends_on = [azapi_resource.main]
}
