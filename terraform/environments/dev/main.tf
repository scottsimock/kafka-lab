// =====================================================
// Provider Configuration
// =====================================================

provider "azapi" {}

// =====================================================
// Existing Resource Group Reference
// =====================================================

data "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2023-07-01"
  name      = var.resource_group_name
  parent_id = "/subscriptions/${var.subscription_id}"
}

// =====================================================
// Managed Identity
// =====================================================

module "uami_kafkalab" {
  source = "../../modules/managed-identity"

  name              = "klc-id-kafkalab-scus"
  location          = var.primary_location
  resource_group_id = data.azapi_resource.resource_group.id
  tags              = local.common_tags
}

// =====================================================
// Key Vault
// =====================================================

data "azapi_client_config" "current" {}

module "key_vault" {
  source = "../../modules/key-vault"

  name              = "klc-kv-kafkalab-scus"
  location          = var.primary_location
  resource_group_id = data.azapi_resource.resource_group.id
  tenant_id         = data.azapi_client_config.current.tenant_id
  uami_principal_id = module.uami_kafkalab.uami_principal_id
  tags              = local.common_tags
}

// =====================================================
// Virtual Network
// =====================================================

module "vnet_scus" {
  source = "../../modules/virtual-network"

  name              = "klc-vnet-scus"
  location          = var.primary_location
  resource_group_id = data.azapi_resource.resource_group.id
  address_space     = ["10.1.0.0/16"]
  tags              = local.common_tags

  subnets = {
    "snet-kafka-brokers" = {
      address_prefix = "10.1.1.0/24"
    }
    "snet-zookeeper" = {
      address_prefix = "10.1.2.0/24"
    }
    "snet-schema-registry" = {
      address_prefix = "10.1.3.0/24"
    }
    "snet-connect" = {
      address_prefix = "10.1.4.0/24"
    }
    "snet-web-app" = {
      address_prefix = "10.1.5.0/24"
    }
    "snet-private-endpoints" = {
      address_prefix                    = "10.1.6.0/24"
      private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
    }
    "snet-management" = {
      address_prefix = "10.1.7.0/24"
    }
  }
}

// =====================================================
// NSG Instances
// =====================================================

locals {
  nsg_configs = {
    "nsg-kafka-brokers" = {
      subnet_name = "snet-kafka-brokers"
      security_rules = [
        {
          name                         = "AllowKafkaClientTCP9092"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "9092"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.4.0/24", "10.1.5.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Kafka client connections from connect and web-app subnets"
        },
        {
          name                         = "AllowKafkaSSLClientTCP9093"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "9093"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.4.0/24", "10.1.5.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Kafka SSL client connections from connect and web-app subnets"
        },
        {
          name                         = "AllowInterBrokerReplicationTCP9092"
          priority                     = 120
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "9092"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.1.0/24", "10.2.1.0/24", "10.3.1.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow inter-broker replication"
        },
        {
          name                         = "AllowInterBrokerSSLTCP9093"
          priority                     = 130
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "9093"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.1.0/24", "10.2.1.0/24", "10.3.1.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow inter-broker SSL replication"
        },
        {
          name                         = "AllowSchemaRegistryTCP9092to9093"
          priority                     = 140
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = null
          destination_port_ranges      = ["9092", "9093"]
          source_address_prefix        = "10.1.3.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow schema registry to broker connections"
        },
        {
          name                         = "AllowControlCenterTCP9021"
          priority                     = 150
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "9021"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Control Center management access"
        },
        {
          name                         = "AllowSSHTCP22FromManagement"
          priority                     = 160
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "22"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow SSH from management subnet"
        },
      ]
    }
    "nsg-zookeeper" = {
      subnet_name = "snet-zookeeper"
      security_rules = [
        {
          name                         = "AllowZKClientTCP2181"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "2181"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.1.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow ZooKeeper client connections from Kafka brokers"
        },
        {
          name                         = "AllowCrossRegionBrokerZKTCP2181"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "2181"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.1.0/24", "10.2.1.0/24", "10.3.1.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow cross-region broker to ZooKeeper access"
        },
        {
          name                         = "AllowZKFollowerLeaderTCP2888"
          priority                     = 120
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "2888"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.2.0/24", "10.2.2.0/24", "10.3.2.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow ZooKeeper follower-to-leader connections"
        },
        {
          name                         = "AllowZKLeaderElectionTCP3888"
          priority                     = 130
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "3888"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.2.0/24", "10.2.2.0/24", "10.3.2.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow ZooKeeper leader election"
        },
        {
          name                         = "AllowSSHTCP22FromManagement"
          priority                     = 140
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "22"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow SSH from management subnet"
        },
      ]
    }
    "nsg-schema-registry" = {
      subnet_name = "snet-schema-registry"
      security_rules = [
        {
          name                         = "AllowSRFromBrokersTCP8081"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8081"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.1.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Schema Registry from Kafka brokers"
        },
        {
          name                         = "AllowSRFromConnectTCP8081"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8081"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.4.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Schema Registry from connect subnet"
        },
        {
          name                         = "AllowSRFromWebAppTCP8081"
          priority                     = 120
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8081"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.5.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Schema Registry from web-app subnet"
        },
        {
          name                         = "AllowCrossRegionSRTCP8081"
          priority                     = 130
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8081"
          destination_port_ranges      = null
          source_address_prefix        = null
          source_address_prefixes      = ["10.1.3.0/24", "10.2.3.0/24", "10.3.3.0/24"]
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow cross-region Schema Registry access"
        },
        {
          name                         = "AllowSSHTCP22FromManagement"
          priority                     = 140
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "22"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow SSH from management subnet"
        },
      ]
    }
    "nsg-connect" = {
      subnet_name = "snet-connect"
      security_rules = [
        {
          name                         = "AllowConnectRESTFromMgmtTCP8083"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8083"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Connect REST API from management subnet"
        },
        {
          name                         = "AllowConnectRESTFromWebAppTCP8083"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8083"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.5.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Connect REST API from web-app subnet"
        },
        {
          name                         = "AllowConnectIntraClusterTCP8089"
          priority                     = 120
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8089"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Connect intra-cluster communication"
        },
        {
          name                         = "AllowConnectMDSRBACTCP8090"
          priority                     = 130
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "8090"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow Connect MDS RBAC access"
        },
        {
          name                         = "AllowSSHTCP22FromManagement"
          priority                     = 140
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "22"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow SSH from management subnet"
        },
      ]
    }
    "nsg-web-app" = {
      subnet_name = "snet-web-app"
      security_rules = [
        {
          name                         = "AllowHTTPSFromFrontDoor"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "443"
          destination_port_ranges      = null
          source_address_prefix        = "AzureFrontDoor.Backend"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow HTTPS from Azure Front Door backend"
        },
        {
          name                         = "AllowSSHTCP22FromManagement"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "22"
          destination_port_ranges      = null
          source_address_prefix        = "10.1.7.0/24"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow SSH from management subnet"
        },
      ]
    }
    "nsg-private-endpoints" = {
      subnet_name = "snet-private-endpoints"
      security_rules = [
        {
          name                         = "AllowHTTPSFromVNetKV"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "443"
          destination_port_ranges      = null
          source_address_prefix        = "VirtualNetwork"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow HTTPS to Key Vault private endpoint from VNet"
        },
        {
          name                         = "AllowHTTPSFromVNetBlob"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "443"
          destination_port_ranges      = null
          source_address_prefix        = "VirtualNetwork"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow HTTPS to Blob Storage private endpoint from VNet"
        },
      ]
    }
    "nsg-management" = {
      subnet_name = "snet-management"
      security_rules = [
        {
          name                         = "AllowSSHTCP22FromVNet"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          source_port_ranges           = null
          destination_port_range       = "22"
          destination_port_ranges      = null
          source_address_prefix        = "VirtualNetwork"
          source_address_prefixes      = null
          destination_address_prefix   = "*"
          destination_address_prefixes = null
          description                  = "Allow SSH access from within the VNet"
        },
      ]
    }
  }
}

module "nsgs" {
  source   = "../../modules/network-security-group"
  for_each = local.nsg_configs

  name              = each.key
  location          = var.primary_location
  resource_group_id = data.azapi_resource.resource_group.id
  security_rules    = each.value.security_rules
  subnet_id         = module.vnet_scus.subnet_ids[each.value.subnet_name]
  tags              = local.common_tags
}

// =====================================================
// Private DNS Zones
// =====================================================

locals {
  private_dns_zones = {
    "blob"  = "privatelink.blob.core.windows.net"
    "vault" = "privatelink.vaultcore.azure.net"
  }
}

module "private_dns_zones" {
  source   = "../../modules/private-dns-zone"
  for_each = local.private_dns_zones

  zone_name         = each.value
  resource_group_id = data.azapi_resource.resource_group.id
  vnet_links = {
    "link-scus" = module.vnet_scus.vnet_id
  }
  tags = local.common_tags
}
