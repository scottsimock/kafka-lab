---
id: doc-6
title: SP0.002 — Confluent Schema Registry
type: other
created_date: '2026-03-30 15:39'
---
# SP0.002 — Confluent Schema Registry

## Executive Summary

Confluent Schema Registry is a centralized repository for managing, validating, and serving schemas used by Kafka producers and consumers. It provides a RESTful API for storing and retrieving Apache Avro, JSON Schema, and Protobuf schemas, and ships with serializer/deserializer (SerDes) libraries that integrate directly into Kafka client applications. Every message produced to Kafka encodes only a compact schema ID in its header rather than the full schema definition, dramatically reducing wire payload size while guaranteeing that producers and consumers share a single, versioned data contract. Schema Registry is a premium component of self-managed Confluent Platform and is included in the 7.8.x distribution installed via standard Confluent packages.

In Confluent Platform 7.8.x, Schema Registry operates as a standalone JVM process (`schema-registry-start`) that maintains all schema data durably inside a single-partition, log-compacted Kafka topic called `_schemas`. Because Kafka is the source of truth, Schema Registry is effectively stateless on disk — any node can be terminated and restarted and will replay the full schema log from the Kafka topic on startup. Leader (primary) election among Schema Registry instances uses the native Kafka group protocol (ZooKeeper-based election was fully removed in Confluent Platform 7.0.0), eliminating the need to deploy or maintain a separate coordination service. Only the elected primary accepts write requests; all secondary nodes serve reads directly and forward writes to the primary automatically.

For the kafka-lab project, Schema Registry is a foundational dependency of the Next.js 15 web application's four-view dashboard architecture. Every Kafka message produced or consumed by the application — whether for topic inspection, consumer group monitoring, cluster metrics, or schema browsing — will use registered schemas to enforce data contracts between the producers (brokers, monitoring agents) and the web application consumers. This guarantees that schema changes are validated before reaching production, prevents silent data corruption from schema drift, and provides an audit trail of all schema versions. The dev environment targets a single Schema Registry instance on a D2s_v5 VM (2 vCPUs, 8 GiB RAM) within the `southcentralus` private VNet, communicating with Kafka brokers exclusively over private endpoints.

---

## Deployment Architecture

### Dev Environment — Single Node (D2s_v5)

The development deployment runs a single Schema Registry instance on an Azure D2s_v5 virtual machine (2 vCPUs, 8 GiB RAM, located in `southcentralus`, resource group `klc-rg-kafkalab-scus`). This is more than sufficient for development workloads: Confluent recommends 1 GiB JVM heap for up to ~10,000 registered schemas, and CPU usage is light since the only computationally intensive operation (schema compatibility checking) occurs infrequently, primarily at schema registration time.

**Topology overview (dev):**

```
Next.js Web App (private VNet)
        │
        │ HTTP :8081 (internal VNet only)
        ▼
Schema Registry Instance (D2s_v5, southcentralus)
        │
        │ PLAINTEXT/SSL :9092 (private endpoint)
        ▼
Kafka Broker Cluster (private VNet)
        │
        ▼
_schemas topic (compacted, RF=1 for dev, RF=3 for prod)
```

**Key characteristics:**
- Schema Registry process: `/opt/confluent/bin/schema-registry-start`
- Config file: `/etc/schema-registry/schema-registry.properties`
- Default listener: `http://0.0.0.0:8081`
- No disk state — all data stored in Kafka `_schemas` topic
- JVM heap: `-Xms512m -Xmx512m` sufficient for dev (1 GiB recommended for production)
- Managed as a `systemd` unit: `confluent-schema-registry.service`

**Package installation (Confluent Platform 7.8.x on Ubuntu/Debian):**

```bash
# Add Confluent apt repository (assumes confluent.list already configured)
sudo apt-get update
sudo apt-get install -y confluent-schema-registry=7.8.*

# Enable and start
sudo systemctl enable confluent-schema-registry
sudo systemctl start confluent-schema-registry
```

---

## Configuration Deep-Dive

All configuration lives in `schema-registry.properties`. The file is located at:
- Confluent Platform install: `$CONFLUENT_HOME/etc/schema-registry/schema-registry.properties`
- System package install: `/etc/schema-registry/schema-registry.properties`

### Core Properties

#### `listeners`
Comma-separated list of `<protocol>://<host>:<port>` entries. Schema Registry listens on all of these for REST API requests.

- **Default:** `http://0.0.0.0:8081`
- **Importance:** High
- **Dev:** `http://0.0.0.0:8081` (plain HTTP on private VNet — acceptable; TLS termination handled by VNet-internal load balancer or application gateway)
- **Prod:** `https://0.0.0.0:8081` with SSL keystore/truststore configured

If multiple listeners are configured, the **first** listener's port is used as the Schema Registry instance's identity for inter-node communication.

#### `host.name`
The advertised hostname used by other Schema Registry nodes and by clients for inter-instance communication. **Must be set in multi-node deployments.**

- **Default:** Current machine IP (auto-detected)
- **Importance:** High
- For single-node dev, may be omitted or set to the VM's private IP.
- For multi-node prod, set to the FQDN/IP resolvable by all other SR instances within the VNet.

#### `kafkastore.bootstrap.servers`
Comma-separated list of Kafka broker addresses. This single setting drives both data storage (writes to `_schemas` topic) and leader election (Kafka group protocol).

- **Default:** `[]` (empty — must be set)
- **Importance:** Medium
- **Format:** `PLAINTEXT://broker1:9092,PLAINTEXT://broker2:9092` or `SSL://broker1:9093`
- **Note:** ZooKeeper-based leader election (`kafkastore.connection.url`) was **removed in CP 7.0.0**. This is the only supported method in 7.8.x.

#### `kafkastore.topic`
The Kafka topic used as the durable commit log for all schema data.

- **Default:** `_schemas`
- **Importance:** High
- **CRITICAL:** This topic must be **compacted** (`cleanup.policy=compact`). Never change this value after initial deployment without full migration planning.
- **Do not modify** replication factor or partition count after creation.
- Manual creation for production (ensure correct settings):

```bash
bin/kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic _schemas \
  --replication-factor 3 \
  --partitions 1 \
  --config cleanup.policy=compact
```

#### `kafkastore.topic.replication.factor`
Desired replication factor for the `_schemas` topic. Actual RF will be `min(this value, live brokers)`.

- **Default:** `3`
- **Dev override:** `1` (single broker dev environment)
- **Prod:** `3`

#### `schema.compatibility.level`
The global default schema compatibility mode applied to all subjects unless overridden per-subject via the REST API.

- **Default:** `BACKWARD`
- **Importance:** High
- **Valid values:** `BACKWARD`, `BACKWARD_TRANSITIVE`, `FORWARD`, `FORWARD_TRANSITIVE`, `FULL`, `FULL_TRANSITIVE`, `NONE`
- Per-subject overrides set via `PUT /config/{subject}` take precedence over this global setting.

#### `schema.registry.group.id`
Consumer group ID used for Kafka leader election. All Schema Registry nodes in the same logical cluster must share the same value.

- **Default:** `schema-registry` (auto-generated as `schema-registry-<host>-<port>` if not set)
- **Recommendation:** Set explicitly to a stable string (e.g., `sr-kafkalab-scus`) to avoid issues after hostname changes.

#### `leader.eligibility`
Controls whether this instance can be elected primary (leader).

- **Default:** `true`
- Set to `false` for Schema Registry nodes in secondary/DR data centers that should never accept writes directly.

#### `kafkastore.security.protocol`
Security protocol for Schema Registry → Kafka broker communication.

- **Default:** `PLAINTEXT`
- **Valid values:** `PLAINTEXT`, `SSL`, `SASL_PLAINTEXT`, `SASL_SSL`
- For private VNet deployments using TLS-terminated private endpoints, set to `SSL` and configure `kafkastore.ssl.*` properties accordingly.

#### `kafkastore.init.timeout.ms`
Timeout in milliseconds for the Kafka store to initialize (includes `_schemas` topic creation if it doesn't exist).

- **Default:** `60000` (60 seconds)

#### `kafkastore.timeout.ms`
Timeout for individual Kafka store operations.

- **Default:** `500` milliseconds

### Kafka Broker Recommendations for `_schemas` Topic

On the Kafka broker side, configure the following for the `_schemas` topic to ensure durability:

```bash
# Set min.insync.replicas > 1 when RF=3 (do NOT set for RF=1 dev)
bin/kafka-configs --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name _schemas \
  --alter --add-config min.insync.replicas=2

# Prevent unclean leader election (potential data loss)
bin/kafka-configs --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name _schemas \
  --alter --add-config unclean.leader.election.enable=false
```

---

## High Availability Setup

### Architecture: Single Primary (Leader-Follower)

Schema Registry is designed around a **single primary architecture**: at any moment, exactly one node is the primary (leader) and is the only node authorized to accept write (registration) requests. All nodes — primary and secondaries — can serve read requests directly. Secondary nodes automatically forward write requests to the current primary and relay the response back to the client.

This design means:
- **Reads are horizontally scalable** — any node handles them.
- **Writes are serialized through the primary** — no split-brain on schema IDs.
- **Failover is automatic** — if the primary node crashes, a new primary is elected from the remaining eligible nodes within the Kafka consumer group rebalance timeout.

### Leader Election Mechanism (Kafka Group Protocol)

Leader election uses the native Kafka consumer group protocol — the same mechanism Kafka Connect and Kafka Streams use for work assignment. The process:

1. All Schema Registry instances with `leader.eligibility=true` join the same Kafka consumer group (`schema.registry.group.id`).
2. Kafka's group coordinator (a Kafka broker) manages membership.
3. One instance is elected group leader by the coordinator.
4. The group leader assigns itself the role of Schema Registry primary.
5. If the primary disconnects (session timeout, crash, network partition), the group rebalances and a new primary is elected automatically.

**No external coordination service is required.** ZooKeeper-based leader election was fully removed in Confluent Platform 7.0.0.

### Single Datacenter HA Setup (Production)

Deploy 2–3 Schema Registry instances within the same region, all pointing to the same Kafka cluster:

```
┌─────────────────────────────────────────┐
│  southcentralus VNet                    │
│                                         │
│  SR-1 (primary)   SR-2 (secondary)      │
│  leader.eligibility=true (both)         │
│           │              │              │
│           └──────┬───────┘              │
│                  │                      │
│            Kafka Cluster                │
│         (_schemas RF=3, ISR=2)          │
└─────────────────────────────────────────┘
```

**Client configuration for HA:**

```properties
# Producer / consumer config — list all SR instances for automatic failover
schema.registry.url=http://sr-1.internal:8081,http://sr-2.internal:8081
```

When multiple URLs are listed in `schema.registry.url`, the client tries each in order on failure, providing seamless failover without DNS changes.

**Key settings for single-DC HA:**

```properties
kafkastore.bootstrap.servers=PLAINTEXT://broker1:9092,PLAINTEXT://broker2:9092,PLAINTEXT://broker3:9092
schema.registry.group.id=sr-kafkalab-scus
leader.eligibility=true
host.name=<this-node-private-ip-or-fqdn>
```

**Runbook — primary node failure:**
1. Remaining nodes detect loss of primary via Kafka consumer group heartbeat timeout (default ~30s).
2. Group rebalances; a new primary is automatically elected.
3. All write requests that were in-flight to the old primary will fail briefly; clients retry automatically.
4. Restart the failed node — it rejoins as a secondary.
5. No manual intervention required.

### Multi-Datacenter Setup (Active-Passive)

For the kafka-lab multi-region topology (southcentralus primary, mexicocentral secondary, canadaeast DR):

- All Schema Registry nodes in **all regions point to the primary Kafka cluster** in `southcentralus`.
- Nodes in `mexicocentral` and `canadaeast` have `leader.eligibility=false` — they are read-only forwarders during normal operation.
- The `_schemas` topic is replicated to secondary clusters using **Confluent Replicator** for DR purposes.
- On DC failover, `_schemas` topic is available in the secondary cluster, and `leader.eligibility` is manually flipped to `true` on the secondary SR nodes.

```properties
# Secondary datacenter (mexicocentral) Schema Registry config
kafkastore.bootstrap.servers=SSL://broker1-scus.internal:9093,...
leader.eligibility=false
host.name=<mexicocentral-node-ip>
schema.registry.group.id=sr-kafkalab-scus
```

### Backup and Restore

The `_schemas` topic is the single source of truth. Back it up using:

```bash
# Backup
bin/kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic _schemas \
  --from-beginning \
  --property print.key=true \
  --timeout-ms 5000 > _schemas-backup.log

# Restore to new topic
bin/kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic _schemas_restore \
  --property parse.key=true < _schemas-backup.log
```

---

## Schema Evolution and Compatibility

Schema Registry enforces configurable compatibility rules whenever a new schema version is registered under a subject. Compatibility is checked by comparing the new schema against the existing registered version(s).

### Compatibility Modes

#### `BACKWARD` (Default)
**Consumers using the new schema can read data written with the previous schema.**

- Allows: adding optional fields with defaults, removing fields
- Prevents: adding required fields without defaults, renaming fields, changing field types incompatibly
- **Use case:** Upgrading consumers before producers. You can rewind consumers to the beginning of the topic and read all historical data.
- **Example (Avro):** Adding a field with a default is backward compatible:

```json
// Version 1
{"type": "record", "name": "User", "fields": [
  {"name": "id",    "type": "int"},
  {"name": "name",  "type": "string"}
]}

// Version 2 — BACKWARD compatible (new field has default)
{"type": "record", "name": "User", "fields": [
  {"name": "id",           "type": "int"},
  {"name": "name",         "type": "string"},
  {"name": "email",        "type": "string", "default": ""}
]}
```
A consumer with schema v2 reading v1 data will use the default `""` for the missing `email` field.

#### `BACKWARD_TRANSITIVE`
Same as `BACKWARD`, but the new schema must be compatible with **all** previously registered versions, not just the latest.

- **Use case:** Long-running consumers that may process data serialized with any historical schema version.

#### `FORWARD`
**Data written with the new schema can be read by consumers using the previous schema.**

- Allows: adding required fields (old consumers will ignore them), removing optional fields
- **Use case:** Upgrading producers before consumers.
- **Example (Avro):** Removing a field is forward compatible:

```json
// Version 1
{"type": "record", "name": "Event", "fields": [
  {"name": "id",        "type": "int"},
  {"name": "timestamp", "type": "long"},
  {"name": "debug_info","type": "string", "default": ""}
]}

// Version 2 — FORWARD compatible (removed optional field)
{"type": "record", "name": "Event", "fields": [
  {"name": "id",        "type": "int"},
  {"name": "timestamp", "type": "long"}
]}
```

#### `FORWARD_TRANSITIVE`
Same as `FORWARD`, but new schema must be compatible with all previously registered schemas.

#### `FULL`
**New schema is both backward AND forward compatible with the latest registered schema.**

- Allows only: adding/removing optional fields with defaults
- **Use case:** Zero-downtime rolling deployments where producer and consumer versions may be mixed at any time.
- Most restrictive — recommended for stable, long-lived schemas.

#### `FULL_TRANSITIVE`
New schema is fully compatible with all previously registered versions. The most conservative mode.

#### `NONE`
No compatibility checks — any schema is accepted. **Not recommended for production.**

### Compatibility Rules by Format

| Change | Avro BACKWARD | Avro FORWARD | Avro FULL | Protobuf BW | JSON Schema BW |
|---|---|---|---|---|---|
| Add optional field (with default) | ✔ | ✔ | ✔ | ✔ | ✔ |
| Remove optional field | ✔ | ✔ | ✔ | ✔ | ✔ |
| Add required field (no default) | ✗ | ✔ | ✗ | ✔ | Open |
| Remove required field | ✔ | ✗ | ✗ | ✗ | Open |
| Rename field | ✗ | ✗ | ✗ | ✗ | ✗ |
| Change field type | ✗ | ✗ | ✗ | ✗ | ✗ |

> **Protobuf best practice:** Use `BACKWARD_TRANSITIVE` for Protobuf schemas. Adding new message types is not forward compatible.

### Per-Subject Compatibility Override

The global `schema.compatibility.level` can be overridden per subject via the REST API. Subject-level settings take precedence:

```bash
# Set FULL_TRANSITIVE for a specific subject
curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"compatibility": "FULL_TRANSITIVE"}' \
  http://schema-registry:8081/config/my-topic-value
```

---

## Serialization Formats

Schema Registry 7.8.x natively supports three serialization formats. All three use the **5-byte magic prefix wire format**: 1 magic byte (`0x00`) + 4-byte schema ID + serialized payload.

### Avro

**Overview:** The original and default Schema Registry format. Avro schemas are JSON documents describing records, fields, types, and defaults. Avro is compact (binary encoding), schema-driven, and was designed with schema evolution as a first-class concern.

**SerDes classes:**
- Producer: `io.confluent.kafka.serializers.KafkaAvroSerializer`
- Consumer: `io.confluent.kafka.serializers.KafkaAvroDeserializer`

**When to use:**
- High-throughput pipelines where wire payload size matters
- Teams comfortable with schema-first development
- Environments using Kafka Streams (only BACKWARD compatibility supported by Kafka Streams)
- Historical default in Confluent ecosystem — widest tool support (Kafka Connect, ksqlDB, Control Center)

**Example Avro schema:**
```json
{
  "type": "record",
  "namespace": "io.kafkalab",
  "name": "TopicMetrics",
  "fields": [
    {"name": "topic_name",     "type": "string"},
    {"name": "partition_count","type": "int"},
    {"name": "message_count",  "type": "long"},
    {"name": "lag",            "type": ["null", "long"], "default": null}
  ]
}
```

**Subject name:** By default uses `TopicNameStrategy` → `<topic-name>-value` and `<topic-name>-key`.

### JSON Schema

**Overview:** Schemas are JSON Schema documents (draft-07 by default). More human-readable than Avro. Two validation policies: **lenient** (open content model, additional properties allowed) and **strict** (closed content model). Payloads are JSON — larger than Avro binary but human-readable.

**SerDes classes:**
- Producer: `io.confluent.kafka.serializers.json.KafkaJsonSchemaSerializer`
- Consumer: `io.confluent.kafka.serializers.json.KafkaJsonSchemaDeserializer`

**When to use:**
- Interoperability with REST APIs or systems already consuming JSON
- Web applications (Next.js) where JSON parsing is native
- Debugging-friendly pipelines (human-readable messages)
- Schema compatibility requirements are less strict

**Example JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "ConsumerGroupStatus",
  "type": "object",
  "properties": {
    "group_id":     {"type": "string"},
    "state":        {"type": "string", "enum": ["Empty","Stable","PreparingRebalance","CompletingRebalance","Dead"]},
    "member_count": {"type": "integer", "minimum": 0},
    "lag":          {"type": "integer", "minimum": 0}
  },
  "required": ["group_id", "state"]
}
```

**Compatibility note:** JSON Schema uses an open content model by default (additional properties allowed), making compatibility rules more nuanced than Avro. Adding required fields is compatible under `BACKWARD` (open model). Use `additionalProperties: false` for strict closed-model validation.

### Protobuf

**Overview:** Google's Protocol Buffers. Binary encoding, strongly typed, language-neutral `.proto` schema definitions. Most compact wire format of the three. Schema Registry supports recursive registration of imported schemas (`.proto` imports).

**SerDes classes:**
- Producer: `io.confluent.kafka.serializers.protobuf.KafkaProtobufSerializer`
- Consumer: `io.confluent.kafka.serializers.protobuf.KafkaProtobufDeserializer`

**When to use:**
- Polyglot environments (Go, Python, Java, C# consumers)
- Maximum wire efficiency
- gRPC-adjacent architectures
- When schema evolution needs are well-understood upfront (Protobuf evolution requires care)

**Example Protobuf schema:**
```protobuf
syntax = "proto3";
package io.kafkalab;
option java_package = "io.kafkalab.proto";

message BrokerMetrics {
  string broker_id    = 1;
  int32  port         = 2;
  double cpu_percent  = 3;
  int64  bytes_in_sec = 4;
}
```

**Best practice:** Use `BACKWARD_TRANSITIVE` for Protobuf; adding new message types is not forward compatible.

### Format Comparison Summary

| Attribute | Avro | JSON Schema | Protobuf |
|---|---|---|---|
| Wire format | Binary (compact) | JSON (verbose) | Binary (most compact) |
| Schema format | JSON | JSON Schema | .proto |
| Human-readable payloads | No | Yes | No |
| Schema evolution support | Excellent | Good | Good |
| Kafka Streams support | Full | Limited | Limited |
| Language support | Java, Python, Go, .NET | Universal | Universal |
| Confluent tool support | Full (widest) | Good | Good |
| Best for kafka-lab | Broker/cluster metrics | Web app API responses | Cross-language integration |

---

## REST API

Schema Registry exposes a RESTful API on port `8081` (default). The preferred content type is `application/vnd.schemaregistry.v1+json`. All write operations are handled only by the primary node; reads can be served by any node.

### Key Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/subjects` | List all subjects |
| `GET` | `/subjects/{subject}/versions` | List all versions for a subject |
| `GET` | `/subjects/{subject}/versions/{version}` | Get a specific schema version |
| `GET` | `/subjects/{subject}/versions/latest` | Get the latest schema version |
| `POST` | `/subjects/{subject}/versions` | Register a new schema version |
| `POST` | `/subjects/{subject}` | Check if a schema is already registered |
| `DELETE` | `/subjects/{subject}` | Delete a subject (soft delete) |
| `DELETE` | `/subjects/{subject}/versions/{version}` | Delete a specific version |
| `GET` | `/schemas/ids/{id}` | Fetch schema by global ID |
| `GET` | `/schemas/ids/{id}/versions` | List all subject-versions for a schema ID |
| `POST` | `/compatibility/subjects/{subject}/versions/{version}` | Test schema compatibility against a version |
| `POST` | `/compatibility/subjects/{subject}/versions` | Test schema against all versions |
| `GET` | `/config` | Get global compatibility config |
| `PUT` | `/config` | Update global compatibility config |
| `GET` | `/config/{subject}` | Get per-subject compatibility config |
| `PUT` | `/config/{subject}` | Update per-subject compatibility config |

### Example curl Commands

**Register an Avro schema:**
```bash
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{
    "schema": "{\"type\":\"record\",\"name\":\"TopicMetrics\",\"namespace\":\"io.kafkalab\",\"fields\":[{\"name\":\"topic_name\",\"type\":\"string\"},{\"name\":\"message_count\",\"type\":\"long\"}]}"
  }' \
  http://schema-registry.internal:8081/subjects/topic-metrics-value/versions
# Response: {"id":1}
```

**Register a JSON Schema:**
```bash
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{
    "schemaType": "JSON",
    "schema": "{\"$schema\":\"http://json-schema.org/draft-07/schema#\",\"title\":\"ConsumerGroupStatus\",\"type\":\"object\",\"properties\":{\"group_id\":{\"type\":\"string\"},\"state\":{\"type\":\"string\"}},\"required\":[\"group_id\",\"state\"]}"
  }' \
  http://schema-registry.internal:8081/subjects/consumer-groups-value/versions
# Response: {"id":2}
```

**Retrieve a schema by global ID:**
```bash
curl -X GET http://schema-registry.internal:8081/schemas/ids/1
# Response: {"schema":"{...avro schema json...}"}
```

**List all subjects:**
```bash
curl -X GET http://schema-registry.internal:8081/subjects
# Response: ["topic-metrics-value","consumer-groups-value"]
```

**Get latest schema version for a subject:**
```bash
curl -X GET http://schema-registry.internal:8081/subjects/topic-metrics-value/versions/latest
# Response: {"subject":"topic-metrics-value","version":1,"id":1,"schema":"{...}"}
```

**Test backward compatibility of a new schema:**
```bash
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{
    "schema": "{\"type\":\"record\",\"name\":\"TopicMetrics\",\"namespace\":\"io.kafkalab\",\"fields\":[{\"name\":\"topic_name\",\"type\":\"string\"},{\"name\":\"message_count\",\"type\":\"long\"},{\"name\":\"lag\",\"type\":[\"null\",\"long\"],\"default\":null}]}"
  }' \
  "http://schema-registry.internal:8081/compatibility/subjects/topic-metrics-value/versions/latest?verbose=true"
# Response: {"is_compatible":true}
```

**Update global compatibility to FULL:**
```bash
curl -X PUT \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"compatibility": "FULL"}' \
  http://schema-registry.internal:8081/config
# Response: {"compatibility":"FULL"}
```

**Check current global config:**
```bash
curl -X GET http://schema-registry.internal:8081/config
# Response: {"compatibility":"BACKWARD"}
```

---

## Example Configuration

Complete `schema-registry.properties` for the kafka-lab dev environment. This assumes:
- Single Schema Registry node on D2s_v5 in `southcentralus`
- Kafka brokers accessible via private VNet on port 9092 (PLAINTEXT within VNet)
- Single-broker dev Kafka (replication factor adjusted to 1)
- Private VNet only — no public endpoint

```properties
# =============================================================================
# Confluent Schema Registry — Dev Environment Configuration
# Host: D2s_v5, southcentralus, klc-rg-kafkalab-scus
# Confluent Platform: 7.8.x
# =============================================================================

# ---------------------------------------------------------------------------
# Listeners — bind to all interfaces, plain HTTP on private VNet only
# ---------------------------------------------------------------------------
listeners=http://0.0.0.0:8081

# Advertised hostname — set to the VM's private IP or internal DNS name
# Replace with actual VM private IP or FQDN from Azure private DNS zone
host.name=schema-registry.kafkalab.internal

# ---------------------------------------------------------------------------
# Kafka Store — connection and topic settings
# ---------------------------------------------------------------------------
# Kafka bootstrap brokers — private VNet endpoints (replace with actual broker addresses)
kafkastore.bootstrap.servers=PLAINTEXT://kafka-broker-1.kafkalab.internal:9092

# Schema storage topic — must be compacted, single partition
kafkastore.topic=_schemas

# Replication factor: 1 for dev (single broker), 3 for prod
kafkastore.topic.replication.factor=1

# Security protocol for broker communication — PLAINTEXT within private VNet
# Change to SSL or SASL_SSL when mTLS is required
kafkastore.security.protocol=PLAINTEXT

# Initialization and operation timeouts
kafkastore.init.timeout.ms=60000
kafkastore.timeout.ms=500

# ---------------------------------------------------------------------------
# Leader Election (Kafka Group Protocol)
# ---------------------------------------------------------------------------
# Consumer group for leader election — all SR nodes in same logical cluster share this
schema.registry.group.id=sr-kafkalab-scus

# This node is eligible to become primary
leader.eligibility=true

# ---------------------------------------------------------------------------
# Schema Compatibility
# ---------------------------------------------------------------------------
# Global default compatibility mode — BACKWARD is the recommended default
schema.compatibility.level=BACKWARD

# ---------------------------------------------------------------------------
# JVM Heap (set in SCHEMA_REGISTRY_JVM_PERFORMANCE_OPTS or systemd override)
# Appropriate for dev; increase to -Xms1g -Xmx1g for production
# ---------------------------------------------------------------------------
# Set in /etc/schema-registry/schema-registry.properties.env or systemd:
# SCHEMA_REGISTRY_HEAP_OPTS="-Xms512m -Xmx512m"
# SCHEMA_REGISTRY_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35"

# ---------------------------------------------------------------------------
# CORS — allow Next.js web app origin (private VNet only)
# ---------------------------------------------------------------------------
access.control.allow.methods=GET,POST,PUT,DELETE,OPTIONS
access.control.allow.origin=http://webapp.kafkalab.internal:3000

# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------
metrics.jmx.prefix=kafka.schema.registry

# ---------------------------------------------------------------------------
# Debug (disable in prod)
# ---------------------------------------------------------------------------
debug=false
```

### Systemd Service Override (JVM Heap)

Create `/etc/systemd/system/confluent-schema-registry.service.d/heap.conf`:

```ini
[Service]
Environment="SCHEMA_REGISTRY_HEAP_OPTS=-Xms512m -Xmx512m"
Environment="SCHEMA_REGISTRY_JVM_PERFORMANCE_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:G1HeapRegionSize=16M"
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart confluent-schema-registry
```

### Verification

```bash
# Health check
curl -s http://schema-registry.kafkalab.internal:8081/ | jq .

# List registered subjects (empty on fresh install)
curl -s http://schema-registry.kafkalab.internal:8081/subjects | jq .

# Confirm compatibility mode
curl -s http://schema-registry.kafkalab.internal:8081/config | jq .
```

---

## References

1. **Confluent Schema Registry Overview**
   https://docs.confluent.io/platform/current/schema-registry/index.html

2. **Schema Registry Deployment Guide (Production)**
   https://docs.confluent.io/platform/current/schema-registry/installation/deployment.html

3. **Schema Registry REST API Reference**
   https://docs.confluent.io/platform/current/schema-registry/develop/api.html

4. **Schema Registry API Usage Examples (curl)**
   https://docs.confluent.io/platform/current/schema-registry/develop/using.html

5. **Schema Registry Configuration Reference**
   https://docs.confluent.io/platform/current/schema-registry/installation/config.html

6. **Schema Evolution and Compatibility**
   https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html

7. **Formats, Serializers, and Deserializers**
   https://docs.confluent.io/platform/current/schema-registry/fundamentals/serdes-develop/index.html

8. **Multi-Datacenter Schema Registry Setup**
   https://docs.confluent.io/platform/current/schema-registry/multidc.html

9. **Understanding Protobuf Compatibility** (Yokota Blog)
   https://yokota.blog/2021/08/26/understanding-protobuf-compatibility/

10. **Understanding JSON Schema Compatibility** (Yokota Blog)
    https://yokota.blog/2021/03/29/understanding-json-schema-compatibility/

11. **Confluent Platform Versions and Interoperability**
    https://docs.confluent.io/platform/current/installation/versions-interoperability.html
