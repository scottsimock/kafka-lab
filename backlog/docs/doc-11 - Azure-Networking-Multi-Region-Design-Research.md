---
id: doc-11
title: Azure Networking Multi-Region Design Research
type: other
created_date: '2026-03-28 18:31'
---
# Azure Networking Multi-Region Design Research

## Summary

This document defines the Azure networking architecture for the Kafka Lab multi-region deployment of Confluent Platform 7.x (ZooKeeper-based) across three Azure regions: southcentralus (primary), mexicocentral (secondary), and canadaeast (DR). The design uses Global VNet Peering for cross-region connectivity, private IPs exclusively for all Confluent components (no public endpoints), and a single Azure Private DNS Zone linked to all regional VNets for consistent Kafka broker hostname resolution. NSG rules enforce least-privilege network segmentation across five subnet tiers per region: Kafka brokers, ZooKeeper, Schema Registry, Kafka Connect, and management.

## Key Findings

- **Global VNet Peering** is the recommended cross-region connectivity method for Cluster Linking traffic. It provides low-latency (~30–50 ms round-trip between the three regions), high-bandwidth connectivity over the Azure backbone without requiring gateway infrastructure. VNet peering is non-transitive — each region pair requires its own peering relationship.
- **Cross-region latency estimates**: southcentralus ↔ mexicocentral ~30–50 ms; southcentralus ↔ canadaeast ~30–40 ms; canadaeast ↔ mexicocentral ~50 ms. All are well within the <100 ms threshold recommended for Cluster Linking.
- **Global VNet peering cost**: $0.035/GB inbound + $0.035/GB outbound (Zone 1 pricing), totaling $0.07/GB transferred between any two peered VNets.
- **Azure Private DNS Zones** can be linked to VNets across multiple regions (up to 1,000 VNet links per zone). A single global private DNS zone (e.g., `kafka.internal`) linked to all three regional VNets provides seamless cross-region broker hostname resolution without manual DNS synchronization.
- **Kafka advertised.listeners** must be configured with FQDNs registered in the Private DNS Zone (not raw IPs) so that cross-region Cluster Linking and clients can resolve brokers to their private IPs regardless of originating region.
- **Confluent Platform 7.x enables Cluster Linking by default** — no `confluent.cluster.link.enable=true` is needed. Cluster links are created on the destination cluster, initiating TCP connections to the source cluster's Kafka listener port.
- **All Confluent components must use private IPs only**. No public endpoints are permitted per project requirements. NSGs enforce traffic flow between specific subnet tiers.
- **Separate subnets per tier** provide network isolation and enable granular NSG rules. Each subnet is sized to accommodate the initial deployment plus growth headroom.

## Architecture / Design Decisions

### Decision 1: Global VNet Peering over VPN Gateway or ExpressRoute

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| Global VNet Peering | Low latency (~30–50 ms), high bandwidth (10–100+ Gbps), no gateway infrastructure, simple setup, Azure backbone | Non-transitive (needs peering per pair), no built-in encryption at network layer | **Selected** |
| VPN Gateway | Encrypted tunnel, supports transitive routing via hub | Higher latency (~5–15 ms overhead), limited to ~1.25 Gbps (VpnGw1), gateway cost | Rejected |
| ExpressRoute | Dedicated circuit, predictable latency, high bandwidth | Expensive, requires telco provisioning, overkill for Azure-to-Azure | Rejected |

**Rationale**: The Kafka Lab is purely Azure-to-Azure with no on-premises connectivity requirement. Global VNet Peering provides the best latency/bandwidth at the lowest cost and complexity. Kafka traffic is encrypted at the application layer (TLS 1.2+) via `SASL_SSL` listeners, making VPN tunnel encryption redundant. Three peering relationships are required: scus↔mxc, scus↔cae, mxc↔cae.

### Decision 2: Private IPs Only — No Public Endpoints

All Confluent components (brokers, ZooKeeper, Schema Registry, Connect) run on Ubuntu 22.04 VMs with private IPs only. `public_network_access_enabled = false` is enforced on all resources. The web application front door is the sole public-facing resource per project requirements.

**Rationale**: Eliminates attack surface. Cross-region communication uses VNet peering over the Azure backbone. Management access is through a bastion host in the management subnet.

### Decision 3: Single Global Private DNS Zone

A single Azure Private DNS Zone (`kafka.internal`) is linked to all three regional VNets. Broker A records resolve to private IPs (e.g., `broker-0.scus.kafka.internal` → `10.1.1.4`). This avoids the complexity of regional DNS zone synchronization and enables seamless Cluster Linking hostname resolution across regions.

**Rationale**: Simplest model for active-active + DR. Failover does not require DNS zone reconfiguration. The limit of 1,000 VNet links per zone is more than sufficient.

### Decision 4: Subnet-per-Tier Isolation

Each region deploys five dedicated subnets, one per Confluent component tier plus management. NSGs are applied at the subnet level for uniform enforcement. This enables:

- Granular port-level controls between tiers (e.g., only broker subnet can reach ZooKeeper on 2181)
- Independent scaling of each tier
- Clear blast radius containment

## Configuration Reference

### VNet and Subnet CIDR Allocation

Each region is assigned a `/16` VNet from the `10.0.0.0/8` private range. Subnets use `/24` blocks providing 251 usable IPs each (more than sufficient for 3 brokers + growth).

#### southcentralus (Primary)

| Subnet | CIDR | Purpose | Initial Hosts |
|---|---|---|---|
| `snet-kafka-brokers-scus` | `10.1.1.0/24` | Kafka brokers | 3 |
| `snet-zookeeper-scus` | `10.1.2.0/24` | ZooKeeper ensemble | 3 |
| `snet-schema-registry-scus` | `10.1.3.0/24` | Schema Registry | 2 |
| `snet-kafka-connect-scus` | `10.1.4.0/24` | Kafka Connect workers | 2 |
| `snet-management-scus` | `10.1.10.0/24` | Bastion, monitoring, jumpbox | 2 |

**VNet**: `vnet-kafka-scus` — `10.1.0.0/16`

#### mexicocentral (Secondary)

| Subnet | CIDR | Purpose | Initial Hosts |
|---|---|---|---|
| `snet-kafka-brokers-mxc` | `10.2.1.0/24` | Kafka brokers | 3 |
| `snet-zookeeper-mxc` | `10.2.2.0/24` | ZooKeeper ensemble | 3 |
| `snet-schema-registry-mxc` | `10.2.3.0/24` | Schema Registry | 2 |
| `snet-kafka-connect-mxc` | `10.2.4.0/24` | Kafka Connect workers | 2 |
| `snet-management-mxc` | `10.2.10.0/24` | Bastion, monitoring, jumpbox | 2 |

**VNet**: `vnet-kafka-mxc` — `10.2.0.0/16`

#### canadaeast (DR)

| Subnet | CIDR | Purpose | Initial Hosts |
|---|---|---|---|
| `snet-kafka-brokers-cae` | `10.3.1.0/24` | Kafka brokers | 3 |
| `snet-zookeeper-cae` | `10.3.2.0/24` | ZooKeeper ensemble | 3 |
| `snet-schema-registry-cae` | `10.3.3.0/24` | Schema Registry | 2 |
| `snet-kafka-connect-cae` | `10.3.4.0/24` | Kafka Connect workers | 2 |
| `snet-management-cae` | `10.3.10.0/24` | Bastion, monitoring, jumpbox | 2 |

**VNet**: `vnet-kafka-cae` — `10.3.0.0/16`

### NSG Rules

NSGs are applied at the subnet level. Rules below use subnet CIDR references. "Cross-region broker subnets" refers to broker subnets in peered VNets (e.g., for scus: `10.2.1.0/24` and `10.3.1.0/24`).

#### Kafka Broker Subnet NSG (`nsg-kafka-brokers-{region}`)

| Priority | Name | Direction | Port | Protocol | Source | Destination | Action | Purpose |
|---|---|---|---|---|---|---|---|---|
| 100 | AllowInterBrokerSASL | Inbound | 9093 | TCP | Broker subnet (local) | Broker subnet (local) | Allow | Inter-broker replication (SASL_SSL) |
| 110 | AllowInterBrokerCrossRegion | Inbound | 9093 | TCP | Cross-region broker subnets | Broker subnet (local) | Allow | Cross-region Cluster Linking |
| 120 | AllowClientSASL | Inbound | 9093 | TCP | Schema Registry + Connect + Mgmt subnets | Broker subnet (local) | Allow | Client connections (SASL_SSL) |
| 130 | AllowInternalPlaintext | Inbound | 9092 | TCP | Broker subnet (local) | Broker subnet (local) | Allow | Internal inter-broker (PLAINTEXT for metrics) |
| 200 | AllowZookeeperOutbound | Outbound | 2181 | TCP | Broker subnet | ZooKeeper subnet (local) | Allow | Broker → ZooKeeper client connections |
| 300 | AllowSSHFromMgmt | Inbound | 22 | TCP | Management subnet | Broker subnet | Allow | SSH administration |
| 900 | AllowJMXFromMgmt | Inbound | 9999 | TCP | Management subnet | Broker subnet | Allow | JMX monitoring |
| 910 | AllowNodeExporter | Inbound | 9100 | TCP | Management subnet | Broker subnet | Allow | Prometheus node_exporter |
| 4096 | DenyAllInbound | Inbound | * | * | * | * | Deny | Default deny |

#### ZooKeeper Subnet NSG (`nsg-zookeeper-{region}`)

| Priority | Name | Direction | Port | Protocol | Source | Destination | Action | Purpose |
|---|---|---|---|---|---|---|---|---|
| 100 | AllowZKClient | Inbound | 2181 | TCP | Broker subnet (local) | ZK subnet | Allow | Kafka broker → ZK client port |
| 110 | AllowZKPeer | Inbound | 2888 | TCP | ZK subnet (local) | ZK subnet | Allow | ZK peer-to-peer replication |
| 120 | AllowZKElection | Inbound | 3888 | TCP | ZK subnet (local) | ZK subnet | Allow | ZK leader election |
| 300 | AllowSSHFromMgmt | Inbound | 22 | TCP | Management subnet | ZK subnet | Allow | SSH administration |
| 900 | AllowJMXFromMgmt | Inbound | 9999 | TCP | Management subnet | ZK subnet | Allow | JMX monitoring |
| 4096 | DenyAllInbound | Inbound | * | * | * | * | Deny | Default deny |

#### Schema Registry Subnet NSG (`nsg-schema-registry-{region}`)

| Priority | Name | Direction | Port | Protocol | Source | Destination | Action | Purpose |
|---|---|---|---|---|---|---|---|---|
| 100 | AllowSchemaRegistryHTTPS | Inbound | 8081 | TCP | Connect + Mgmt subnets | SR subnet | Allow | Schema Registry REST API |
| 110 | AllowSchemaRegistryCrossRegion | Inbound | 8081 | TCP | Cross-region SR subnets | SR subnet | Allow | Schema Registry leader-follower |
| 200 | AllowBrokerOutbound | Outbound | 9093 | TCP | SR subnet | Broker subnet (local) | Allow | SR → Kafka (SASL_SSL) for _schemas topic |
| 300 | AllowSSHFromMgmt | Inbound | 22 | TCP | Management subnet | SR subnet | Allow | SSH administration |
| 4096 | DenyAllInbound | Inbound | * | * | * | * | Deny | Default deny |

#### Kafka Connect Subnet NSG (`nsg-kafka-connect-{region}`)

| Priority | Name | Direction | Port | Protocol | Source | Destination | Action | Purpose |
|---|---|---|---|---|---|---|---|---|
| 100 | AllowConnectREST | Inbound | 8083 | TCP | Management subnet | Connect subnet | Allow | Connect REST API |
| 200 | AllowBrokerOutbound | Outbound | 9093 | TCP | Connect subnet | Broker subnet (local) | Allow | Connect → Kafka (SASL_SSL) |
| 210 | AllowSchemaRegistryOutbound | Outbound | 8081 | TCP | Connect subnet | SR subnet (local) | Allow | Connect → Schema Registry |
| 300 | AllowSSHFromMgmt | Inbound | 22 | TCP | Management subnet | Connect subnet | Allow | SSH administration |
| 4096 | DenyAllInbound | Inbound | * | * | * | * | Deny | Default deny |

#### Management Subnet NSG (`nsg-management-{region}`)

| Priority | Name | Direction | Port | Protocol | Source | Destination | Action | Purpose |
|---|---|---|---|---|---|---|---|---|
| 100 | AllowBastionInbound | Inbound | 443 | TCP | AzureBastionSubnet | Mgmt subnet | Allow | Azure Bastion → jumpbox |
| 4096 | DenyAllInbound | Inbound | * | * | * | * | Deny | Default deny |

### Confluent Platform Port Reference

| Component | Port | Protocol | Listener Name | Purpose |
|---|---|---|---|---|
| Kafka Broker | 9092 | TCP | INTERNAL | Inter-broker (PLAINTEXT, internal metrics only) |
| Kafka Broker | 9093 | TCP | BROKER | Inter-broker replication + client access (SASL_SSL) |
| Kafka Broker | 9093 | TCP | REPLICATION | Cluster Linking cross-region (SASL_SSL, same port as BROKER) |
| ZooKeeper | 2181 | TCP | — | Client connections from brokers |
| ZooKeeper | 2888 | TCP | — | Peer-to-peer replication |
| ZooKeeper | 3888 | TCP | — | Leader election |
| Schema Registry | 8081 | TCP (HTTPS) | — | REST API |
| Kafka Connect | 8083 | TCP (HTTPS) | — | REST API |
| JMX (all components) | 9999 | TCP | — | JMX monitoring |
| Node Exporter | 9100 | TCP | — | Prometheus metrics |

### Kafka Broker Listener Configuration

Each broker uses two listeners: `INTERNAL` for intra-cluster metrics (PLAINTEXT, bound to the local broker subnet) and `BROKER` for all client and cross-region traffic (SASL_SSL, accessible from all authorized subnets and peered VNets).

#### server.properties — Broker 0 in southcentralus (example)

```properties
// Listener bindings — bind to all interfaces, differentiate by port
listeners=INTERNAL://0.0.0.0:9092,BROKER://0.0.0.0:9093

// Advertised listeners — use FQDNs registered in Private DNS Zone
// Each broker advertises its unique FQDN so clients and Cluster Linking
// resolve to the correct private IP via the shared kafka.internal DNS zone
advertised.listeners=INTERNAL://broker-0.scus.kafka.internal:9092,BROKER://broker-0.scus.kafka.internal:9093

// Security protocol mapping
listener.security.protocol.map=INTERNAL:PLAINTEXT,BROKER:SASL_SSL

// Inter-broker communication uses the BROKER listener (encrypted)
inter.broker.listener.name=BROKER

// SASL configuration for BROKER listener
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-512
```

#### Cluster Linking Configuration — link-scus-to-mxc.properties (on destination cluster)

```properties
// Source cluster bootstrap servers (southcentralus brokers via Private DNS)
bootstrap.servers=broker-0.scus.kafka.internal:9093,broker-1.scus.kafka.internal:9093,broker-2.scus.kafka.internal:9093

// Security for the link connection
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="cluster-link-user" \
  password="<from-key-vault>";

// TLS configuration
ssl.truststore.location=/etc/kafka/ssl/truststore.jks
ssl.truststore.password=<from-key-vault>
```

### Private DNS Zone Configuration

#### Zone: `kafka.internal`

| Record | Type | Value | Region |
|---|---|---|---|
| `broker-0.scus.kafka.internal` | A | `10.1.1.4` | southcentralus |
| `broker-1.scus.kafka.internal` | A | `10.1.1.5` | southcentralus |
| `broker-2.scus.kafka.internal` | A | `10.1.1.6` | southcentralus |
| `broker-0.mxc.kafka.internal` | A | `10.2.1.4` | mexicocentral |
| `broker-1.mxc.kafka.internal` | A | `10.2.1.5` | mexicocentral |
| `broker-2.mxc.kafka.internal` | A | `10.2.1.6` | mexicocentral |
| `broker-0.cae.kafka.internal` | A | `10.3.1.4` | canadaeast |
| `broker-1.cae.kafka.internal` | A | `10.3.1.5` | canadaeast |
| `broker-2.cae.kafka.internal` | A | `10.3.1.6` | canadaeast |
| `zk-0.scus.kafka.internal` | A | `10.1.2.4` | southcentralus |
| `zk-1.scus.kafka.internal` | A | `10.1.2.5` | southcentralus |
| `zk-2.scus.kafka.internal` | A | `10.1.2.6` | southcentralus |
| `zk-0.mxc.kafka.internal` | A | `10.2.2.4` | mexicocentral |
| `zk-1.mxc.kafka.internal` | A | `10.2.2.5` | mexicocentral |
| `zk-2.mxc.kafka.internal` | A | `10.2.2.6` | mexicocentral |
| `zk-0.cae.kafka.internal` | A | `10.3.2.4` | canadaeast |
| `zk-1.cae.kafka.internal` | A | `10.3.2.5` | canadaeast |
| `zk-2.cae.kafka.internal` | A | `10.3.2.6` | canadaeast |
| `schema-registry.scus.kafka.internal` | A | `10.1.3.4` | southcentralus |
| `schema-registry.mxc.kafka.internal` | A | `10.2.3.4` | mexicocentral |
| `schema-registry.cae.kafka.internal` | A | `10.3.3.4` | canadaeast |
| `connect.scus.kafka.internal` | A | `10.1.4.4` | southcentralus |
| `connect.mxc.kafka.internal` | A | `10.2.4.4` | mexicocentral |
| `connect.cae.kafka.internal` | A | `10.3.4.4` | canadaeast |

The Private DNS Zone is linked to all three VNets with auto-registration disabled (records managed by Terraform).

### Terraform Reference — VNet Peering (southcentralus ↔ mexicocentral)

```hcl
// =====================================================
// Global VNet Peering: southcentralus ↔ mexicocentral
// =====================================================

resource "azurerm_virtual_network_peering" "scus_to_mxc" {
  name                         = "peer-scus-to-mxc"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.scus.name
  remote_virtual_network_id    = azurerm_virtual_network.mxc.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "mxc_to_scus" {
  name                         = "peer-mxc-to-scus"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.mxc.name
  remote_virtual_network_id    = azurerm_virtual_network.scus.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
```

### Terraform Reference — Private DNS Zone and VNet Links

```hcl
// =====================================================
// Private DNS Zone for Kafka broker hostname resolution
// =====================================================

resource "azurerm_private_dns_zone" "kafka" {
  name                = "kafka.internal"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kafka_scus" {
  name                  = "link-kafka-dns-scus"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.kafka.name
  virtual_network_id    = azurerm_virtual_network.scus.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "kafka_mxc" {
  name                  = "link-kafka-dns-mxc"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.kafka.name
  virtual_network_id    = azurerm_virtual_network.mxc.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "kafka_cae" {
  name                  = "link-kafka-dns-cae"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.kafka.name
  virtual_network_id    = azurerm_virtual_network.cae.id
  registration_enabled  = false
}
```

### Terraform Reference — Broker Subnet NSG (southcentralus)

```hcl
// =====================================================
// NSG for Kafka Broker Subnet — southcentralus
// =====================================================

resource "azurerm_network_security_group" "kafka_brokers_scus" {
  name                = "nsg-kafka-brokers-scus"
  location            = "southcentralus"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "broker_inter_broker_sasl" {
  name                        = "AllowInterBrokerSASL"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9093"
  source_address_prefix       = "10.1.1.0/24"
  destination_address_prefix  = "10.1.1.0/24"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.kafka_brokers_scus.name
}

resource "azurerm_network_security_rule" "broker_cross_region_mxc" {
  name                        = "AllowCrossRegionMxc"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9093"
  source_address_prefix       = "10.2.1.0/24"
  destination_address_prefix  = "10.1.1.0/24"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.kafka_brokers_scus.name
}

resource "azurerm_network_security_rule" "broker_cross_region_cae" {
  name                        = "AllowCrossRegionCae"
  priority                    = 115
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9093"
  source_address_prefix       = "10.3.1.0/24"
  destination_address_prefix  = "10.1.1.0/24"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.kafka_brokers_scus.name
}

resource "azurerm_network_security_rule" "broker_client_sasl" {
  name                        = "AllowClientSASL"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9093"
  source_address_prefixes     = ["10.1.3.0/24", "10.1.4.0/24", "10.1.10.0/24"]
  destination_address_prefix  = "10.1.1.0/24"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.kafka_brokers_scus.name
}

resource "azurerm_network_security_rule" "broker_ssh_mgmt" {
  name                        = "AllowSSHFromMgmt"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "10.1.10.0/24"
  destination_address_prefix  = "10.1.1.0/24"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.kafka_brokers_scus.name
}

resource "azurerm_network_security_rule" "broker_deny_all" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.kafka_brokers_scus.name
}

resource "azurerm_subnet_network_security_group_association" "kafka_brokers_scus" {
  subnet_id                 = azurerm_subnet.kafka_brokers_scus.id
  network_security_group_id = azurerm_network_security_group.kafka_brokers_scus.id
}
```

## Risks and Open Questions

1. **VNet peering is non-transitive**: If future architecture requires spoke-to-spoke routing through a hub, the flat peering model must be refactored to hub-and-spoke with Azure Firewall or NVA for transit. Current three-way peering works for the three-region design.

2. **Global VNet peering does not encrypt at the network layer**: Traffic between peered VNets traverses the Azure backbone unencrypted at L3. This is mitigated by Kafka's SASL_SSL listeners (TLS 1.2+) encrypting all data in transit at the application layer. If regulatory requirements mandate network-layer encryption, VPN Gateway would be needed (at the cost of latency and throughput).

3. **Static DNS records require Terraform management**: Broker DNS A records are statically assigned in the Private DNS Zone. If a broker VM is replaced and receives a new private IP (e.g., during VM scale set replacement), the DNS record must be updated. Consider auto-registration or a Terraform lifecycle approach with `create_before_destroy` to avoid stale records.

4. **ZooKeeper ensemble is region-local only**: Each region runs its own 3-node ZooKeeper ensemble. Cross-region ZooKeeper communication is not configured because Confluent Platform ZooKeeper ensembles are per-cluster. This is correct for the architecture but means each region's Kafka cluster is an independent cluster linked via Cluster Linking, not a single stretched cluster.

5. **Cross-region data transfer costs**: At $0.07/GB, high-throughput Cluster Linking replication (e.g., 100 GB/day between scus and mxc) would cost ~$7/day or ~$210/month. Monitor replication throughput and set budget alerts.

6. **mexicocentral availability zones**: mexicocentral is a newer Azure region. Verify current availability zone support for all required VM SKUs before deployment. Fall back to availability sets if AZ support is limited.

7. **Cluster Linking RPO during network partition**: If VNet peering connectivity between regions is disrupted, Cluster Linking replication will pause and resume when connectivity restores. The RPO during a partition equals the duration of the outage plus replication lag catch-up time. No automatic failover of producers to the secondary cluster is included in this design.

8. **NSG rule maintenance**: With three regions × five subnets × multiple rules each, NSG management complexity is significant. Consider using Azure Network Security Group application security groups (ASGs) or Terraform modules to reduce duplication.

## References

- [Azure Virtual Network Peering Overview](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)
- [Azure Virtual Networks Overview](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
- [Azure Availability Zones Overview](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
- [Azure Private DNS Zone Overview](https://learn.microsoft.com/en-us/azure/dns/private-dns-privatednszone)
- [Azure Network Round-Trip Latency Statistics](https://learn.microsoft.com/en-us/azure/networking/azure-network-latency)
- [Virtual Network Pricing](https://azure.microsoft.com/en-us/pricing/details/virtual-network/)
- [Confluent Platform — Configure Kafka Listeners](https://docs.confluent.io/platform/current/kafka/listeners.html)
- [Confluent — Kafka Listeners Explained](https://www.confluent.io/blog/kafka-listeners-explained/)
- [Confluent Platform — Cluster Linking](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/index.html)
- [Confluent Platform — Cluster Linking Configuration](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html)
- [Confluent Platform — Multi-Region Architectures](https://docs.confluent.io/platform/current/multi-dc-deployments/multi-region-architectures.html)
- [Azure Architecture — Virtual Network Peering Connectivity Options](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/virtual-network-peering)
- [Azure Cross-Region Data Landing Zone Connectivity](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/cloud-scale-analytics/eslz-network-considerations-cross-region)
- [Confluent — Cluster Linking for Azure Private Link](https://www.confluent.io/blog/cluster-linking-for-azure-private-link-is-now-available-in-confluent-cloud/)
- [Azure Multi-Region Private DNS Options](https://mikeguy.co.uk/posts/azure-multiregion-pdns/)
- [Azure Private Link Multi-Region Architecture](https://github.com/adstuart/azure-privatelink-multiregion)
