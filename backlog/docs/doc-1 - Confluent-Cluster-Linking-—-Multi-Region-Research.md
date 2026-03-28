---
id: doc-1
title: Confluent Cluster Linking — Multi-Region Research
type: other
created_date: '2026-03-28 18:23'
---
## Summary

Confluent Cluster Linking is a native broker-to-broker replication feature in Confluent Platform 7.x that creates byte-for-byte mirror topics between clusters, preserving offsets, partitioning, and metadata without requiring external Kafka Connect or MirrorMaker infrastructure. For the Kafka Lab three-region topology (southcentralus primary, mexicocentral secondary, canadaeast DR), Cluster Linking provides near-real-time asynchronous replication with RPO of seconds and RTO governed by client failover automation. This document captures architecture, configuration, failover procedures, and risks for the multi-region deployment.

## Key Findings

### Architecture

- **Cluster Link** is a logical connection created on the *destination* cluster that points to the *source* cluster. The destination initiates the connection.
- **Mirror topics** are read-only replicas on the destination cluster. They are exact byte-for-byte copies of source topics — same partitions, same offsets, same message ordering.
- Cluster Linking is enabled by default on Confluent Platform 7.0+. No separate `confluent.cluster.link.enable=true` is needed.
- No external Connect cluster or MirrorMaker infrastructure is required — replication runs within the broker process itself.

### Three-Cluster Topology (Kafka Lab)

- **southcentralus → mexicocentral**: Bidirectional cluster links for active-active replication between the two active regions. Topic prefixing (`cluster.link.prefix`) is **mandatory** to avoid infinite replication loops.
- **southcentralus → canadaeast**: Unidirectional cluster link for passive DR. canadaeast mirrors critical topics from the primary.
- **mexicocentral → canadaeast**: Unidirectional cluster link so DR receives data originating in the secondary region as well.

```text
[southcentralus]  <--- bidirectional --->  [mexicocentral]
       \                                        /
        \--- unidirectional -->  [canadaeast] <-/
                                 (passive DR)
```

### Cluster Linking vs MirrorMaker 2

| Aspect | Cluster Linking | MirrorMaker 2 |
|---|---|---|
| Infrastructure | Built into brokers | Requires separate Kafka Connect cluster |
| Offset preservation | Byte-for-byte identical offsets | Requires offset translation |
| Topic naming | Identical (or prefixed for bidirectional) | Prefixed by default (e.g., `source.topic`) |
| Compression handling | Byte-level pass-through (no decompress/recompress) | Decompress-recompress cycle reduces throughput |
| Consumer failover | Seamless — same offsets, no translation | Requires checkpoint-based offset mapping |
| Licensing | Confluent Platform (enterprise) | Open-source Apache Kafka |
| Operational complexity | Lower (no Connect cluster to manage) | Higher (Connect workers, connector configs) |

### Offset Sync and Consumer Group Migration

- Consumer group offset synchronization is controlled by `consumer.offset.sync.enable=true` on the cluster link configuration.
- Sync interval is controlled by `consumer.offset.sync.ms` (default: 5000 ms, configurable as low as 1000 ms for tighter RPO during cutover windows).
- Specific consumer groups can be targeted via `consumer.offset.group.filters` (JSON array of group IDs).
- On failover, consumers reconnect to the destination cluster using the **same group ID** and resume from the exact synced offset — no translation required.
- Mirror topic promotion (`kafka-mirrors --promote`) or failover (`kafka-mirrors --failover`) converts the read-only mirror topic into a writable standard topic on the destination.

### Failover and Failback Procedures

**Planned Failover (Promote)**:

1. Stop producers writing to the source cluster (or drain with a quiesce period).
2. Monitor mirror lag until destination is fully caught up (lag = 0).
3. Promote mirror topics on destination: `kafka-mirrors --bootstrap-server <DEST>:9092 --promote --topics <topic1,topic2>`.
4. Redirect producers and consumers to the destination cluster.

**Unplanned Failover (DR)**:

1. Detect primary cluster outage via monitoring/alerting.
2. Failover mirror topics on DR cluster: `kafka-mirrors --bootstrap-server <DR>:9092 --failover --topics <topic1,topic2>`.
3. Redirect all clients to the DR cluster (DNS switch, config update, or Ansible-driven reconfiguration).
4. Accept potential data loss equal to the replication lag at time of failure (typically seconds).

**Failback**:

1. Restore the original primary cluster and verify health.
2. Create a new cluster link from the restored primary (now destination) to the currently-active DR cluster (now source).
3. Create mirror topics on the restored primary for all topics that received new data during the outage.
4. Wait for mirror topics to catch up.
5. Promote mirror topics on the restored primary.
6. Redirect clients back to the restored primary.
7. Re-establish original cluster link topology.

### RTO / RPO Profile

| Metric | Value | Notes |
|---|---|---|
| **RPO** | Seconds (typically 1–10 s) | Asynchronous replication; RPO = replication lag at time of failure. Configurable via `consumer.offset.sync.ms`. |
| **RTO** | Minutes (1–5 min typical) | Dominated by client redirect time. Automated DNS/config switching reduces RTO. Mirror topic failover itself is sub-second. |
| **Zero RPO** | Not achievable with Cluster Linking alone | Requires synchronous replication (Multi-Region Clusters with observer replicas), which is a different Confluent Platform feature. |

### Network Partition Behavior

- During a network partition between linked clusters, replication pauses but does **not** corrupt data or lose already-replicated messages.
- When connectivity restores, the cluster link resumes replication from where it left off — no gaps or duplicates.
- Mirror topics remain read-only during a partition; consumers can continue reading already-replicated data on the destination.
- Retry behavior is controlled by `retry.backoff.ms` (base backoff) and `retry.max.backoff.ms` (maximum backoff between retries).

### Network Requirements

- **Port**: TCP 9092 (or the configured Kafka broker listener port). TLS-encrypted connections mandatory for inter-region traffic.
- **Protocol**: The destination cluster initiates connections to the source cluster's broker listener.
- **Authentication**: SASL_SSL recommended. Both clusters must share a compatible authentication mechanism.
- For the Kafka Lab (self-managed on Azure VMs):
  - **VNet peering** between the three regional VNets (southcentralus ↔ mexicocentral, southcentralus ↔ canadaeast, mexicocentral ↔ canadaeast) provides private IP connectivity.
  - Azure VNet peering supports cross-region peering natively.
  - Private endpoints are not required for self-managed clusters (they are an Azure PaaS / Confluent Cloud concept). Direct broker-to-broker connectivity over peered VNets is sufficient.
  - NSG rules must allow TCP 9092 (or configured listener port) between broker subnets in all three regions.
  - DNS resolution must work cross-region so destination brokers can resolve source broker hostnames (private DNS zones or `/etc/hosts` entries via Ansible).

## Architecture / Design Decisions

### Decision 1: Bidirectional links between active clusters, unidirectional to DR

**Rationale**: southcentralus and mexicocentral both serve active workloads. Bidirectional linking allows consumers in each region to read data produced in the other region with minimal latency. canadaeast is passive — it only needs to receive data, never originate it, so unidirectional links suffice.

### Decision 2: Use topic prefixing for bidirectional active-active links

**Rationale**: Without prefixing, bidirectional links create infinite replication loops (topic A mirrors to B, then mirrors back to A). Setting `cluster.link.prefix=scus-` on mexicocentral and `cluster.link.prefix=mxc-` on southcentralus ensures mirrored topics have distinct names. Applications must be configured to consume from both the local topic and the prefixed mirror topic.

### Decision 3: Unidirectional to DR without prefixing

**Rationale**: canadaeast receives one-way mirrors from both active clusters. Since canadaeast never produces data back, there is no loop risk. However, because both active clusters mirror to canadaeast, prefixing is still recommended to avoid topic name collisions (e.g., if both clusters produce to the same topic name). Use `cluster.link.prefix=scus-` for the southcentralus link and `cluster.link.prefix=mxc-` for the mexicocentral link on canadaeast.

### Decision 4: Consumer offset sync enabled with 5-second interval

**Rationale**: The default `consumer.offset.sync.ms=5000` provides a good balance between overhead and RPO for consumer group migration. During planned failover windows, this can be temporarily reduced to 1000 ms for tighter offset sync.

### Decision 5: VNet peering for inter-cluster networking

**Rationale**: Self-managed Confluent Platform brokers on Azure VMs communicate via standard Kafka listeners. VNet peering provides low-latency, private, encrypted-in-transit connectivity between Azure regions without exposing brokers to the public internet. This aligns with the project's private networking requirements.

## Configuration Reference

### Cluster Link Configuration File (southcentralus → mexicocentral)

```properties
# link-scus-to-mxc.properties (created on mexicocentral destination cluster)
bootstrap.servers=scus-broker-0:9092,scus-broker-1:9092,scus-broker-2:9092
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="link-user" \
  password="<secret>";
ssl.truststore.location=/etc/kafka/ssl/truststore.jks
ssl.truststore.password=<secret>

# Mirror topic settings
auto.create.mirror.topics.enable=true
auto.create.mirror.topics.filters={"topicFilters":[{"name":"*","patternType":"LITERAL","filterType":"INCLUDE"}]}

# Consumer offset sync
consumer.offset.sync.enable=true
consumer.offset.sync.ms=5000
consumer.offset.group.filters={"groupFilters":[{"name":"*","patternType":"LITERAL","filterType":"INCLUDE"}]}

# Topic prefixing (required for bidirectional)
cluster.link.prefix=scus-

# ACL sync
acl.sync.enable=true
acl.sync.ms=5000
```

### CLI Commands

**Create a cluster link on the destination cluster**:

```bash
kafka-cluster-links --bootstrap-server mxc-broker-0:9092 \
  --create --link scus-to-mxc \
  --config-file link-scus-to-mxc.properties \
  --command-config admin-client.properties
```

**Create a mirror topic (if auto-create is disabled)**:

```bash
kafka-mirrors --create \
  --bootstrap-server mxc-broker-0:9092 \
  --link scus-to-mxc \
  --mirror-topic orders \
  --command-config admin-client.properties
```

**List cluster links**:

```bash
kafka-cluster-links --list \
  --bootstrap-server mxc-broker-0:9092 \
  --command-config admin-client.properties
```

**Monitor mirror topic lag**:

```bash
kafka-mirrors --describe \
  --bootstrap-server mxc-broker-0:9092 \
  --link scus-to-mxc \
  --command-config admin-client.properties
```

**Promote mirror topics (planned failover)**:

```bash
kafka-mirrors --promote \
  --topics orders,payments,inventory \
  --bootstrap-server mxc-broker-0:9092 \
  --command-config admin-client.properties
```

**Failover mirror topics (unplanned DR)**:

```bash
kafka-mirrors --failover \
  --topics orders,payments,inventory \
  --bootstrap-server cae-broker-0:9092 \
  --command-config admin-client.properties
```

### Key Broker-Level Properties

| Property | Default (CP 7.x) | Notes |
|---|---|---|
| `confluent.cluster.link.enable` | `true` | Enabled by default since CP 7.0 |
| `confluent.balancer.topic.replication.factor` | `3` | Ensures internal link metadata topics are replicated |

### Key Link-Level Properties

| Property | Default | Description |
|---|---|---|
| `consumer.offset.sync.enable` | `false` | Enable consumer group offset mirroring |
| `consumer.offset.sync.ms` | `5000` | Offset sync interval in milliseconds |
| `auto.create.mirror.topics.enable` | `false` | Auto-create mirror topics for new source topics |
| `acl.sync.enable` | `false` | Sync ACLs from source to destination |
| `acl.sync.ms` | `5000` | ACL sync polling interval |
| `cluster.link.prefix` | (empty) | Prefix for mirror topic names (required for bidirectional) |
| `consumer.group.prefix.enable` | `false` | Prefix consumer group names from the source |
| `retry.backoff.ms` | `1000` | Base backoff between retry attempts |
| `retry.max.backoff.ms` | `30000` | Maximum backoff between retry attempts |

## Risks and Open Questions

### Risks

1. **Active-active write conflicts**: Bidirectional linking with topic prefixing means applications must be aware of both local and prefixed mirror topics. Incorrect application routing could cause data duplication or loss. Mitigation: strict topic naming conventions and application-level routing rules.

2. **Transactional topics**: Cluster Linking does not fully support Kafka transactions (exactly-once semantics) across linked clusters. Transactional IDs and producer state are not mirrored. If the Kafka Lab uses transactional producers, additional design work is required.

3. **Schema Registry sync**: Cluster Linking mirrors topic data but does **not** automatically sync Schema Registry schemas. A separate Schema Registry replication or shared Schema Registry strategy is needed.

4. **Replication lag under load**: During initial catch-up (e.g., after link creation with existing topics) or sustained high throughput, replication lag can spike. This directly impacts RPO. Bandwidth between Azure regions must be monitored and potentially throttled with Kafka client quotas.

5. **Network partition duration**: Extended network partitions (hours+) will cause the destination cluster's mirror topics to fall significantly behind. When connectivity restores, a large catch-up burst may impact broker performance on both clusters.

6. **Failback complexity**: Failback after a DR event requires creating reverse links, mirroring accumulated data back, and re-establishing the original topology. This is operationally complex and must be rehearsed.

### Open Questions

1. **Topic selection**: Which topics are critical enough to mirror to all three clusters vs. only to the DR cluster? A tiered topic classification (Tier 1: all clusters, Tier 2: DR only, Tier 3: no replication) is needed.

2. **Consumer routing strategy**: For active-active, how do consumers in each region discover and consume from both local and prefixed mirror topics? Consider a fan-in consumer pattern or application-level topic routing.

3. **Schema Registry HA**: Will Schema Registry run as a shared cluster across regions, or will each region have its own instance with a separate sync mechanism?

4. **Monitoring and alerting thresholds**: What mirror lag thresholds (in ms or message count) trigger alerts? What lag is acceptable for the Kafka Lab's SLO?

5. **Chaos experiment integration**: How will Azure Chaos Studio experiments interact with cluster links? Specific experiments to design: network partition between regions, single broker failure on source, full region outage.

6. **License scope**: Cluster Linking requires Confluent Platform enterprise license. Confirm license coverage for all three clusters.

## References

- [Cluster Linking Overview — Confluent Platform](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/index.html)
- [Cluster Linking Configuration Options](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html)
- [Cluster Linking CLI Command Reference](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/commands.html)
- [Mirror Topic Management](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/mirror-topics-cp.html)
- [Cluster Linking DR and Failover (Cloud reference)](https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/dr-failover.html)
- [Multi-Data Center Architectures](https://docs.confluent.io/platform/current/multi-dc-deployments/multi-region-architectures.html)
- [Data Migration with Cluster Linking](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/migrate-cp.html)
- [Cluster Linking Private Networking](https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/private-networking.html)
- [Cluster Linking FAQ](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/faqs-cp.html)
- [Multi-Region Cluster Tutorial](https://docs.confluent.io/platform/current/multi-dc-deployments/multi-region-tutorial.html)
- [Confluent DR Best Practices Whitepaper](https://www.confluent.io/resources/white-paper/best-practices-disaster-recovery/)
- [Kafka Replicator Comparison Guide — Lenses.io](https://lenses.io/blog/kafka-replicator-comparison-guide-lenses-k2k)
