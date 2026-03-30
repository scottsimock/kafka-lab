---
id: doc-10
title: SP0.006 — Azure Virtual Networks and Private Networking
type: other
created_date: '2026-03-30 15:47'
---
# SP0.006 — Azure Virtual Networks and Private Networking

## Executive Summary

The kafka-lab deployment spans three Azure regions — `southcentralus` (primary), `mexicocentral` (secondary), and `canadaeast` (DR) — each provisioned with a dedicated Virtual Network (VNet) carrying a non-overlapping `/16` address space. All Kafka infrastructure (brokers, ZooKeeper, Schema Registry, Kafka Connect) and supporting services (Azure Blob Storage, Azure Key Vault) reside exclusively on private networks with no public endpoints. Inter-region connectivity is achieved through Azure Global VNet Peering, which keeps all cross-region traffic on Microsoft's private backbone without requiring VPN gateways or internet routing. This design satisfies the kafka-lab compliance requirements: CMEK encryption at rest, User Assigned Managed Identity (UAMI) authentication, TLS 1.2+ in transit, and private-only network access with `public_network_access_enabled = false` on every resource.

Each VNet is partitioned into purpose-specific subnets to apply the principle of least privilege at the network layer. Network Security Groups (NSGs) enforce allow-list rules for each Kafka component's port requirements, with an explicit deny-all default at the end of every rule set. Azure PaaS services — Blob Storage and Key Vault — are integrated using Azure Private Endpoints, each provisioned with a dedicated network interface that receives a static private IP from the `private-endpoints` subnet. Private DNS Zones (`privatelink.blob.core.windows.net` and `privatelink.vaultcore.azure.net`) are created globally, then linked to all three VNets, ensuring consistent DNS resolution across all regions without custom DNS servers or conditional forwarders within the Azure network boundary.

The peering topology is a full mesh among all three VNets. Because Azure VNet peering is non-transitive by design, each directed pair requires its own explicit peering resource (six total peering objects). Global VNet peering does not support Standard Load Balancer Basic SKU communication, so all load balancers in this deployment use the Standard SKU. Subnet-level network policy for private endpoints is enabled (`privateEndpointNetworkPolicies: NetworkSecurityGroupEnabled`) to permit NSG and UDR enforcement on the private endpoint NIC. All Terraform IaC uses the AzAPI provider with ARM-native resource types for full API version control and preview feature support.

---

## VNet CIDR Planning

Three non-overlapping `/16` address spaces are allocated — one per region. Within each `/16`, subnets consume `/24` blocks from the lower range, leaving the upper half available for future growth.

| Region | Role | VNet Name | Address Space |
|---|---|---|---|
| `southcentralus` | Primary | `klc-vnet-scus` | `10.1.0.0/16` |
| `mexicocentral` | Secondary | `klc-vnet-mxc` | `10.2.0.0/16` |
| `canadaeast` | DR | `klc-vnet-cae` | `10.3.0.0/16` |

These ranges do not overlap with common on-premises RFC 1918 blocks (10.0.0.0/8 is used, but sub-ranges are chosen to be distinct) and allow for up to 254 subnets of `/24` size within each VNet before address space expansion is needed.

---

## Subnet Design

Each region receives an identical subnet layout. The CIDR blocks below use the region's second octet as the discriminator (1 = scus, 2 = mxc, 3 = cae). Replace `{R}` with the appropriate value for each region.

### southcentralus — `klc-vnet-scus` (10.1.0.0/16)

| Subnet Name | CIDR | Purpose |
|---|---|---|
| `snet-kafka-brokers` | `10.1.1.0/24` | Kafka broker VMs (3-node cluster, AZ-spread) |
| `snet-zookeeper` | `10.1.2.0/24` | ZooKeeper ensemble VMs (3-node) |
| `snet-schema-registry` | `10.1.3.0/24` | Confluent Schema Registry VMs |
| `snet-connect` | `10.1.4.0/24` | Kafka Connect worker VMs |
| `snet-web-app` | `10.1.5.0/24` | Web application tier (frontend + API) |
| `snet-private-endpoints` | `10.1.6.0/24` | Private endpoint NICs for Blob Storage and Key Vault |
| `snet-management` | `10.1.7.0/24` | Bastion, monitoring agents, jump hosts |

### mexicocentral — `klc-vnet-mxc` (10.2.0.0/16)

| Subnet Name | CIDR | Purpose |
|---|---|---|
| `snet-kafka-brokers` | `10.2.1.0/24` | Kafka broker VMs (HA replica set) |
| `snet-zookeeper` | `10.2.2.0/24` | ZooKeeper observer nodes |
| `snet-schema-registry` | `10.2.3.0/24` | Schema Registry secondary instances |
| `snet-connect` | `10.2.4.0/24` | Kafka Connect workers |
| `snet-web-app` | `10.2.5.0/24` | Web application secondary tier |
| `snet-private-endpoints` | `10.2.6.0/24` | Private endpoint NICs for Blob Storage and Key Vault |
| `snet-management` | `10.2.7.0/24` | Management and monitoring |

### canadaeast — `klc-vnet-cae` (10.3.0.0/16)

| Subnet Name | CIDR | Purpose |
|---|---|---|
| `snet-kafka-brokers` | `10.3.1.0/24` | Kafka broker VMs (DR passive) |
| `snet-zookeeper` | `10.3.2.0/24` | ZooKeeper DR observer nodes |
| `snet-schema-registry` | `10.3.3.0/24` | Schema Registry DR instances |
| `snet-connect` | `10.3.4.0/24` | Kafka Connect DR workers |
| `snet-web-app` | `10.3.5.0/24` | Web application DR tier |
| `snet-private-endpoints` | `10.3.6.0/24` | Private endpoint NICs for Blob Storage and Key Vault |
| `snet-management` | `10.3.7.0/24` | Management and monitoring |

---

## VNet Peering Configuration

### Topology: Full Mesh

With three VNets and no central hub requirement (no on-premises gateway, no NVA in the primary region), a **full mesh** peering topology is used. Every VNet peers directly with every other VNet, providing the lowest latency path for cross-region traffic.

Since peering between regions uses **Global VNet Peering**, all six directed peering objects must be created explicitly:

| Peering Name | Source VNet | Target VNet | Type |
|---|---|---|---|
| `scus-to-mxc` | `klc-vnet-scus` | `klc-vnet-mxc` | Global (cross-region) |
| `mxc-to-scus` | `klc-vnet-mxc` | `klc-vnet-scus` | Global (cross-region) |
| `scus-to-cae` | `klc-vnet-scus` | `klc-vnet-cae` | Global (cross-region) |
| `cae-to-scus` | `klc-vnet-cae` | `klc-vnet-scus` | Global (cross-region) |
| `mxc-to-cae` | `klc-vnet-mxc` | `klc-vnet-cae` | Global (cross-region) |
| `cae-to-mxc` | `klc-vnet-cae` | `klc-vnet-mxc` | Global (cross-region) |

### Key Peering Properties

| Property | Value | Rationale |
|---|---|---|
| `allowVirtualNetworkAccess` | `true` | Enables routing between peered VNets |
| `allowForwardedTraffic` | `true` | Allows traffic forwarded by a VM/NVA from a non-peered VNet to traverse this peering |
| `allowGatewayTransit` | `false` | No VPN gateway transit needed (no on-premises connectivity) |
| `useRemoteGateways` | `false` | No remote gateway to use |

### Transitivity Limitations

Azure VNet peering is **non-transitive**: traffic between VNet-A and VNet-C does not flow through VNet-B even if A↔B and B↔C are peered. This is why all three explicit pairs are required for a three-region mesh. If a hub-and-spoke topology were used instead, UDRs and a Network Virtual Appliance (or Azure Firewall) in the hub would be required to forward traffic between spokes — this adds latency and cost that is unnecessary for this deployment.

**Global peering limitation**: Resources that use a Basic SKU Load Balancer cannot communicate with resources in globally peered VNets. All load balancers in the kafka-lab deployment must use the **Standard SKU** to avoid this constraint.

---

## NSG Rules

One NSG is attached to each subnet. The rules below define the required allow rules per component. All NSGs share a terminal `Deny-All-Inbound` rule at priority 4096.

### NSG: `nsg-kafka-brokers` (attached to `snet-kafka-brokers`)

| Priority | Direction | Protocol | Port | Source | Destination | Description |
|---|---|---|---|---|---|---|
| 100 | Inbound | TCP | 9092 | `snet-connect`, `snet-web-app` | `snet-kafka-brokers` | Kafka plaintext client connections |
| 110 | Inbound | TCP | 9093 | `snet-connect`, `snet-web-app` | `snet-kafka-brokers` | Kafka SSL/SASL_SSL client connections |
| 120 | Inbound | TCP | 9092 | `10.1.1.0/24`, `10.2.1.0/24`, `10.3.1.0/24` | `snet-kafka-brokers` | Inter-broker replication (all regions) |
| 130 | Inbound | TCP | 9093 | `10.1.1.0/24`, `10.2.1.0/24`, `10.3.1.0/24` | `snet-kafka-brokers` | Inter-broker SSL replication (all regions) |
| 140 | Inbound | TCP | 9092-9093 | `snet-schema-registry` | `snet-kafka-brokers` | Schema Registry to broker access |
| 150 | Inbound | TCP | 9021 | `snet-management` | `snet-kafka-brokers` | Confluent Control Center management |
| 160 | Inbound | TCP | 22 | `snet-management` | `snet-kafka-brokers` | SSH from management subnet only |
| 200 | Outbound | TCP | 2181 | `snet-kafka-brokers` | `snet-zookeeper` | Broker-to-ZooKeeper coordination |
| 4096 | Inbound | Any | Any | Any | Any | Deny all other inbound |

### NSG: `nsg-zookeeper` (attached to `snet-zookeeper`)

| Priority | Direction | Protocol | Port | Source | Destination | Description |
|---|---|---|---|---|---|---|
| 100 | Inbound | TCP | 2181 | `snet-kafka-brokers` | `snet-zookeeper` | ZooKeeper client port (brokers) |
| 110 | Inbound | TCP | 2181 | `10.1.1.0/24`, `10.2.1.0/24`, `10.3.1.0/24` | `snet-zookeeper` | ZooKeeper client access from all broker regions |
| 120 | Inbound | TCP | 2888 | `10.1.2.0/24`, `10.2.2.0/24`, `10.3.2.0/24` | `snet-zookeeper` | ZooKeeper follower-to-leader replication |
| 130 | Inbound | TCP | 3888 | `10.1.2.0/24`, `10.2.2.0/24`, `10.3.2.0/24` | `snet-zookeeper` | ZooKeeper leader election |
| 140 | Inbound | TCP | 22 | `snet-management` | `snet-zookeeper` | SSH from management subnet only |
| 4096 | Inbound | Any | Any | Any | Any | Deny all other inbound |

### NSG: `nsg-schema-registry` (attached to `snet-schema-registry`)

| Priority | Direction | Protocol | Port | Source | Destination | Description |
|---|---|---|---|---|---|---|
| 100 | Inbound | TCP | 8081 | `snet-kafka-brokers` | `snet-schema-registry` | Brokers fetching schema metadata |
| 110 | Inbound | TCP | 8081 | `snet-connect` | `snet-schema-registry` | Kafka Connect schema lookup |
| 120 | Inbound | TCP | 8081 | `snet-web-app` | `snet-schema-registry` | Web app schema queries |
| 130 | Inbound | TCP | 8081 | `10.1.3.0/24`, `10.2.3.0/24`, `10.3.3.0/24` | `snet-schema-registry` | Cross-region Schema Registry replication |
| 140 | Inbound | TCP | 22 | `snet-management` | `snet-schema-registry` | SSH from management subnet only |
| 4096 | Inbound | Any | Any | Any | Any | Deny all other inbound |

### NSG: `nsg-connect` (attached to `snet-connect`)

| Priority | Direction | Protocol | Port | Source | Destination | Description |
|---|---|---|---|---|---|---|
| 100 | Inbound | TCP | 8083 | `snet-management` | `snet-connect` | Kafka Connect REST API (admin/monitoring) |
| 110 | Inbound | TCP | 8083 | `snet-web-app` | `snet-connect` | Web app accessing Connect REST API |
| 120 | Inbound | TCP | 8089 | `snet-management` | `snet-connect` | Connect intra-cluster communication (alternate listener) |
| 130 | Inbound | TCP | 8090 | `snet-management` | `snet-connect` | Confluent Metadata Service (MDS/RBAC) |
| 140 | Inbound | TCP | 22 | `snet-management` | `snet-connect` | SSH from management subnet only |
| 4096 | Inbound | Any | Any | Any | Any | Deny all other inbound |

### NSG: `nsg-web-app` (attached to `snet-web-app`)

| Priority | Direction | Protocol | Port | Source | Destination | Description |
|---|---|---|---|---|---|---|
| 100 | Inbound | TCP | 443 | `AzureFrontDoor.Backend` | `snet-web-app` | HTTPS from Application Gateway / Front Door only |
| 110 | Inbound | TCP | 22 | `snet-management` | `snet-web-app` | SSH from management subnet only |
| 4096 | Inbound | Any | Any | Any | Any | Deny all other inbound |

### NSG: `nsg-private-endpoints` (attached to `snet-private-endpoints`)

| Priority | Direction | Protocol | Port | Source | Destination | Description |
|---|---|---|---|---|---|---|
| 100 | Inbound | TCP | 443 | `VirtualNetwork` | `snet-private-endpoints` | HTTPS to Key Vault private endpoint |
| 110 | Inbound | TCP | 443 | `VirtualNetwork` | `snet-private-endpoints` | HTTPS to Blob Storage private endpoint |
| 4096 | Inbound | Any | Any | Any | Any | Deny all other inbound |

> **Note:** `privateEndpointNetworkPolicies` must be set to `NetworkSecurityGroupEnabled` (API version 2023-05-01+) or `Enabled` (older API versions) on `snet-private-endpoints` for NSG rules to take effect on private endpoint NICs. This is distinct from `privateLinkServiceNetworkPolicies`, which governs Private Link *service provider* resources and is not relevant here.

---

## Private Endpoint Architecture

### Design Principles

- One dedicated private endpoint per service instance — private endpoints are never shared between services.
- All private endpoints deploy to the `snet-private-endpoints` subnet in each region's VNet.
- Each private endpoint gets a **static private IP** assigned from the subnet DHCP range; the IP is immutable for the lifetime of the private endpoint.
- `public_network_access_enabled = false` is set on every PaaS resource; access is exclusively through the private endpoint.
- The private endpoint resource and the VNet must be in the same region and subscription; the target PaaS service may be in a different region.

### Azure Blob Storage

| Property | Value |
|---|---|
| Resource type | `Microsoft.Storage/storageAccounts` |
| Target subresource | `blob` |
| Private endpoint NIC location | `snet-private-endpoints` in each region |
| Private IP (scus) | `10.1.6.4` (first available in subnet) |
| Private IP (mxc) | `10.2.6.4` |
| Private IP (cae) | `10.3.6.4` |

### Azure Key Vault

| Property | Value |
|---|---|
| Resource type | `Microsoft.KeyVault/vaults` |
| Target subresource | `vault` |
| Private endpoint NIC location | `snet-private-endpoints` in each region |
| Private IP (scus) | `10.1.6.5` |
| Private IP (mxc) | `10.2.6.5` |
| Private IP (cae) | `10.3.6.5` |

### DNS Resolution Flow

When a VM in `snet-kafka-brokers` calls `mystorageaccount.blob.core.windows.net`:

1. Azure public DNS returns a CNAME record: `mystorageaccount.blob.core.windows.net` → `mystorageaccount.privatelink.blob.core.windows.net`
2. The VNet's DNS server (Azure DNS at `168.63.129.16`) is queried for `mystorageaccount.privatelink.blob.core.windows.net`
3. Because the VNet is linked to the Private DNS Zone `privatelink.blob.core.windows.net`, Azure DNS returns the A record pointing to the private endpoint's NIC IP (e.g., `10.1.6.4`)
4. Traffic flows to the private endpoint NIC entirely within the VNet — no public internet egress occurs

The same chain applies to Key Vault: `mykeyvault.vault.azure.net` → `mykeyvault.privatelink.vaultcore.azure.net` → `10.1.6.5`.

---

## Private DNS Zone Design

Private DNS Zones are **global resources** in Azure — they are not region-specific. One zone is created per service type and linked to all three VNets.

### Zone Names

| Service | Private DNS Zone Name | Public DNS Zone Forwarder |
|---|---|---|
| Azure Blob Storage | `privatelink.blob.core.windows.net` | `blob.core.windows.net` |
| Azure Key Vault | `privatelink.vaultcore.azure.net` | `vault.azure.net`, `vaultcore.azure.net` |

### VNet Link Configuration

Each Private DNS Zone must be linked to all three VNets. Autoregistration is **disabled** for the private endpoint zones (autoregistration is only appropriate for VM hostname zones).

| DNS Zone | Linked VNets | Autoregistration |
|---|---|---|
| `privatelink.blob.core.windows.net` | `klc-vnet-scus`, `klc-vnet-mxc`, `klc-vnet-cae` | Disabled |
| `privatelink.vaultcore.azure.net` | `klc-vnet-scus`, `klc-vnet-mxc`, `klc-vnet-cae` | Disabled |

### A Record Setup

A records are automatically created in the linked zone when the private endpoint is provisioned, pointing the service's `privatelink` FQDN to the private IP of the endpoint NIC. Manual A record creation is not required; however, it is possible as a workaround if automation fails.

| DNS Zone | A Record (example) | Value |
|---|---|---|
| `privatelink.blob.core.windows.net` | `klcstoragescus` | `10.1.6.4` |
| `privatelink.blob.core.windows.net` | `klcstoragemxc` | `10.2.6.4` |
| `privatelink.blob.core.windows.net` | `klcstoragecae` | `10.3.6.4` |
| `privatelink.vaultcore.azure.net` | `klc-kv-scus` | `10.1.6.5` |
| `privatelink.vaultcore.azure.net` | `klc-kv-mxc` | `10.2.6.5` |
| `privatelink.vaultcore.azure.net` | `klc-kv-cae` | `10.3.6.5` |

---

## Example Terraform AzAPI

The following HCL demonstrates AzAPI-native resource definitions for VNet, subnets, NSG with rules, and Global VNet peering. All resources target the `klc-rg-kafkalab-scus` resource group. Adjust `parent_id` and `body` for each region.

```hcl
// =====================================================
// Variables
// =====================================================

variable "resource_group_id" {
  description = "Resource ID of klc-rg-kafkalab-scus"
  type        = string
}

variable "location_scus" {
  description = "Primary region"
  type        = string
  default     = "southcentralus"
}

variable "location_mxc" {
  description = "Secondary region"
  type        = string
  default     = "mexicocentral"
}

variable "location_cae" {
  description = "DR region"
  type        = string
  default     = "canadaeast"
}

// =====================================================
// NSG — southcentralus (kafka brokers)
// =====================================================

resource "azapi_resource" "nsg_kafka_brokers_scus" {
  type      = "Microsoft.Network/networkSecurityGroups@2023-09-01"
  name      = "klc-nsg-kafka-brokers-scus"
  parent_id = var.resource_group_id
  location  = var.location_scus

  body = {
    properties = {
      securityRules = [
        {
          name = "Allow-Kafka-Plaintext-Client"
          properties = {
            priority                 = 100
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "Tcp"
            sourcePortRange          = "*"
            destinationPortRange     = "9092"
            sourceAddressPrefixes    = ["10.1.4.0/24", "10.1.5.0/24"]
            destinationAddressPrefix = "10.1.1.0/24"
            description              = "Kafka plaintext client connections from Connect and web-app subnets"
          }
        },
        {
          name = "Allow-Kafka-SSL-Client"
          properties = {
            priority                 = 110
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "Tcp"
            sourcePortRange          = "*"
            destinationPortRange     = "9093"
            sourceAddressPrefixes    = ["10.1.4.0/24", "10.1.5.0/24"]
            destinationAddressPrefix = "10.1.1.0/24"
            description              = "Kafka SSL/SASL_SSL client connections"
          }
        },
        {
          name = "Allow-InterBroker-Replication"
          properties = {
            priority                  = 120
            direction                 = "Inbound"
            access                    = "Allow"
            protocol                  = "Tcp"
            sourcePortRange           = "*"
            destinationPortRanges     = ["9092", "9093"]
            sourceAddressPrefixes     = ["10.1.1.0/24", "10.2.1.0/24", "10.3.1.0/24"]
            destinationAddressPrefix  = "10.1.1.0/24"
            description               = "Inter-broker replication across all regions"
          }
        },
        {
          name = "Deny-All-Inbound"
          properties = {
            priority                 = 4096
            direction                = "Inbound"
            access                   = "Deny"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "*"
            destinationAddressPrefix = "*"
            description              = "Deny all other inbound traffic"
          }
        }
      ]
    }
  }
}

// =====================================================
// VNet — southcentralus
// =====================================================

resource "azapi_resource" "vnet_scus" {
  type      = "Microsoft.Network/virtualNetworks@2023-09-01"
  name      = "klc-vnet-scus"
  parent_id = var.resource_group_id
  location  = var.location_scus

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.1.0.0/16"]
      }
    }
  }
}

// =====================================================
// Subnets — southcentralus
// =====================================================

resource "azapi_resource" "snet_kafka_brokers_scus" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-09-01"
  name      = "snet-kafka-brokers"
  parent_id = azapi_resource.vnet_scus.id

  body = {
    properties = {
      addressPrefix = "10.1.1.0/24"
      networkSecurityGroup = {
        id = azapi_resource.nsg_kafka_brokers_scus.id
      }
    }
  }
}

resource "azapi_resource" "snet_private_endpoints_scus" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-09-01"
  name      = "snet-private-endpoints"
  parent_id = azapi_resource.vnet_scus.id

  body = {
    properties = {
      addressPrefix = "10.1.6.0/24"
      // Enable NSG and UDR enforcement on private endpoint NICs (API 2023-05-01+)
      privateEndpointNetworkPolicies = "NetworkSecurityGroupEnabled"
    }
  }

  depends_on = [azapi_resource.snet_kafka_brokers_scus]
}

// =====================================================
// Global VNet Peering — scus → mxc (example pair)
// =====================================================

// klc-vnet-mxc is declared in a separate module

resource "azapi_resource" "peering_scus_to_mxc" {
  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01"
  name      = "scus-to-mxc"
  parent_id = azapi_resource.vnet_scus.id

  body = {
    properties = {
      remoteVirtualNetwork = {
        id = azapi_resource.vnet_mxc.id
      }
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      useRemoteGateways         = false
    }
  }
}

resource "azapi_resource" "peering_mxc_to_scus" {
  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01"
  name      = "mxc-to-scus"
  parent_id = azapi_resource.vnet_mxc.id

  body = {
    properties = {
      remoteVirtualNetwork = {
        id = azapi_resource.vnet_scus.id
      }
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      useRemoteGateways         = false
    }
  }
}

// =====================================================
// Private DNS Zone — Blob Storage
// =====================================================

resource "azapi_resource" "private_dns_zone_blob" {
  type      = "Microsoft.Network/privateDnsZones@2020-06-01"
  name      = "privatelink.blob.core.windows.net"
  parent_id = var.resource_group_id
  location  = "global"
  body      = {}
}

// VNet link — scus
resource "azapi_resource" "dns_link_blob_scus" {
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  name      = "link-blob-scus"
  parent_id = azapi_resource.private_dns_zone_blob.id
  location  = "global"

  body = {
    properties = {
      virtualNetwork = {
        id = azapi_resource.vnet_scus.id
      }
      registrationEnabled = false
    }
  }
}

// VNet link — mxc (repeat pattern for cae)
resource "azapi_resource" "dns_link_blob_mxc" {
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  name      = "link-blob-mxc"
  parent_id = azapi_resource.private_dns_zone_blob.id
  location  = "global"

  body = {
    properties = {
      virtualNetwork = {
        id = azapi_resource.vnet_mxc.id
      }
      registrationEnabled = false
    }
  }
}

// =====================================================
// Private DNS Zone — Key Vault
// =====================================================

resource "azapi_resource" "private_dns_zone_kv" {
  type      = "Microsoft.Network/privateDnsZones@2020-06-01"
  name      = "privatelink.vaultcore.azure.net"
  parent_id = var.resource_group_id
  location  = "global"
  body      = {}
}

resource "azapi_resource" "dns_link_kv_scus" {
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  name      = "link-kv-scus"
  parent_id = azapi_resource.private_dns_zone_kv.id
  location  = "global"

  body = {
    properties = {
      virtualNetwork = {
        id = azapi_resource.vnet_scus.id
      }
      registrationEnabled = false
    }
  }
}
```

---

## References

- Azure Virtual Network overview: <https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview>
- Azure VNet Peering overview: <https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview>
- Azure Private Endpoint overview: <https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview>
- Azure Private Endpoint DNS configuration: <https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns>
- Azure Private DNS overview: <https://learn.microsoft.com/en-us/azure/dns/private-dns-overview>
- Network Security Groups overview: <https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview>
- AzAPI provider — VirtualNetworks resource: <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/Microsoft.Network_virtualNetworks>
- AzAPI provider overview: <https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider>
- Hub-and-spoke topology in Azure: <https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke>
- Confluent Platform networking — port reference: <https://docs.confluent.io/operator/current/co-networking-overview.html>
- Apache Kafka listener configuration: <https://kafka.apache.org/documentation/#brokerconfigs_listeners>
- Azure naming conventions (CAF): <https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming>
