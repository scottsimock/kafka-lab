---
id: doc-3
title: Confluent Platform 7.x Architecture Research
type: other
created_date: '2026-03-28 18:23'
---
## Summary

Confluent Platform 7.x is a full-featured streaming platform built around Apache Kafka, with ZooKeeper providing cluster coordination in the ZK-based deployment mode. For the Kafka Lab's multi-region resilience topology (southcentralus/mexicocentral/canadaeast), the strictly required components are Kafka brokers, ZooKeeper, and Cluster Linking. Schema Registry, Connect, and Control Center are strongly recommended for a realistic resilience lab but can each tolerate single-node deployment per region without compromising the primary research goals. A 3-node ZooKeeper ensemble per region paired with 3 Kafka brokers across availability zones provides quorum-based fault tolerance and is the minimum recommended topology for meaningful chaos testing.

## Key Findings

### Component Inventory and Roles

- **Kafka Brokers** — Core data plane. Receive, store, replicate, and serve streaming records via topics and partitions. Each region runs 3 brokers spread across availability zones. Brokers handle producer/consumer traffic, inter-broker replication, and controller election.
- **ZooKeeper** — Cluster coordination. Manages broker metadata, partition leader election, topic configuration, and ACLs. Required for Confluent Platform 7.x in ZK-based mode. Must run on dedicated nodes, never co-located with brokers.
- **Schema Registry** — Schema governance. Centralized Avro/Protobuf/JSON Schema management with compatibility enforcement. Uses leader-follower model with Kafka-based leader election (no ZK dependency for SR leader election in CP 7.x). Stores schemas in the `_schemas` internal topic.
- **Kafka Connect** — Integration framework. Source and sink connectors bridge Kafka with external systems. Runs in distributed mode for HA with task rebalancing across workers. Stores state in `_connect-offsets`, `_connect-configs`, and `_connect-status` internal topics.
- **Cluster Linking** — Cross-cluster replication. Byte-for-byte topic mirroring with offset preservation between clusters. Essential for the multi-region DR topology. No additional infrastructure required — runs within Kafka brokers natively. Supports active-passive and active-active patterns.
- **Control Center** — Monitoring and management UI. Aggregates metrics from all components via the Confluent Metrics Reporter. Provides dashboards, consumer lag tracking, alerting, and connector management. Stores metrics in `_confluent-metrics` and `_confluent-command` internal topics.

### Required vs Optional Components for the Resilience Lab

| Component | Required? | Justification |
|---|---|---|
| Kafka Brokers (3/region) | **Required** | Core data plane; primary target for chaos experiments |
| ZooKeeper (3/region) | **Required** | Cluster coordination; single point of failure if undersized |
| Cluster Linking | **Required** | Cross-region replication for DR failover testing |
| Schema Registry | **Recommended** | Validates schema compat during failover; 1 node/region OK in lab |
| Kafka Connect | **Recommended** | Tests data pipeline resilience; 1 worker/region OK in lab |
| Control Center | **Recommended** | Observability during chaos experiments; 1 node in primary only |

### HA Requirements per Component

| Component | Production HA | Lab Minimum | Notes |
|---|---|---|---|
| Kafka Brokers | 3+ per cluster, RF=3 | 3 per region (AZ-spread) | min.insync.replicas=2 for durability |
| ZooKeeper | 3 or 5 node ensemble | 3 per region | Quorum=2, tolerates 1 failure |
| Schema Registry | 2+ (leader-follower) | 1 per region | Follower auto-promotes; single-node OK for lab |
| Kafka Connect | 2+ workers (distributed) | 1 per region | Task rebalance on failure; standalone OK for lab |
| Control Center | 1 (not HA natively) | 1 in primary region | Stateful; data persists in Kafka topics |
| Cluster Linking | Runs on brokers | N/A (broker-embedded) | No separate nodes needed |

### ZooKeeper + 3-Broker Topology

A 3-node ZooKeeper ensemble with 3 Kafka brokers provides:

- **Quorum**: 2 of 3 ZK nodes must agree (tolerates 1 ZK node failure)
- **Broker coordination**: All 3 brokers connect to the ZK ensemble for metadata, leader election, and configuration
- **AZ spread**: Each ZK node and each broker in a separate availability zone within the region

### Inter-Component Communication Patterns

```text
                    ┌─────────────────────────────────────────────────┐
                    │              ZooKeeper Ensemble                  │
                    │   ZK-1 (:2181)  ZK-2 (:2181)  ZK-3 (:2181)    │
                    │       ↔ :2888 (peer)  ↔ :3888 (election)       │
                    └──────────────────┬──────────────────────────────┘
                                       │ :2181 (client)
                    ┌──────────────────▼──────────────────────────────┐
                    │              Kafka Brokers                       │
                    │   B-1 (:9092/9093)  B-2 (:9092/9093)           │
                    │   B-3 (:9092/9093)                              │
                    │   ↔ :9092 (inter-broker replication)            │
                    │   → Cluster Linking (embedded, :9092)           │
                    └──┬────────────┬────────────┬────────────────────┘
                       │            │            │
              :9092    │    :9092   │    :9092   │
                       ▼            ▼            ▼
              ┌────────────┐ ┌───────────┐ ┌──────────────┐
              │  Schema    │ │  Kafka    │ │   Control    │
              │  Registry  │ │  Connect  │ │   Center     │
              │  (:8081)   │ │  (:8083)  │ │   (:9021)    │
              └────────────┘ └─────┬─────┘ └──────────────┘
                       ▲           │
                       │  :8081    │
                       └───────────┘
                  (Connect → SR for Avro)
```

### Port Map

| Port | Protocol | Component | Purpose |
|---|---|---|---|
| 2181 | TCP | ZooKeeper | Client connections (brokers → ZK) |
| 2888 | TCP | ZooKeeper | Peer-to-peer communication |
| 3888 | TCP | ZooKeeper | Leader election |
| 9092 | TCP | Kafka Broker | PLAINTEXT client + inter-broker |
| 9093 | TCP | Kafka Broker | TLS/SSL client connections |
| 9091 | TCP | Kafka Broker | Inter-broker (if separate listener) |
| 8081 | TCP | Schema Registry | REST API |
| 8083 | TCP | Kafka Connect | REST API |
| 9021 | TCP | Control Center | Web UI |
| 8082 | TCP | REST Proxy | REST API (optional) |
| 8088 | TCP | ksqlDB | REST API (optional) |
| 9999 | TCP | All (JMX) | JMX monitoring (optional) |

### Internal Kafka Topics

| Topic | Component | Purpose |
|---|---|---|
| `_schemas` | Schema Registry | Schema storage and versioning |
| `_connect-offsets` | Kafka Connect | Source connector offset tracking |
| `_connect-configs` | Kafka Connect | Connector configuration storage |
| `_connect-status` | Kafka Connect | Connector and task status |
| `_confluent-metrics` | Metrics Reporter | Cluster metrics for Control Center |
| `_confluent-command` | Control Center | Control plane commands |
| `_confluent-controlcenter-*` | Control Center | Internal state and aggregation |
| `__consumer_offsets` | Kafka Brokers | Consumer group offset management |

## Architecture / Design Decisions

### Decision 1: 3-Node ZooKeeper Ensemble per Region

**Decision**: Deploy a 3-node ZooKeeper ensemble in each region (southcentralus, mexicocentral, canadaeast).

**Rationale**: A 3-node ensemble provides quorum-based fault tolerance (survives 1 node failure). A single ZK node is a single point of failure that would prevent meaningful chaos testing. Five nodes are unnecessary for a 3-broker lab cluster and add cost without proportional benefit.

**Topology per region**:

```text
Region: southcentralus
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   ZK Node 1 │  │   ZK Node 2 │  │   ZK Node 3 │
│   (Zone 1)  │  │   (Zone 2)  │  │   (Zone 1)  │
│  :2181/2888 │  │  :2181/2888 │  │  :2181/2888 │
│  /3888      │  │  /3888      │  │  /3888      │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │ :2181
┌─────────────┐  ┌──────┴──────┐  ┌─────────────┐
│  Broker 1   │  │  Broker 2   │  │  Broker 3   │
│  (Zone 1)   │  │  (Zone 2)   │  │  (Zone 1)   │
│  :9092/9093 │  │  :9092/9093 │  │  :9092/9093 │
└─────────────┘  └─────────────┘  └─────────────┘
```

**Note on AZ distribution**: southcentralus has 2 AZs available per the Azure environment spec. Brokers and ZK nodes are spread across Zone 1 and Zone 2 in a 2-1 pattern. mexicocentral and canadaeast each have 1 AZ, so all nodes in those regions run in Zone 1 with VM-level fault domains providing separation.

### Decision 2: Co-located Ancillary Components on Shared VMs in Lab

**Decision**: In the lab environment, Schema Registry, Kafka Connect (1 worker), and Control Center can share VMs or be co-located with each other (but never with ZooKeeper or Kafka brokers).

**Rationale**: These components are lightweight in a lab context. Schema Registry and Connect are stateless (state lives in Kafka topics). Co-location reduces VM count and cost. Brokers and ZooKeeper must remain on dedicated VMs due to I/O sensitivity and the need for isolated chaos testing.

### Decision 3: Cluster Linking for Cross-Region Replication

**Decision**: Use Confluent Cluster Linking (not MirrorMaker 2 or Confluent Replicator) for cross-region topic mirroring.

**Rationale**: Cluster Linking is built into Confluent Server (no additional infrastructure), provides byte-for-byte replication with offset preservation, and supports atomic failover. It is the recommended approach for DR in Confluent Platform 7.x. The active-passive pattern (southcentralus → mexicocentral, southcentralus → canadaeast) aligns with the lab's multi-region topology.

### Decision 4: Single-Node Schema Registry per Region

**Decision**: Deploy 1 Schema Registry instance per region for the lab.

**Rationale**: Schema Registry uses a leader-follower model. In a lab context, a single instance per region is sufficient. If the instance fails, it restarts quickly since state is persisted in the `_schemas` Kafka topic. Multi-node SR adds complexity without meaningful benefit for chaos testing focused on broker/ZK resilience.

### Decision 5: Control Center in Primary Region Only

**Decision**: Deploy Control Center only in the primary region (southcentralus).

**Rationale**: Control Center is a monitoring/management UI, not a data-plane component. It can monitor remote clusters via Metrics Reporter. Running it in a single region reduces cost and operational overhead. During failover testing, monitoring can still function as long as the primary region is reachable (and if it isn't, that's the scenario being tested).

## Configuration Reference

### VM Sizing Recommendations (Lab Environment)

| Component | Azure VM SKU | vCPU | RAM | Storage | Qty/Region |
|---|---|---|---|---|---|
| Kafka Broker | Standard_D8s_v5 | 8 | 32 GB | 256 GB Premium SSD (data) + 64 GB OS | 3 |
| ZooKeeper | Standard_D2s_v5 | 2 | 8 GB | 64 GB Premium SSD | 3 |
| Schema Registry | Standard_D2s_v5 | 2 | 8 GB | 32 GB OS disk | 1 |
| Kafka Connect | Standard_D4s_v5 | 4 | 16 GB | 64 GB OS disk | 1 |
| Control Center | Standard_D4s_v5 | 4 | 16 GB | 128 GB Premium SSD | 1 (primary only) |

**Total VMs per active region**: 8 (3 broker + 3 ZK + 1 SR + 1 Connect)
**Total VMs for primary region**: 9 (adds Control Center)
**Total VMs for DR region (canadaeast)**: 8 (3 broker + 3 ZK + 1 SR + 1 Connect)
**Grand total across all 3 regions**: 25 VMs

### JVM Heap Settings

```properties
# Kafka Broker
KAFKA_HEAP_OPTS="-Xms6G -Xmx6G"

# ZooKeeper
KAFKA_HEAP_OPTS="-Xms2G -Xmx2G"

# Schema Registry
SCHEMA_REGISTRY_HEAP_OPTS="-Xms1G -Xmx1G"

# Kafka Connect
KAFKA_HEAP_OPTS="-Xms2G -Xmx2G"

# Control Center
CONTROL_CENTER_HEAP_OPTS="-Xms4G -Xmx4G"
```

### Key Kafka Broker Configuration (server.properties)

```properties
# Replication
default.replication.factor=3
min.insync.replicas=2
unclean.leader.election.enable=false

# ZooKeeper connection
zookeeper.connect=zk1:2181,zk2:2181,zk3:2181/kafka

# Listeners (TLS)
listeners=PLAINTEXT://:9092,SSL://:9093
inter.broker.listener.name=PLAINTEXT
advertised.listeners=PLAINTEXT://broker-N:9092,SSL://broker-N:9093

# Metrics Reporter (for Control Center)
metric.reporters=io.confluent.metrics.reporter.ConfluentMetricsReporter
confluent.metrics.reporter.bootstrap.servers=broker-1:9092,broker-2:9092,broker-3:9092

# Log retention
log.retention.hours=168
log.segment.bytes=1073741824
log.dirs=/var/kafka-data
```

### Key ZooKeeper Configuration (zookeeper.properties)

```properties
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/var/zookeeper/data
dataLogDir=/var/zookeeper/log
clientPort=2181
maxClientCnxns=60
autopurge.snapRetainCount=3
autopurge.purgeInterval=1

# Ensemble members
server.1=zk1:2888:3888
server.2=zk2:2888:3888
server.3=zk3:2888:3888
```

### Key Schema Registry Configuration

```properties
listeners=http://0.0.0.0:8081
kafkastore.bootstrap.servers=broker-1:9092,broker-2:9092,broker-3:9092
kafkastore.topic=_schemas
schema.compatibility.level=BACKWARD
```

### Key Connect Worker Configuration

```properties
bootstrap.servers=broker-1:9092,broker-2:9092,broker-3:9092
group.id=connect-cluster
config.storage.topic=_connect-configs
offset.storage.topic=_connect-offsets
status.storage.topic=_connect-status
config.storage.replication.factor=3
offset.storage.replication.factor=3
status.storage.replication.factor=3
key.converter=io.confluent.connect.avro.AvroConverter
value.converter=io.confluent.connect.avro.AvroConverter
key.converter.schema.registry.url=http://schema-registry:8081
value.converter.schema.registry.url=http://schema-registry:8081
rest.port=8083
```

### Cluster Linking Configuration

```properties
# On destination cluster, create a cluster link to source
# CLI: confluent kafka link create src-link \
#   --source-cluster <source-cluster-id> \
#   --source-bootstrap-server source-broker-1:9092,source-broker-2:9092

# Link properties
link.mode=DESTINATION
connection.mode=OUTBOUND

# Mirror topic creation
# CLI: confluent kafka mirror create <topic-name> --link src-link
```

### Network Security Group Rules (Azure NSG)

| Priority | Direction | Port | Source | Destination | Purpose |
|---|---|---|---|---|---|
| 100 | Inbound | 9092-9093 | VNet | Brokers | Kafka client + inter-broker |
| 110 | Inbound | 2181 | VNet | ZooKeeper | ZK client port |
| 120 | Inbound | 2888 | ZK Subnet | ZK Subnet | ZK peer communication |
| 130 | Inbound | 3888 | ZK Subnet | ZK Subnet | ZK leader election |
| 140 | Inbound | 8081 | VNet | Schema Registry | SR REST API |
| 150 | Inbound | 8083 | VNet | Connect | Connect REST API |
| 160 | Inbound | 9021 | VNet | Control Center | CC Web UI |
| 200 | Inbound | 9092 | Peered VNets | Brokers | Cross-region Cluster Linking |
| 4096 | Inbound | * | * | * | Deny all other inbound |

## Risks and Open Questions

### Risks

1. **AZ limitations in mexicocentral and canadaeast**: These regions may have only 1 availability zone. Without multi-AZ spread, a zone failure takes out all nodes in that region. Mitigation: rely on cross-region Cluster Linking for DR rather than intra-region AZ resilience.
2. **Cluster Linking latency**: Cross-region replication latency between southcentralus ↔ mexicocentral and southcentralus ↔ canadaeast needs measurement. High latency increases RPO. Mitigation: benchmark replication lag as part of initial lab validation.
3. **ZooKeeper sensitivity to disk I/O**: ZooKeeper write performance degrades with high disk latency. Using Premium SSD is required. Shared disks with other services could cause latency spikes. Mitigation: dedicated VMs with Premium SSD for ZK.
4. **Confluent license scope**: Some components (Cluster Linking, Control Center, Metrics Reporter) require Confluent Enterprise license. Ensure licensing covers all 3 regions.
5. **VM cost**: 25 VMs across 3 regions may exceed lab budget expectations. Consider reducing DR region to 1 ZK + 1 broker for cost savings (at the expense of less realistic chaos testing in DR).

### Open Questions

1. **KRaft migration path**: Confluent Platform 7.9+ supports KRaft mode. Should the lab plan for eventual ZooKeeper removal, or is ZK-based mode sufficient for the resilience research goals?
2. **mTLS vs SASL/PLAIN**: What authentication mechanism should be used for inter-broker and client connections? mTLS aligns with the Azure environment's security posture but adds certificate management complexity.
3. **Cluster Linking security**: Does Cluster Linking between VNet-peered regions require TLS, or is VNet-level encryption sufficient?
4. **Schema Registry cross-region**: Should Schema Registry instances across regions share the same `_schemas` topic (via Cluster Linking mirror) or operate independently?
5. **Exact Azure VM availability**: Verify that Standard_D8s_v5 and Standard_D2s_v5 are available in all 3 target regions (southcentralus, mexicocentral, canadaeast) with the required zone support.
6. **Connect connector selection**: Which specific connectors are needed for the resilience lab? This affects Connect worker sizing and may influence whether distributed mode is necessary.

## References

- [Confluent Platform Documentation — Overview](https://docs.confluent.io/platform/current/overview.html)
- [Confluent Platform Architecture](https://docs.confluent.io/platform/current/get-started/platform.html)
- [Confluent Platform System Requirements](https://docs.confluent.io/platform/current/installation/system-requirements.html)
- [Running Kafka in Production](https://docs.confluent.io/platform/current/kafka/deployment.html)
- [ZooKeeper Production Guide](https://docs.confluent.io/platform/current/kafka-metadata/zk-production.html)
- [Cluster Linking for Confluent Platform](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/index.html)
- [Multi-Data Center Architectures](https://docs.confluent.io/platform/current/multi-dc-deployments/multi-region-architectures.html)
- [Multi-Region Cluster Tutorial](https://docs.confluent.io/platform/current/multi-dc-deployments/multi-region-tutorial.html)
- [Kafka Connect Cluster Sizing](https://docs.confluent.io/platform/current/connect/references/connect-cluster-sizing.html)
- [Control Center System Requirements](https://docs.confluent.io/control-center/current/installation/system-requirements.html)
- [Confluent Metrics Reporter](https://docs.confluent.io/platform/current/monitor/metrics-reporter.html)
- [Kafka Connect Worker Configuration](https://docs.confluent.io/platform/current/connect/references/allconfigs.html)
- [CP-Ansible Component Deployment](https://deepwiki.com/confluentinc/cp-ansible/5-component-deployment)
- [Confluent Platform Reference Architecture (White Paper)](https://www.confluent.io/resources/white-paper/apache-kafka-confluent-enterprise-reference-architecture/)
- [Confluent Kafka Hardware Requirements Guide](https://www.codestudy.net/blog/confluent-kafka-hardware-requirements/)
- [Confluent Kafka Ports Reference](https://www.codestudy.net/blog/confluent-kafka-ports/)
- [Cluster Linking DR Failover (Confluent Cloud)](https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/dr-failover.html)
- [Configure Pod Scheduling for Confluent Platform](https://docs.confluent.io/operator/current/co-schedule-workloads.html)
- [Multiple AZ Deployment of Confluent Platform](https://docs.confluent.io/operator/current/co-multi-az.html)
