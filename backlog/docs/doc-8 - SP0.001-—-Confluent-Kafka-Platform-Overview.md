---
id: doc-8
title: SP0.001 — Confluent Kafka Platform Overview
type: other
created_date: '2026-03-30 15:41'
updated_date: '2026-03-30 15:57'
---
# SP0.001 — Confluent Kafka Platform Overview

## Executive Summary

Confluent Platform 7.8.x is an enterprise-grade event streaming platform built on top of Apache Kafka 3.8. It extends open-source Kafka with production-hardened components — including Schema Registry, Kafka Connect, ksqlDB, Confluent Control Center, and now Apache Flink — packaged under a unified operational model with long-term support (LTS). The 7.8 release introduced Confluent Platform for Apache Flink as generally available (GA), enabling on-premises Flink workloads to be managed at scale alongside Kafka, with integrated RBAC security, REST API automation, and the Confluent Manager for Apache Flink (CMF). Additionally, 7.8 delivered mTLS Identity for RBAC Authorization, allowing client TLS certificates to be used directly as RBAC principals — a significant improvement for zero-trust, on-premises deployments.

For the kafka-lab project, Confluent Platform 7.8.x provides the foundational streaming backbone across three Azure regions (southcentralus primary, mexicocentral secondary, canadaeast DR). Its tiered storage capability is particularly strategic: by offloading warm Kafka log segments to Azure Blob Storage, brokers can be right-sized for compute without over-provisioning local disk, and data retention can extend to months or years at object-storage cost. Self-Balancing Clusters reduce operational burden by automatically redistributing partitions when broker topology changes — critical in a multi-region, multi-AZ environment where nodes may be added, upgraded, or replaced.

**Important note on ZooKeeper vs. KRaft:** ZooKeeper mode was deprecated in Confluent Platform 7.5 and has been completely removed in 8.0. Confluent Platform 7.8.x still supports ZooKeeper-based clusters for existing deployments and is fully documented in the 7.9 branch of the docs. All new kafka-lab deployments should be evaluated for KRaft mode. This document covers ZooKeeper ensemble setup for completeness, as existing environments may require migration, but kafka-lab should target KRaft for all new clusters.

---

## Broker Configuration

### Core server.properties Keys

The primary Kafka broker configuration lives in `/etc/kafka/server.properties` (package install) or `$CONFLUENT_HOME/etc/kafka/server.properties`. Key categories and properties:

#### Identity and Listeners

```properties
# Unique broker ID — must be unique per broker in the cluster
broker.id=1

# Listener for inter-broker and client communication (private VNet only — no public endpoint)
listeners=PLAINTEXT://0.0.0.0:9092
advertised.listeners=PLAINTEXT://<private-ip>:9092

# Required for KRaft mode inter-broker listener name matching
inter.broker.listener.name=PLAINTEXT
```

#### Log Storage

```properties
# Data log directories (one or more dedicated data disks; NOT the OS disk)
# NOTE: Confluent Tiered Storage does not support JBOD (multiple log.dirs) — use a single directory
log.dirs=/data/kafka/logs

# Segment size — roll a new segment when this size is reached (default 1 GB)
log.segment.bytes=1073741824

# Retention — broker-level defaults (override per topic as needed)
log.retention.hours=168
log.retention.bytes=-1

# Compaction threads
log.cleaner.threads=2
```

#### Replication and Durability

```properties
# Default replication factor for auto-created topics
default.replication.factor=3

# Minimum in-sync replicas for producer acks=-1 (all) durability guarantee
min.insync.replicas=2

# Rack label — set to the Azure Availability Zone (1, 2, or 3) for this broker
broker.rack=1

# Enable controlled shutdown to drain leadership before stop
controlled.shutdown.enable=true
```

#### Networking and I/O Threads

```properties
# Network handler threads (scale with client parallelism; 3–8 is typical)
num.network.threads=4

# I/O threads for disk operations (typically 2x num.network.threads)
num.io.threads=8

# Socket buffer sizes
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
```

#### ZooKeeper Connection (ZK-mode clusters only)

```properties
zookeeper.connect=zk1:2181,zk2:2181,zk3:2181/kafka
zookeeper.connection.timeout.ms=18000
```

### JVM Settings

JVM options are set via environment variables before broker startup — they are **not** inside `server.properties`. Set in `/etc/kafka/kafka-env.sh` or export before calling `kafka-server-start.sh`:

```bash
# Heap — for D4s_v5 (16 GB RAM): allocate 6 GB to the broker JVM
# Leave OS and page cache headroom (~10 GB free) for kernel-level I/O buffering
export KAFKA_HEAP_OPTS="-Xmx6g -Xms6g"

# G1GC is recommended for Kafka workloads on Java 11+
export KAFKA_JVM_PERFORMANCE_OPTS="-server \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=20 \
  -XX:InitiatingHeapOccupancyPercent=35 \
  -XX:+ExplicitGCInvokesConcurrent \
  -XX:MaxInlineLevel=15 \
  -Djava.awt.headless=true"

# GC logging (recommended for production tuning)
export KAFKA_GC_LOG_OPTS="-Xlog:gc*:file=/var/log/kafka/kafka-gc.log:time,tags:filecount=10,filesize=100m"
```

**Heap sizing guidance by VM size:**

| VM SKU | RAM | Recommended -Xmx | Rationale |
|---|---|---|---|
| D4s_v5 (broker) | 16 GiB | 6 GiB | ~10 GiB for OS page cache (critical for Kafka I/O) |
| D2s_v5 (ZooKeeper) | 8 GiB | 1 GiB | ZK is not heap-intensive for Kafka metadata workloads |

### Log Directory Setup

Brokers should use **dedicated data disks** (Azure Premium SSD P30 or P40) mounted separately from the OS volume. Recommended setup:

```bash
# Format and mount a dedicated data disk at /data/kafka
mkfs.xfs /dev/sdc
mkdir -p /data/kafka/logs
mount /dev/sdc /data/kafka/logs

# Add to /etc/fstab for persistence
echo "/dev/sdc /data/kafka/logs xfs defaults,noatime 0 2" >> /etc/fstab

# Set ownership
chown -R cp-kafka:cp-kafka /data/kafka/logs
```

Key mount options: use `noatime` to reduce unnecessary disk I/O metadata updates. XFS is recommended over ext4 for Kafka workloads due to superior handling of many small files.

---

## ZooKeeper Ensemble

> **Deprecation Notice:** ZooKeeper mode is deprecated as of Confluent Platform 7.5 and removed in 8.0. For kafka-lab, prefer KRaft mode for new clusters. This section documents ZooKeeper for existing or migrating deployments.

### 3-Node Ensemble Design

A 3-node ensemble (`2n+1 = 3`, so `n=1`) tolerates one node failure while maintaining quorum. All three nodes are **voting participants** — quorum requires 2 of 3. Place each ZooKeeper node in a separate Azure Availability Zone to avoid correlated failures.

### ZooKeeper Configuration (`/etc/kafka/zookeeper.properties`)

This configuration is **identical across all three nodes**:

```properties
# Client port — brokers connect here
clientPort=2181

# Data directory (SSD-backed disk; snapshots and transaction logs)
dataDir=/data/zookeeper/data

# Separate transaction log directory on its own disk for best performance
dataLogDir=/data/zookeeper/log

# Tick time in ms — heartbeat interval and base for all ZK timeouts
tickTime=2000

# Follower init timeout = initLimit * tickTime = 5 * 2000 = 10000 ms
initLimit=5

# Follower sync timeout = syncLimit * tickTime = 2 * 2000 = 4000 ms
syncLimit=2

# Maximum client connections per server (0 = unlimited)
maxClientCnxns=0

# Ensemble membership: server.<myid>=<hostname>:<leader-port>:<election-port>
server.1=zk1:2888:3888
server.2=zk2:2888:3888
server.3=zk3:2888:3888

# Auto-purge: retain last 3 snapshots, purge every 24 hours
autopurge.snapRetainCount=3
autopurge.purgeInterval=24

# Prevent connection drops behind NAT/firewalls (Azure VNet has stateful NAT)
tcpKeepAlive=true

# Admin server (disable if port conflicts occur)
admin.enableServer=true
admin.serverPort=8080
```

### myid File

Each ZooKeeper node must have a unique identity file in `dataDir`:

```bash
# On zk1:
echo "1" > /data/zookeeper/data/myid

# On zk2:
echo "2" > /data/zookeeper/data/myid

# On zk3:
echo "3" > /data/zookeeper/data/myid
```

### Observer Pattern

ZooKeeper observers are non-voting nodes that replicate state but do not participate in write quorum or leader elections. They are useful for scaling read traffic or adding DR-region nodes without increasing quorum complexity. To add an observer:

```properties
# In zoo.cfg on ALL nodes — including the observer itself:
server.4=zk-observer:2888:3888:observer

# On the observer node:
# myid = 4
```

Observers do not provide additional fault tolerance for writes. For the kafka-lab 3-broker dev environment, observers are optional; they become relevant when adding a read-only replica in a DR region without changing quorum.

### Hardware Recommendations for D2s_v5 (ZooKeeper)

| Resource | Recommendation | Notes |
|---|---|---|
| CPU | 2 vCPU (D2s_v5) | ZK is not CPU-intensive for Kafka metadata |
| RAM | 8 GiB (D2s_v5) | Use 1 GiB JVM heap; rest for OS |
| Disk | Premium SSD P10 (128 GiB) for `dataDir`, P6 (64 GiB) for `dataLogDir` | SSD is critical — ZK requires low-latency disk writes |
| Network | 16,000 Mbps max | D2s_v5 provides sufficient bandwidth for ZK traffic |

---

## KRaft Configuration

> **KRaft is the recommended metadata mode for all new kafka-lab clusters.** ZooKeeper mode is deprecated as of CP 7.5 and removed in 8.0. Confluent Platform 7.8.x ships KRaft as GA.

KRaft (Kafka Raft) replaces ZooKeeper with an internal Raft-based metadata quorum. Controllers are elected from a dedicated pool of broker nodes or from combined broker+controller nodes. For the kafka-lab 3-broker dev environment, each node runs in **combined mode** (`process.roles=broker,controller`), eliminating the need for separate ZooKeeper VMs.

### Combined Broker + Controller Node — Key KRaft Properties

The following properties must be added to (or replace ZooKeeper properties in) `server.properties` on each node:

```properties
# Node operates as both a Kafka broker and a KRaft controller
process.roles=broker,controller

# Unique node ID — must be unique across the entire cluster
node.id=1

# Quorum voters: all controller-eligible nodes listed as <node.id>@<host>:<controller-port>
controller.quorum.voters=1@broker1:9093,2@broker2:9093,3@broker3:9093

# Name of the listener used for controller-to-controller and broker-to-controller communication
controller.listener.names=CONTROLLER

# Listeners — expose both broker (9092) and controller (9093) ports
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://<private-ip>:9092

# Map each listener name to its security protocol
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT

# Inter-broker listener must match one of the PLAINTEXT listeners
inter.broker.listener.name=PLAINTEXT

# KRaft metadata log directory (separate from data log.dirs for clarity)
metadata.log.dir=/data/kafka/metadata
```

### Broker-Specific node.id Values (Dev Cluster)

| Node | node.id | Private IP |
|---|---|---|
| Broker 1 (AZ1) | 1 | 10.0.1.11 |
| Broker 2 (AZ2) | 2 | 10.0.1.12 |
| Broker 3 (AZ3) | 3 | 10.0.1.13 |

### KRaft Cluster Initialisation

A KRaft cluster must be bootstrapped once before first start. Generate a cluster UUID and format the metadata directory on each node:

```bash
# Generate a unique cluster ID (run once; use the same ID on all nodes)
CLUSTER_ID=$(kafka-storage.sh random-uuid)

# Format the metadata storage on each node (run on each broker)
kafka-storage.sh format -t "$CLUSTER_ID" \
  -c /etc/kafka/server.properties
```

> Do not re-run `kafka-storage.sh format` on an existing cluster — it will wipe metadata.

### KRaft vs ZooKeeper Property Comparison

| Purpose | ZooKeeper property | KRaft equivalent |
|---|---|---|
| Cluster metadata | `zookeeper.connect` | `controller.quorum.voters` |
| Node role | _(broker only)_ | `process.roles=broker,controller` |
| Controller port | _(ZK election port 3888)_ | `controller.listener.names=CONTROLLER` |
| Node identifier | `broker.id` | `node.id` (replaces `broker.id`) |

---

## Replication Strategy

### Replication Factor and min.insync.replicas

For a 3-broker cluster spanning 3 Azure Availability Zones:

```properties
# server.properties (broker-level defaults)
default.replication.factor=3
min.insync.replicas=2
```

- `default.replication.factor=3`: Each partition has one replica per broker/AZ. Tolerates one full AZ failure.
- `min.insync.replicas=2`: When combined with producer `acks=-1` (all), at least 2 replicas must acknowledge a write before it is committed. This ensures no data loss if one AZ goes offline after the write.

**Producer configuration alignment** (clients must configure this):
```properties
acks=-1          # Wait for all in-sync replicas
retries=2147483647
enable.idempotence=true
```

### Rack Awareness with Azure Availability Zones

Kafka's rack awareness assigns `broker.rack` labels to brokers and then ensures partition replicas are spread across distinct rack values during partition assignment:

```properties
# Broker 1 (southcentralus Zone 1)
broker.rack=az1

# Broker 2 (southcentralus Zone 2)
broker.rack=az2

# Broker 3 (southcentralus Zone 3 — or mexicocentral Zone 1 for secondary region)
broker.rack=az3
```

With `broker.rack` set, Kafka's partition assignment algorithm guarantees that for a topic with `replication.factor=3`, no two replicas of the same partition share a rack value. This provides AZ-level fault isolation out of the box.

**ZooKeeper connection string should include a chroot** to namespace Kafka metadata:
```properties
zookeeper.connect=zk1:2181,zk2:2181,zk3:2181/kafka
```

### Topic-Level Overrides

High-value topics can override broker defaults:
```bash
kafka-topics.sh --bootstrap-server broker1:9092 \
  --create --topic critical-events \
  --partitions 12 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000
```

### Partition Count Guidelines

| Scenario | Recommended Partitions |
|---|---|
| Low-throughput dev topics | 3–6 (one per broker) |
| Medium-throughput production | 12–24 |
| High-throughput (100 MB/s+) | 48–96+ |

Rule of thumb: target 10–100 MB/s per partition for broker headroom. More partitions = more parallelism but higher metadata overhead in ZooKeeper/KRaft.

---

## Tiered Storage with Azure Blob

### Architecture Overview

Confluent Tiered Storage separates compute (brokers) from storage (Azure Blob). Brokers write new segments to local disk as usual; a background **Tiering Task** uploads closed segments to Azure Blob Storage asynchronously. A **Tier Fetcher** handles reads for data no longer on local disk by fetching segments from Blob on demand.

The same storage container must be shared across all brokers in a tiered cluster.

### Broker Configuration for Azure Blob

Add the following to every broker's `server.properties` (or `broker.properties`):

```properties
# Enable tiered storage feature support on this broker
confluent.tier.feature=true

# Set tiering active for all non-compacted topics by default
# Set to false to opt-in per topic instead of opt-out
confluent.tier.enable=true

# Azure Block Blob backend
confluent.tier.backend=AzureBlockBlob

# Azure Blob container name (Standard general-purpose v2, Hot tier)
confluent.tier.azure.block.blob.container=klc-kafka-tiered-storage

# UAMI authentication via Azure IMDS — no client secret required when broker VM has a UAMI attached
# The ManagedIdentityCredentialProvider calls IMDS automatically; no credential file needed
confluent.tier.azure.block.blob.credentials.provider=com.microsoft.azure.storage.auth.ManagedIdentityCredentialProvider

# Replication factor for tiered storage internal metadata topic
# Default is 3 — matches the cluster replication factor
confluent.tier.metadata.replication.factor=3

# Local hotset retention — how long uploaded segments stay on local disk after upload
# Default: inherits from retention.ms (7 days). Recommended dev value: 86400000 (24 h)
confluent.tier.local.hotset.ms=86400000

# Number of upload threads per broker (default 8; tune for throughput)
confluent.tier.archiver.num.threads=8

# Number of fetch threads for remote reads (default 8)
confluent.tier.fetcher.num.threads=8
```

### Credential Format — UAMI vs Service Principal

**UAMI (User Assigned Managed Identity) — preferred for kafka-lab:**

When the broker VM has a UAMI attached, Azure IMDS handles authentication automatically. No client secret or tenant ID is required. Use the managed identity credential provider in `server.properties`:

```properties
confluent.tier.azure.block.blob.credentials.provider=com.microsoft.azure.storage.auth.ManagedIdentityCredentialProvider
```

If the VM has multiple UAMIs attached, disambiguate by specifying the UAMI client ID in a minimal credential file (`confluent.tier.azure.block.blob.cred.file.path`):

```json
{
  "azureClientId": "<uami-client-id>"
}
```

No `azureTenantId` or `azureClientSecret` — these fields are not required for VM-level UAMI authentication via IMDS. Including `azureClientSecret` in a UAMI context is incorrect and a configuration error.

**Service Principal — alternative for environments without VM-level UAMI:**

```json
{
  "azureClientId": "<sp-client-id>",
  "azureTenantId": "<aad-tenant-id>",
  "azureClientSecret": "<sp-client-secret>"
}
```

> ⚠️ Do not use service principal credentials on kafka-lab broker VMs. UAMIs are attached at the VM level and IMDS-based authentication requires no secret.

**Connection string (dev/testing only — never store in plaintext):**

```json
{
  "connectionString": "DefaultEndpointsProtocol=https;AccountName=<account>;AccountKey=<key>;EndpointSuffix=core.windows.net"
}
```

### CMEK and Private Endpoint Integration

Confluent Tiered Storage writes to Azure Blob through the Azure Blob SDK. CMEK and private endpoint transparency are handled at the Azure Storage Account level — no special Confluent configuration is needed beyond using the correct endpoint and credentials.

Required Azure Storage Account configuration:
1. **Account type**: Standard general-purpose v2 (StorageV2)
2. **Access tier**: Hot (default, hardcoded by Confluent's Azure backend)
3. **CMEK**: Enable customer-managed keys in Azure Storage encryption settings, linked to an Azure Key Vault key. The UAMI used by the broker must have `Key Vault Crypto User` role on the CMK.
4. **Private Endpoint**: Provision a private endpoint for the storage account with DNS zone `privatelink.blob.core.windows.net` linked to the broker VNet. Set `publicNetworkAccess=Disabled` on the storage account.
5. **Broker UAMI permissions**: Assign `Storage Blob Data Contributor` role to the UAMI on the container.

When a private endpoint is configured, all Confluent Tier storage traffic traverses the private endpoint — no internet egress.

### Segment Lifecycle

```
Active segment (write) → Local disk
        │
        ▼ (segment rolls — size or time threshold reached)
Closed segment → Local disk
        │
        ▼ (Tiering Task uploads asynchronously)
Segment in Azure Blob Storage ← permanent remote copy
        │
        ├── Local disk copy retained for confluent.tier.local.hotset.ms (default: inherits retention.ms)
        │
        └── After hotset expiry → evicted from local disk
              │
              └── Reads for evicted segments → Tier Fetcher fetches from Blob on demand
```

Topic-level retention controls:
```bash
# Retain data in Blob for 30 days total
kafka-configs.sh --bootstrap-server broker1:9092 --entity-type topics \
  --entity-name my-topic --alter \
  --add-config confluent.tier.enable=true,\
retention.ms=2592000000,\
confluent.tier.local.hotset.ms=86400000
```

### Limitations
- JBOD (`log.dirs` with multiple paths) is not supported with Tiered Storage — use a single `log.dirs` path.
- Compacted topics are supported starting with Confluent Platform 7.6.
- All brokers in the cluster must point to the same container.

---

## Self-Balancing Cluster

### Overview

Self-Balancing Clusters (SBC) is a Confluent-exclusive feature that continuously monitors partition distribution across brokers and automatically triggers rebalancing operations. It is the preferred replacement for the legacy Auto Data Balancer (ADB) — the two cannot run simultaneously.

SBC uses an internal controller-based architecture: brokers publish metrics to internal topics prefixed `_confluent_balancer_`, the controller aggregates them and generates rebalancing plans, and executes partition reassignments automatically.

### Core Configuration Properties

Add to all brokers' `server.properties`:

```properties
# Master switch — enables self-balancing
confluent.balancer.enable=true

# Trigger mode:
#   EMPTY_BROKER — rebalance only when a broker is added or removed (lowest overhead)
#   ANY_UNEVEN_LOAD — continuous balancing for any detected imbalance (recommended for production)
confluent.balancer.heal.uneven.load.trigger=ANY_UNEVEN_LOAD

# Throttle on partition data movements to protect production throughput
# Default is unlimited; set to 10 MB/s for dev environment
confluent.balancer.throttle.bytes.per.second=10485760

# How long a broker must be offline before SBC moves its partitions
# Default: 300000 ms (5 min); set higher to avoid thrashing during transient restarts
confluent.balancer.heal.broker.failure.threshold.ms=300000

# For KRaft mode — required to enable SBC properly
# (inter.broker.listener.name must also be set)
inter.broker.listener.name=PLAINTEXT
```

### Trigger Modes

| Mode | Configuration value | When to use |
|---|---|---|
| Broker add/remove only | `EMPTY_BROKER` | Low-traffic dev clusters; manual rebalancing preferred |
| Continuous balancing | `ANY_UNEVEN_LOAD` | Production; automatically addresses hot partitions and leadership skew |

### Constraints and Operational Notes

1. **Disk uniformity**: Broker disks must be within 5% of average cluster capacity. Attach equal-sized data disks to all brokers before enabling SBC.
2. **Mutual exclusion**: `confluent.balancer.enable=true` and Auto Data Balancer cannot coexist. Verify ADB is not running before enabling SBC.
3. **Throttle**: Always set `confluent.balancer.throttle.bytes.per.second` in production to prevent rebalancing from saturating network bandwidth. A value of 50–100 MB/s is typical for production; 10 MB/s for dev.
4. **Broker removal**: Use the `kafka-remove-brokers` CLI command before decommissioning a broker — this signals SBC to drain the broker's partitions gracefully before shutdown.
5. **Control Center integration**: SBC metrics are visible in Confluent Control Center. Configure brokers with REST endpoints (`confluent.balancer.enable=true` + `confluent.http.server.listeners`) for C3 integration.
6. **Internal topics**: SBC creates several internal topics (`_confluent_balancer_api_state`, `_confluent_balancer_broker_samples`, etc.). These require `default.replication.factor=3` or set `confluent.balancer.topics.replication.factor` explicitly.

### SBC Monitoring Commands

```bash
# Check balancer status
kafka-configs.sh --bootstrap-server broker1:9092 \
  --describe --entity-type brokers --entity-default

# Remove broker 3 gracefully (drain before decommission)
kafka-remove-brokers.sh --bootstrap-server broker1:9092 --brokers 3
```

---

## Example Configuration

### Environment Sizing

| Component | Count | Azure VM SKU | Specs | AZ Placement |
|---|---|---|---|---|
| Kafka Broker | 3 | D4s_v5 | 4 vCPU, 16 GiB RAM, 145 MB/s uncached | AZ1, AZ2, AZ3 |
| ZooKeeper | 3 | D2s_v5 | 2 vCPU, 8 GiB RAM, 85 MB/s uncached | AZ1, AZ2, AZ3 |
| Data Disk (broker) | 1 per broker | Premium SSD P30 | 1 TiB, 5000 IOPS, 200 MB/s | — |
| Data Disk (ZK) | 2 per ZK | Premium SSD P10 | 128 GiB each (data + log) | — |

### Broker 1 — `/etc/kafka/server.properties` (D4s_v5, AZ1)

```properties
##############################################
# Identity
##############################################
broker.id=1
broker.rack=az1

##############################################
# Listeners (private VNet only — no public endpoint)
##############################################
listeners=PLAINTEXT://0.0.0.0:9092
advertised.listeners=PLAINTEXT://10.0.1.11:9092
inter.broker.listener.name=PLAINTEXT
listener.security.protocol.map=PLAINTEXT:PLAINTEXT

##############################################
# Log Storage
##############################################
log.dirs=/data/kafka/logs
log.segment.bytes=1073741824
log.retention.hours=168
log.retention.bytes=-1
log.cleaner.threads=2

##############################################
# Replication
##############################################
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
controlled.shutdown.enable=true

##############################################
# ZooKeeper (ZK-mode; replace with KRaft for new clusters)
##############################################
zookeeper.connect=10.0.3.11:2181,10.0.3.12:2181,10.0.3.13:2181/kafka
zookeeper.connection.timeout.ms=18000

##############################################
# Networking and Threads
##############################################
num.network.threads=4
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

##############################################
# Tiered Storage — Azure Blob
##############################################
confluent.tier.feature=true
confluent.tier.enable=true
confluent.tier.backend=AzureBlockBlob
confluent.tier.azure.block.blob.container=klc-kafka-tiered-storage
# UAMI authentication via Azure IMDS — no credential file or client secret required
confluent.tier.azure.block.blob.credentials.provider=com.microsoft.azure.storage.auth.ManagedIdentityCredentialProvider
confluent.tier.metadata.replication.factor=3
confluent.tier.local.hotset.ms=86400000
confluent.tier.archiver.num.threads=8
confluent.tier.fetcher.num.threads=8

##############################################
# Self-Balancing Cluster
##############################################
confluent.balancer.enable=true
confluent.balancer.heal.uneven.load.trigger=EMPTY_BROKER
confluent.balancer.throttle.bytes.per.second=10485760
confluent.balancer.heal.broker.failure.threshold.ms=300000

##############################################
# Metrics and Monitoring
##############################################
confluent.metrics.reporter.bootstrap.servers=10.0.1.11:9092,10.0.1.12:9092,10.0.1.13:9092
confluent.metrics.reporter.topic.replicas=3
confluent.support.metrics.enable=false
```

### Broker JVM Startup Script — `/etc/kafka/kafka-env.sh`

```bash
# Heap for D4s_v5 (16 GB RAM): 6 GB JVM heap, ~10 GB for page cache
export KAFKA_HEAP_OPTS="-Xmx6g -Xms6g"

export KAFKA_JVM_PERFORMANCE_OPTS="-server \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=20 \
  -XX:InitiatingHeapOccupancyPercent=35 \
  -XX:+ExplicitGCInvokesConcurrent \
  -XX:MaxInlineLevel=15 \
  -Djava.awt.headless=true"

export KAFKA_GC_LOG_OPTS="-Xlog:gc*:file=/var/log/kafka/kafka-gc.log:time,tags:filecount=10,filesize=100m"
```

### ZooKeeper Node 1 — `/etc/kafka/zookeeper.properties` (D2s_v5, AZ1)

```properties
clientPort=2181
dataDir=/data/zookeeper/data
dataLogDir=/data/zookeeper/log
tickTime=2000
initLimit=5
syncLimit=2
maxClientCnxns=0
server.1=10.0.3.11:2888:3888
server.2=10.0.3.12:2888:3888
server.3=10.0.3.13:2888:3888
autopurge.snapRetainCount=3
autopurge.purgeInterval=24
tcpKeepAlive=true
admin.enableServer=true
admin.serverPort=8080
```

### ZooKeeper JVM — `/etc/kafka/zookeeper-env.sh`

```bash
# 1 GB heap for ZK on D2s_v5 (8 GB total RAM)
export KAFKA_HEAP_OPTS="-Xmx1g -Xms1g"

export KAFKA_JVM_PERFORMANCE_OPTS="-server \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=20 \
  -Djava.awt.headless=true"
```

### Azure Blob Credentials File — `/etc/kafka/secrets/az-blob-cred.json`

For the recommended UAMI approach, no credential file is needed when using `ManagedIdentityCredentialProvider`. If the VM has multiple UAMIs and disambiguation is required, create a minimal file containing only the UAMI client ID:

```json
{
  "azureClientId": "<uami-client-id-for-broker-vm>"
}
```

No `azureTenantId` or `azureClientSecret`. A broker VM with a UAMI attached authenticates through Azure IMDS automatically — providing a client secret here is incorrect and will be ignored or cause errors.

> Store this file with `chmod 600` and `chown cp-kafka:cp-kafka`. The Confluent broker user (`cp-kafka`) is the only required reader.

### myid Files

```bash
# ZooKeeper node 1 (AZ1)
echo "1" > /data/zookeeper/data/myid

# ZooKeeper node 2 (AZ2)
echo "2" > /data/zookeeper/data/myid

# ZooKeeper node 3 (AZ3)
echo "3" > /data/zookeeper/data/myid
```

---

## References

| Source | URL |
|---|---|
| Confluent Platform Overview | <https://docs.confluent.io/platform/7.8/platform.html> |
| Kafka Broker Configuration Reference | <https://docs.confluent.io/platform/7.8/installation/configuration/broker-configs.html> |
| Kafka Configuration Reference Index | <https://docs.confluent.io/platform/7.8/installation/configuration/index.html> |
| Confluent Tiered Storage | <https://docs.confluent.io/platform/7.8/kafka/tiered-storage.html> |
| Self-Balancing Clusters Overview | <https://docs.confluent.io/platform/7.8/kafka/sbc/index.html> |
| Self-Balancing Configuration Options | <https://docs.confluent.io/platform/7.8/kafka/sbc/configuration-options.html> |
| ZooKeeper Production Guide (CP 7.8) | <https://docs.confluent.io/platform/7.8/kafka-metadata/zk-production.html> |
| Post-Deployment Best Practices | <https://docs.confluent.io/platform/7.8/kafka/post-deployment.html> |
| Migrate ZooKeeper to KRaft | <https://docs.confluent.io/platform/7.8/installation/migrate-zk-kraft.html> |
| End of Support for ZooKeeper | <https://support.confluent.io/hc/en-us/articles/30881659449748-End-of-Support-for-ZooKeeper-in-Confluent-Platform> |
| CP 7.8 Release Notes (Support Portal) | <https://support.confluent.io/hc/en-us/articles/33032768211220-New-with-Confluent-Platform-7-8-Confluent-Platform-for-Apache-Flink-GA-mTLS-Identity-for-RBAC-Authorization-and-More> |
| Kafka Topic Configuration Reference | <https://docs.confluent.io/platform/7.8/installation/configuration/topic-configs.html> |
| Infinite Kafka Data Retention Blog | <https://www.confluent.io/blog/infinite-kafka-storage-in-confluent-platform/> |
| Azure Dsv5 VM Series Specs | <https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv5-series> |
| Azure DefaultAzureCredential SDK | <https://learn.microsoft.com/en-us/dotnet/api/overview/azure/identity-readme> |
| ZooKeeper Administrator's Guide | <https://zookeeper.apache.org/doc/r3.4.10/zookeeperAdmin.html> |
| ZooKeeper Observer Documentation | <https://zookeeper.apache.org/doc/r3.5.6/zookeeperObservers.html> |
