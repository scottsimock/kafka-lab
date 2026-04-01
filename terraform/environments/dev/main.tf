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
// Managed Identity (managed by dev-shared layer)
// =====================================================

data "azapi_resource" "uami_kafkalab" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "klc-id-kafkalab-scus"
  parent_id = data.azapi_resource.resource_group.id

  response_export_values = ["properties.principalId", "properties.clientId"]
}

// =====================================================
// Key Vault (managed by dev-shared layer)
// =====================================================

data "azapi_resource" "key_vault" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = "klc-kv-kafkalab-scus"
  parent_id = data.azapi_resource.resource_group.id

  response_export_values = ["properties.vaultUri"]
}

data "azapi_resource" "cmk_key" {
  type      = "Microsoft.KeyVault/vaults/keys@2023-07-01"
  name      = "klc-kv-kafkalab-scus-cmk"
  parent_id = data.azapi_resource.key_vault.id

  response_export_values = ["properties.keyUriWithVersion", "properties.keyUri"]
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
    "blob"     = "privatelink.blob.core.windows.net"
    "vault"    = "privatelink.vaultcore.azure.net"
    "sites"    = "privatelink.azurewebsites.net"
    "internal" = "kafkalab.internal"
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

// =====================================================
// Storage Account
// =====================================================

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2023-01-01"
  name      = "klcstgkafkalabscus"
  parent_id = data.azapi_resource.resource_group.id
  location  = var.primary_location
  tags      = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azapi_resource.uami_kafkalab.id]
  }

  body = {
    kind = "StorageV2"
    sku  = { name = "Standard_LRS" }
    properties = {
      publicNetworkAccess   = "Disabled"
      minimumTlsVersion     = "TLS1_2"
      allowBlobPublicAccess = false
      encryption = {
        keySource = "Microsoft.Keyvault"
        keyvaultproperties = {
          keyname     = "${data.azapi_resource.key_vault.name}-cmk"
          keyvaulturi = data.azapi_resource.key_vault.output.properties.vaultUri
        }
        identity = {
          userAssignedIdentity = data.azapi_resource.uami_kafkalab.id
        }
        services = {
          blob = { enabled = true, keyType = "Account" }
          file = { enabled = true, keyType = "Account" }
        }
      }
    }
  }
}

// =====================================================
// Blob Container
// =====================================================

resource "azapi_resource" "tfstate_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  name      = "tfstate"
  parent_id = "${azapi_resource.storage_account.id}/blobServices/default"

  body = {
    properties = {
      publicAccess = "None"
    }
  }

  depends_on = [azapi_resource.storage_account]
}

// =====================================================
// Private Endpoints
// =====================================================

module "pe_storage_blob" {
  source = "../../modules/private-endpoint"

  name               = "klc-pe-storage-blob-scus"
  location           = var.primary_location
  resource_group_id  = data.azapi_resource.resource_group.id
  subnet_id          = module.vnet_scus.subnet_ids["snet-private-endpoints"]
  target_resource_id = azapi_resource.storage_account.id
  group_ids          = ["blob"]
  dns_zone_ids = {
    "blob" = module.private_dns_zones["blob"].dns_zone_id
  }
  tags = local.common_tags
}

module "pe_key_vault" {
  source = "../../modules/private-endpoint"

  name               = "klc-pe-keyvault-scus"
  location           = var.primary_location
  resource_group_id  = data.azapi_resource.resource_group.id
  subnet_id          = module.vnet_scus.subnet_ids["snet-private-endpoints"]
  target_resource_id = data.azapi_resource.key_vault.id
  group_ids          = ["vault"]
  dns_zone_ids = {
    "vault" = module.private_dns_zones["vault"].dns_zone_id
  }
  tags = local.common_tags
}

// =====================================================
// Function App (Web Application)
// =====================================================

module "function_app" {
  source = "../../modules/function-app"

  name                                = "klc-func-kafkalab-scus"
  location                            = var.primary_location
  resource_group_id                   = data.azapi_resource.resource_group.id
  web_app_subnet_id                   = module.vnet_scus.subnet_ids["snet-web-app"]
  user_assigned_identity_id           = data.azapi_resource.uami_kafkalab.id
  user_assigned_identity_principal_id = data.azapi_resource.uami_kafkalab.output.properties.principalId
  user_assigned_identity_client_id    = data.azapi_resource.uami_kafkalab.output.properties.clientId
  key_vault_name                      = data.azapi_resource.key_vault.name
  key_vault_id                        = data.azapi_resource.key_vault.id
  schema_registry_url                 = "http://sr-01.kafkalab.internal:8081"
  tags                                = merge(local.common_tags, { component = "webapp" })
}

module "pe_function_app" {
  source = "../../modules/private-endpoint"

  name               = "klc-pe-func-scus"
  location           = var.primary_location
  resource_group_id  = data.azapi_resource.resource_group.id
  subnet_id          = module.vnet_scus.subnet_ids["snet-private-endpoints"]
  target_resource_id = module.function_app.function_app_id
  group_ids          = ["sites"]
  dns_zone_ids = {
    "sites" = module.private_dns_zones["sites"].dns_zone_id
  }
  tags = local.common_tags
}

// =====================================================
// ZooKeeper VM Instances
// =====================================================

locals {
  zookeeper_nodes = {
    "klc-vm-zk-01-scus" = { private_ip = "10.1.2.4", dns_name = "zk-01" }
    "klc-vm-zk-02-scus" = { private_ip = "10.1.2.5", dns_name = "zk-02" }
    "klc-vm-zk-03-scus" = { private_ip = "10.1.2.6", dns_name = "zk-03" }
  }
}

module "zookeeper_vms" {
  source   = "../../modules/virtual-machine"
  for_each = local.zookeeper_nodes

  name               = each.key
  location           = var.primary_location
  resource_group_id  = data.azapi_resource.resource_group.id
  subnet_id          = module.vnet_scus.subnet_ids["snet-zookeeper"]
  private_ip_address = each.value.private_ip
  vm_size            = "Standard_D2s_v5"
  zone               = "1"
  os_disk_size_gb    = 64
  data_disk_size_gb  = 64
  admin_username     = "azureuser"
  ssh_public_key     = var.ssh_public_key
  uami_id            = data.azapi_resource.uami_kafkalab.id
  dns_zone_id        = module.private_dns_zones["internal"].dns_zone_id
  dns_record_name    = each.value.dns_name
  tags               = merge(local.common_tags, { component = "zookeeper" })
}

// =====================================================
// Kafka Broker VM Instances
// =====================================================

locals {
  kafka_broker_nodes = {
    "klc-vm-kb-01-scus" = { private_ip = "10.1.1.4", dns_name = "kb-01" }
    "klc-vm-kb-02-scus" = { private_ip = "10.1.1.5", dns_name = "kb-02" }
    "klc-vm-kb-03-scus" = { private_ip = "10.1.1.6", dns_name = "kb-03" }
  }
}

module "kafka_broker_vms" {
  source   = "../../modules/virtual-machine"
  for_each = local.kafka_broker_nodes

  name               = each.key
  location           = var.primary_location
  resource_group_id  = data.azapi_resource.resource_group.id
  subnet_id          = module.vnet_scus.subnet_ids["snet-kafka-brokers"]
  private_ip_address = each.value.private_ip
  vm_size            = "Standard_D4s_v5"
  zone               = "1"
  os_disk_size_gb    = 64
  data_disk_size_gb  = 256
  admin_username     = "azureuser"
  ssh_public_key     = var.ssh_public_key
  uami_id            = data.azapi_resource.uami_kafkalab.id
  dns_zone_id        = module.private_dns_zones["internal"].dns_zone_id
  dns_record_name    = each.value.dns_name
  tags               = merge(local.common_tags, { component = "kafka_broker" })
}

// =====================================================
// Schema Registry VM Instances
// =====================================================

locals {
  schema_registry_nodes = {
    "klc-vm-sr-01-scus" = { private_ip = "10.1.3.4", dns_name = "sr-01" }
  }
}

module "schema_registry_vms" {
  source   = "../../modules/virtual-machine"
  for_each = local.schema_registry_nodes

  name               = each.key
  location           = var.primary_location
  resource_group_id  = data.azapi_resource.resource_group.id
  subnet_id          = module.vnet_scus.subnet_ids["snet-schema-registry"]
  private_ip_address = each.value.private_ip
  vm_size            = "Standard_D2s_v5"
  zone               = "1"
  os_disk_size_gb    = 64
  data_disk_size_gb  = 0
  admin_username     = "azureuser"
  ssh_public_key     = var.ssh_public_key
  uami_id            = data.azapi_resource.uami_kafkalab.id
  dns_zone_id        = module.private_dns_zones["internal"].dns_zone_id
  dns_record_name    = each.value.dns_name
  tags               = merge(local.common_tags, { component = "schema_registry" })
}

// =====================================================
// Kafka Connect VM Instances
// =====================================================

locals {
  kafka_connect_nodes = {
    "klc-vm-kc-01-scus" = { private_ip = "10.1.4.4", dns_name = "kc-01" }
  }
}

module "kafka_connect_vms" {
  source   = "../../modules/virtual-machine"
  for_each = local.kafka_connect_nodes

  name               = each.key
  location           = var.primary_location
  resource_group_id  = data.azapi_resource.resource_group.id
  subnet_id          = module.vnet_scus.subnet_ids["snet-connect"]
  private_ip_address = each.value.private_ip
  vm_size            = "Standard_D2s_v5"
  zone               = "1"
  os_disk_size_gb    = 64
  data_disk_size_gb  = 0
  admin_username     = "azureuser"
  ssh_public_key     = var.ssh_public_key
  uami_id            = data.azapi_resource.uami_kafkalab.id
  dns_zone_id        = module.private_dns_zones["internal"].dns_zone_id
  dns_record_name    = each.value.dns_name
  tags               = merge(local.common_tags, { component = "kafka_connect" })
}
