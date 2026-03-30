---
id: doc-9
title: SP0.004 — Confluent Cluster Linking
type: other
created_date: '2026-03-30 15:46'
updated_date: '2026-03-30 15:56'
---
# SP0.004 — Confluent Cluster Linking

## Executive Summary

Confluent Cluster Linking is a broker-native replication feature introduced in Confluent Platform 6.0 and reaching general availability (GA) in CP 6.1, then fully production-hardened in 7.x, that enables direct, byte-for-byte mirroring of Kafka topics between clusters without any additional infrastructure such as Kafka Connect workers or separate MirrorMaker VMs. (Note: CP 5.4 introduced Multi-Region Clusters (MRC), a separate feature for synchronous intra-cluster replication across stretched availability zones — MRC and Cluster Linking are complementary but distinct capabilities.) At its core, a *cluster link* is a configuration object created on the **destination** cluster that opens a persistent, authenticated connection back to the **source** cluster. The destination broker then pulls topic data directly—much like an internal follower replica—preserving the original partition count, message bytes, and crucially, the exact Kafka offsets. This offset fidelity is the defining technical advantage of Cluster Linking: when a failover occurs, consumer groups can resume from their last committed offset on the destination cluster without any offset translation layer, because the offsets are identical.

Compared to Apache MirrorMaker 2 (MM2), Cluster Linking eliminates the Kafka Connect dependency, removes the need for offset translation topics (`mm2-offsets.{source}.internal`), and avoids the decompression/recompression overhead that MM2 incurs when serialising messages through Connect workers. MM2 also requires careful tuning of `replication.factor` on the MirrorMaker cluster itself and introduces additional consumer lag monitoring complexity. Cluster Linking sidesteps these concerns by treating replication as a first-class broker operation: throttling, lag monitoring, and security are all managed directly through broker-level configs and the standard Confluent CLI/REST API. For Confluent Platform 7.8.x deployments the feature is enabled by default (`confluent.cluster.link.enable=true` in `server.properties`) and requires no additional licencing beyond the Confluent Platform licence.

For the kafka-lab 3-region deployment on Azure—`southcentralus` (primary), `mexicocentral` (secondary HA), `canadaeast` (DR)—Cluster Linking is the recommended mechanism for cross-region topic replication. The primary cluster in `southcentralus` acts as the single authoritative source; links originate from `mexicocentral` and `canadaeast` pulling from `southcentralus`, and a third link connects `canadaeast` to `mexicocentral` so that DR can be promoted from the secondary during a primary region outage. All inter-cluster traffic traverses Azure private endpoints, meaning bootstrap addresses point to private IP addresses within the peered VNets rather than public hostnames. Consumer offset sync and mirror topic lifecycle management are used by the web app dashboard to visualise replication lag and trigger/observe simulated failover events.

---

## Link Creation and Configuration

### Prerequisites

- Confluent Platform 7.8.x installed on source and destination clusters.
- Network connectivity from destination brokers to source bootstrap servers (private endpoint or VNet peering on Azure).
- A dedicated User Assigned Managed Identity (UAMI) per cluster for broker-to-broker authentication, or a service account with SASL/PLAIN credentials.
- The destination cluster must be running `confluent.cluster.link.enable=true` (default in CP 7.x).

> **UAMI / OAUTHBEARER Note:** Confluent Platform 7.8.x supports SASL/OAUTHBEARER at the broker level, but does not include a native integration for Azure MSI token endpoints (unlike Confluent Cloud, which has first-class Azure AD support). Supporting Azure UAMI tokens with `OAUTHBEARER` in CP requires implementing a custom `OAuthBearerLoginCallbackHandler` that fetches MSI tokens from the Azure IMDS endpoint (`http://169.254.169.254/metadata/identity/oauth2/token`) — this is not included in the standard CP distribution. **For kafka-lab**, the recommended approach is to provision dedicated SASL/PLAIN or SASL/SCRAM credentials for each cluster link, stored in Azure Key Vault and referenced via file-based JAAS config (`${file:/etc/kafka/secrets/link.properties:link.password}`). Each set of credentials should be scoped to the UAMI that owns the corresponding cluster, enforcing the per-identity isolation intent without requiring a custom OAuth implementation.

### Key Configuration Properties

| Property | Description | Example Value |
|---|---|---|
| `bootstrap.servers` | Source cluster bootstrap address(es) | `10.1.0.10:9092` |
| `security.protocol` | Transport security for the link connection | `SASL_SSL` |
| `sasl.mechanism` | SASL mechanism for authentication | `PLAIN` |
| `sasl.jaas.config` | JAAS login credentials for source | see example below |
| `cluster.link.prefix` | Immutable prefix prepended to mirror topic names and optionally consumer group names on the destination | `scus.` |
| `auto.create.mirror.topics.enable` | Whether the link should automatically mirror newly matching topics | `true` |
| `auto.create.mirror.topics.filters` | JSON filter controlling which source topics are auto-mirrored | `{"topicFilters":[{"name":"*","patternType":"LITERAL","filterType":"INCLUDE"}]}` |
| `consumer.offset.sync.enable` | Enables periodic sync of consumer group committed offsets from source to destination | `true` |
| `consumer.offset.sync.ms` | Interval in milliseconds between offset sync cycles | `30000` |
| `consumer.offset.group.filters` | JSON filter controlling which consumer groups are synced | see example below |
| `acl.sync.enable` | Mirrors topic ACLs from source to destination | `false` (manage ACLs per-cluster in kafka-lab) |
| `link.mode` | `DESTINATION` (default) or `SOURCE` for bidirectional setups | `DESTINATION` |

> **Important:** `cluster.link.prefix` cannot be changed after the link is created. Plan the naming scheme before deploying production links.

### CLI: Create a Cluster Link

Create a properties file for the link and then invoke `kafka-cluster-links` pointing at the **destination** cluster's bootstrap server.

```bash
# 1. Create the link configuration file
cat > scus-to-mxc-link.properties <<EOF
bootstrap.servers=10.1.0.10:9092
security.protocol=SASL_SSL
ssl.truststore.location=/etc/kafka/ssl/truststore.jks
ssl.truststore.password=changeit
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="link-user" password="link-password";
cluster.link.prefix=scus.
auto.create.mirror.topics.enable=true
auto.create.mirror.topics.filters={"topicFilters":[{"name":"*","patternType":"LITERAL","filterType":"INCLUDE"}]}
consumer.offset.sync.enable=true
consumer.offset.sync.ms=30000
EOF

# 2. Create the link on the destination cluster (mexicocentral)
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --create \
  --link scus-to-mexicocentral \
  --config-file scus-to-mxc-link.properties
```

### CLI: Describe and List Links

```bash
# List all cluster links on a cluster
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --list

# Describe a specific link (shows status, config, lag)
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --describe \
  --link scus-to-mexicocentral

# Delete a cluster link
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --delete \
  --link scus-to-mexicocentral
```

### CLI: Alter Link Configuration at Runtime

Most link properties (except `cluster.link.prefix`) can be updated without recreating the link:

```bash
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --alter \
  --link scus-to-mexicocentral \
  --add-config consumer.offset.sync.ms=15000
```

---

## Mirror Topics

### What Are Mirror Topics?

Mirror topics are read-only topic replicas on the destination cluster owned and managed by a cluster link. They share the identical partition layout and byte-level message content as the source topic, including the same Kafka offsets. Standard topic operations (produce, deleteRecords, alterConfigs) are blocked on mirror topics while they are actively linked—they become writable only upon **promotion**.

### Auto-Create Mirror Topics

When `auto.create.mirror.topics.enable=true`, the link monitors source topics matching the configured `auto.create.mirror.topics.filters` and creates mirror topics automatically. Topic names on the destination follow the pattern `{cluster.link.prefix}{source-topic-name}`.

```bash
# Override or add topic filter to an existing link
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --alter \
  --link scus-to-mexicocentral \
  --add-config 'auto.create.mirror.topics.filters={"topicFilters":[{"name":"app-*","patternType":"PREFIXED","filterType":"INCLUDE"}]}'
```

### Manual Mirror Topic Creation

To selectively mirror individual topics without auto-create:

```bash
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --create \
  --link scus-to-mexicocentral \
  --mirror-topic orders
```

The topic `orders` on the source will appear as `scus.orders` on the destination (given `cluster.link.prefix=scus.`).

### Consumer Group Offset Sync

Consumer group offsets are synced via the link's control plane—not by replicating the `_consumer_offsets` internal topic. This allows fine-grained control over which groups are synchronised.

```bash
# consumer-group-filters.json
cat > consumer-group-filters.json <<EOF
{
  "consumerGroupFilters": [
    { "name": "app-consumer-*", "patternType": "PREFIXED", "filterType": "INCLUDE" },
    { "name": "test-*", "patternType": "PREFIXED", "filterType": "EXCLUDE" }
  ]
}
EOF

# Apply consumer group filters when creating a link
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --create \
  --link scus-to-mexicocentral \
  --config-file scus-to-mxc-link.properties \
  --consumer-group-filters-json-file consumer-group-filters.json
```

Offset sync frequency is controlled by `consumer.offset.sync.ms` (default `30000` ms). After a sync cycle, consumer groups listed in the filter will have their committed offsets mirrored to the destination cluster's `_consumer_offsets` topic for the corresponding mirror topics. During failover, consumers pointed at the destination will pick up at or near the last synced offset.

### Mirror Topic Lifecycle Commands

```bash
# List all mirror topics on a cluster
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --list

# Describe a specific mirror topic (shows lag, link name, state)
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --describe \
  --mirror-topic scus.orders

# Pause mirroring (retains topic as read-only, stops pulling new data)
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --pause \
  --mirror-topic scus.orders

# Resume mirroring after a pause
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --resume \
  --mirror-topic scus.orders

# Promote mirror topic to a normal writable topic (irreversible on this topic/link)
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --promote \
  --mirror-topic scus.orders
```

---

## Failover and Failback Procedures

### Terminology

| Term | Definition |
|---|---|
| Promote | Convert a mirror topic to a writable, standalone topic by severing its link |
| Failover | Redirecting producers and consumers to the secondary/DR cluster after a primary outage |
| Failback | Restoring the primary cluster as the authoritative source and reversing replication |

### Failover: southcentralus → mexicocentral

The following procedure assumes `mexicocentral` has an active cluster link pulling from `southcentralus` with offset sync enabled.

**Step 1 — Stop producers on the primary (if reachable)**

```bash
# On southcentralus: pause or shut down producer applications
# If the cluster is unreachable, skip to step 2
```

**Step 2 — Verify mirror topic sync status**

```bash
# On mexicocentral: check lag before promoting
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --describe \
  --mirror-topic scus.orders
# Confirm "Max Lag" is at or near 0 before proceeding
```

**Step 3 — Promote mirror topics on mexicocentral**

```bash
# Promote all relevant mirror topics
for TOPIC in scus.orders scus.payments scus.events; do
  kafka-mirrors \
    --bootstrap-server 10.2.0.10:9092 \
    --promote \
    --mirror-topic $TOPIC
done
```

After promotion, each topic is a normal writable topic on `mexicocentral`. The `scus.` prefix remains in the name; applications should use the full prefixed name or be reconfigured to point to the new topic names.

**Step 4 — Update consumers to use the mexicocentral cluster**

```bash
# Update consumer bootstrap.servers to point to mexicocentral
# bootstrap.servers=10.2.0.10:9092
# Consumers will use their synced offsets automatically
```

**Step 5 — Update producers to write to mexicocentral**

```bash
# Update producer bootstrap.servers
# bootstrap.servers=10.2.0.10:9092
# Producers now write to the promoted topics on mexicocentral
```

**Step 6 — Verify traffic and data continuity**

```bash
# Check consumer group lag on mexicocentral
kafka-consumer-groups \
  --bootstrap-server 10.2.0.10:9092 \
  --describe \
  --group app-consumer-group-1
```

---

### Failback: mexicocentral → southcentralus (Reverse Link)

Once the original primary cluster is restored and accessible, failback proceeds by establishing a reverse link from `southcentralus` pulling data written to `mexicocentral` during the outage.

**Step 1 — Stop producers on mexicocentral**

Halt all active producers before establishing the reverse link to prevent diverged write streams.

**Step 2 — Create a reverse cluster link on southcentralus**

```bash
# reverse-mxc-to-scus-link.properties
cat > reverse-mxc-to-scus-link.properties <<EOF
bootstrap.servers=10.2.0.10:9092
security.protocol=SASL_SSL
ssl.truststore.location=/etc/kafka/ssl/truststore.jks
ssl.truststore.password=changeit
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="link-user" password="link-password";
cluster.link.prefix=mxc.
consumer.offset.sync.enable=true
EOF

kafka-cluster-links \
  --bootstrap-server 10.1.0.10:9092 \
  --create \
  --link mexicocentral-to-scus \
  --config-file reverse-mxc-to-scus-link.properties

# Mirror the promoted topics back to southcentralus
kafka-mirrors \
  --bootstrap-server 10.1.0.10:9092 \
  --create \
  --link mexicocentral-to-scus \
  --mirror-topic scus.orders
```

**Step 3 — Wait for catch-up replication**

```bash
kafka-mirrors \
  --bootstrap-server 10.1.0.10:9092 \
  --describe \
  --mirror-topic mxc.scus.orders
# Wait for Max Lag = 0
```

**Step 4 — Promote mirror topics on southcentralus**

```bash
kafka-mirrors \
  --bootstrap-server 10.1.0.10:9092 \
  --promote \
  --mirror-topic mxc.scus.orders
```

**Step 5 — Redirect traffic back to southcentralus**

Update all producer and consumer configurations to use `bootstrap.servers=10.1.0.10:9092`. Recreate the original forward links (`southcentralus → mexicocentral` and `southcentralus → canadaeast`) to resume normal replication for future DR readiness.

---

## Topology Options

### Three Common Topologies

#### Hub-and-Spoke

One central hub cluster (southcentralus) replicates outbound to spoke clusters (mexicocentral, canadaeast). Spokes do not link directly to each other.

```
southcentralus (hub)
     ├──► mexicocentral (spoke)
     └──► canadaeast (spoke)
```

#### Mesh

Every cluster links to every other cluster, providing maximum redundancy.

```
southcentralus ◄──► mexicocentral
southcentralus ◄──► canadaeast
mexicocentral  ◄──► canadaeast
```

#### Chain (Daisy-Chain)

Data flows linearly from one cluster to the next.

```
southcentralus ──► mexicocentral ──► canadaeast
```

---

### Topology Comparison Table

| Topology | Link Count (3 regions) | Failover Complexity | Latency to DR | Resilience | Bandwidth Overhead | Recommended For |
|---|---|---|---|---|---|---|
| **Hub-and-Spoke** | 2 | Low | 1 hop | Medium (hub SPOF) | Medium | Active-passive DR, centralised governance |
| **Mesh** | 6 (bidirectional) | High | 0 hops | High | High | Active-active, maximum resilience |
| **Chain** | 2 | Medium | 2 hops | Low (intermediate SPOF) | Low | Sequential compliance zones, phased migration |

---

### Recommended Topology for kafka-lab

**Recommended: Hub-and-Spoke with a supplemental mexicocentral → canadaeast link**

```
southcentralus (primary hub)
     ├──► mexicocentral (secondary HA)  ──► canadaeast (DR)
     └──► canadaeast (DR, direct link as fallback)
```

**Rationale:**

1. **southcentralus → mexicocentral**: Primary HA link. Serves low-latency failover for the secondary region. `cluster.link.prefix=scus.` keeps topic naming consistent.
2. **southcentralus → canadaeast**: DR link for direct replication from primary. Ensures canadaeast is current even if mexicocentral is unavailable.
3. **mexicocentral → canadaeast**: Supplemental link so that when mexicocentral is promoted during a primary outage, canadaeast continues receiving data from the new primary without manual intervention.

This modified hub-and-spoke avoids the pure chain weakness (intermediate failure blocks DR) while keeping link count manageable (3 unidirectional links vs. 6 in full mesh). The kafka-lab web app dashboard visualises lag and link status for all three links, enabling resiliency testing scenarios such as:
- Primary failure (scus outage): promote on mexicocentral, canadaeast switches to pull from mexicocentral.
- Secondary failure (mexicocentral outage): canadaeast continues receiving directly from southcentralus.
- DR failure: isolated impact, primary and secondary unaffected.

---

## Performance Considerations

### Bandwidth

Cluster Linking replicates data byte-for-byte including the original compression codec. No decompression or recompression occurs, so bandwidth consumption equals the compressed message throughput of the mirrored topics plus a small overhead for control-plane heartbeats (~5–10 KB/s per link). For a 100 MB/s write workload using LZ4 compression at 60% ratio, cross-region link bandwidth will be approximately 60 MB/s per link.

**Bandwidth throttling** prevents links from saturating WAN capacity:

```bash
# Limit the link to 50 MB/s egress from the source perspective
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --alter \
  --link scus-to-mexicocentral \
  --add-config consumer.byte.rate=52428800
```

The `consumer.byte.rate` quota applies to the replication "consumer" identity of the link. You can also apply broker-wide replica quotas via `kafka-configs --entity-type brokers`.

### Latency

Cluster Linking is asynchronous: the link consumer polls the source on an interval controlled by `fetch.min.bytes` and `replica.fetch.wait.max.ms`. Default settings provide sub-second replication lag under normal WAN conditions. The expected end-to-end replication lag for kafka-lab Azure regions is:

| Link | Expected RTT | Typical Replication Lag |
|---|---|---|
| southcentralus → mexicocentral | ~30 ms | < 1 second |
| southcentralus → canadaeast | ~50 ms | < 2 seconds |
| mexicocentral → canadaeast | ~60 ms | < 2 seconds |

### Compression

Use LZ4 or Zstandard (Zstd) on source topics for optimal performance. LZ4 provides fast compression with good ratio; Zstd offers better ratio at modest CPU cost. Gzip has the best ratio but highest CPU overhead and is not recommended for high-throughput real-time topics. Since Cluster Linking preserves compression, set compression once at the producer or topic level:

```bash
kafka-configs \
  --bootstrap-server 10.1.0.10:9092 \
  --entity-type topics \
  --entity-name orders \
  --alter \
  --add-config compression.type=lz4
```

### Fetch Tuning

For high-throughput topics over high-latency WAN links, increase fetch batch sizes to reduce per-round-trip overhead:

```properties
# In link configuration
replica.fetch.max.bytes=10485760       # 10 MB per fetch request
replica.fetch.wait.max.ms=500          # Max wait 500 ms before returning partial batch
fetch.min.bytes=1048576                # Minimum 1 MB before returning (reduces requests)
```

### Mirror Topic Replication Factor

Mirror topics inherit the source topic's partition count but use the destination cluster's default `default.replication.factor`. The `kafka-mirrors --create` command does not accept a `--replication-factor` flag in CP 7.8.x. To override replication factor for a specific mirror topic, use `kafka-configs --alter` after the mirror topic is created:

```bash
# Create the mirror topic (replication factor comes from destination cluster default)
kafka-mirrors \
  --bootstrap-server 10.2.0.10:9092 \
  --create \
  --link scus-to-mexicocentral \
  --mirror-topic orders

# Set replication factor explicitly post-creation if destination default differs
kafka-configs \
  --bootstrap-server 10.2.0.10:9092 \
  --entity-type topics \
  --entity-name scus.orders \
  --alter \
  --add-config replication.factor=3
```

Alternatively, configure the destination broker's `default.replication.factor=3` in `server.properties` before creating the link so all mirror topics inherit the correct value automatically.

### Parallelism

Each partition in a mirrored topic is replicated independently. More partitions yield higher aggregate link throughput. If a topic has few partitions and high throughput, consider increasing partitions before deploying the link to allow parallel fetch threads to distribute work.

---

## Example Configuration

### Complete Link Properties File: scus → mexicocentral

```properties
# scus-to-mexicocentral-link.properties
# Cluster link from southcentralus (source) to mexicocentral (destination)
# Target Confluent Platform: 7.8.x

# --- Source Cluster Connection ---
bootstrap.servers=10.1.0.10:9092

# --- Security ---
security.protocol=SASL_SSL
ssl.truststore.location=/etc/kafka/ssl/scus-truststore.jks
ssl.truststore.password=${file:/etc/kafka/secrets/ssl.properties:truststore.password}
ssl.endpoint.identification.algorithm=https
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="cl-link-user" \
  password="${file:/etc/kafka/secrets/link.properties:link.password}";

# --- Link Identity ---
cluster.link.prefix=scus.

# --- Mirror Topic Auto-Creation ---
auto.create.mirror.topics.enable=true
auto.create.mirror.topics.filters={"topicFilters": \
  [{"name":"*","patternType":"LITERAL","filterType":"INCLUDE"}]}

# --- Consumer Offset Sync ---
consumer.offset.sync.enable=true
consumer.offset.sync.ms=30000

# --- Fetch Tuning (WAN-optimised) ---
replica.fetch.max.bytes=10485760
replica.fetch.wait.max.ms=500
fetch.min.bytes=1048576

# --- ACL Sync (disabled: ACLs managed per-cluster) ---
acl.sync.enable=false
```

### Create Link Command

```bash
# Run on the mexicocentral cluster (destination)
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --create \
  --link scus-to-mexicocentral \
  --config-file scus-to-mexicocentral-link.properties
```

### Consumer Group Filter File

```json
{
  "consumerGroupFilters": [
    { "name": "app-*",     "patternType": "PREFIXED", "filterType": "INCLUDE" },
    { "name": "monitor-*", "patternType": "PREFIXED", "filterType": "INCLUDE" },
    { "name": "test-*",    "patternType": "PREFIXED", "filterType": "EXCLUDE" }
  ]
}
```

Apply during link creation:

```bash
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --create \
  --link scus-to-mexicocentral \
  --config-file scus-to-mexicocentral-link.properties \
  --consumer-group-filters-json-file consumer-group-filters.json
```

### Full 3-Region Link Setup

```bash
# ── Link 1: southcentralus → mexicocentral (HA) ──────────────────────────────
kafka-cluster-links \
  --bootstrap-server 10.2.0.10:9092 \
  --create \
  --link scus-to-mexicocentral \
  --config-file scus-to-mexicocentral-link.properties

# ── Link 2: southcentralus → canadaeast (DR) ─────────────────────────────────
kafka-cluster-links \
  --bootstrap-server 10.3.0.10:9092 \
  --create \
  --link scus-to-canadaeast \
  --config-file scus-to-canadaeast-link.properties    # Same structure, different bootstrap.servers

# ── Link 3: mexicocentral → canadaeast (secondary HA forwarding) ─────────────
# Created after Link 1 mirrors topics to mexicocentral
# Source bootstrap points to mexicocentral, prefix = mxc.
kafka-cluster-links \
  --bootstrap-server 10.3.0.10:9092 \
  --create \
  --link mexicocentral-to-canadaeast \
  --config-file mxc-to-canadaeast-link.properties

# ── Verify all links ──────────────────────────────────────────────────────────
kafka-cluster-links --bootstrap-server 10.2.0.10:9092 --list   # mexicocentral
kafka-cluster-links --bootstrap-server 10.3.0.10:9092 --list   # canadaeast

# ── Check mirror topic lag ────────────────────────────────────────────────────
kafka-mirrors --bootstrap-server 10.2.0.10:9092 --list
kafka-mirrors --bootstrap-server 10.3.0.10:9092 --list
```

---

## References

| Source | URL |
|---|---|
| Cluster Linking Overview — Confluent Platform | <https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/index.html> |
| Configure Cluster Linking — Confluent Platform | <https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html> |
| Manage Mirror Topics — Confluent Platform | <https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/mirror-topics-cp.html> |
| Cluster Linking Commands Reference | <https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/commands.html> |
| FAQ for Cluster Linking — Confluent Platform | <https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/faqs-cp.html> |
| Cluster Linking Disaster Recovery — Confluent Platform | <https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/disaster-recovery.html> |
| Multi-Data Center Architectures — Confluent Platform | <https://docs.confluent.io/platform/current/multi-dc-deployments/multi-region-architectures.html> |
| Tutorial: Multi-Region Clusters — Confluent Platform 7.8 | <https://docs.confluent.io/platform/7.8/multi-dc-deployments/multi-region-tutorial.html> |
| Configure and Manage Cluster Links — Confluent Cloud | <https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/cluster-links-cc.html> |
| Cluster Linking for Hybrid Clouds — Confluent Developer | <https://developer.confluent.io/courses/hybrid-cloud/cluster-linking/> |
