---
id: doc-2
title: Schema Registry Multi-DC Deployment Research
type: other
created_date: '2026-03-28 18:23'
---
# Schema Registry Multi-DC Deployment Research

## Summary

Confluent Schema Registry uses a single-primary architecture where one instance handles all write operations (schema registration/updates) while secondaries serve read requests and forward writes to the primary. For the Kafka Lab's 2-active + 1-DR topology across three Azure regions, we recommend deploying Schema Registry instances per cluster with a primary-eligible cluster in southcentralus, a read-only forwarding cluster in mexicocentral, and a standby DR cluster in canadaeast. The `_schemas` topic must be replicated across clusters using MirrorMaker 2 (or Confluent Replicator) to ensure schema availability during failover. Avro is the recommended serialization format, and modern `confluent-kafka-python` APIs (`AvroSerializer`/`AvroDeserializer`) provide first-class Schema Registry integration for the Python/FastAPI web apps.

## Key Findings

### Schema Registry Architecture

- Schema Registry stores all schemas in a dedicated Kafka topic (`_schemas`) with exactly **1 partition** and a configurable replication factor (recommend RF=3, `min.insync.replicas=2`).
- The `_schemas` topic uses `cleanup.policy=compact` for durable, compacted storage of schema definitions.
- Only one instance across the entire deployment acts as **primary** (leader) — it is the sole writer to `_schemas`. All other instances serve reads and forward writes to the primary.
- Leader election uses the **Kafka group protocol** (ZooKeeper-based election is deprecated since Confluent Platform 7.0). Eligibility is controlled by `leader.eligibility=true|false`.
- Clients can specify multiple Schema Registry URLs (comma-separated) for automatic failover: if the first endpoint is unavailable, the client tries the next.

### Multi-DC Deployment Patterns

- **Single Kafka Cluster, Multi-Node SR (standard HA)**: All SR instances connect to the same Kafka cluster and `_schemas` topic. Leader election among eligible nodes provides automatic failover within the cluster. This is the simplest HA model.
- **Separate Kafka Clusters Per DC (our topology)**: Each DC runs its own Kafka cluster and Schema Registry instances. Only the primary DC's SR instances have `leader.eligibility=true`. Secondary/DR DCs run SR as read-only (`leader.eligibility=false`) and point to their local Kafka cluster. The `_schemas` topic is replicated from primary to secondary/DR clusters via MirrorMaker 2.
- **Cross-cluster leader election is NOT supported** — there is no automatic failover of the SR primary role across separate Kafka clusters. Failover requires operational intervention to promote a secondary DC.

### Schema Compatibility Modes

| Mode | Definition | Upgrade Order | Safe Changes |
|---|---|---|---|
| `BACKWARD` (default) | New schema can read data written with previous schema | Consumers first, then producers | Add optional fields with defaults |
| `FORWARD` | Previous schema can read data written with new schema | Producers first, then consumers | Remove optional fields |
| `FULL` | Both backward and forward compatible | Either order | Add/remove optional fields with defaults only |
| `BACKWARD_TRANSITIVE` | Backward compatible with ALL prior versions | Consumers first | Add optional fields with defaults |
| `FORWARD_TRANSITIVE` | Forward compatible with ALL prior versions | Producers first | Remove optional fields |
| `FULL_TRANSITIVE` | Full compatible with ALL prior versions | Either order | Most restrictive, safest |

**Recommendation for Kafka Lab**: Use `BACKWARD` (the default) for initial deployment. This matches the common pattern where consumers may lag behind producers, and it allows safe schema evolution by adding optional fields with default values. During multi-DC failover, BACKWARD ensures old consumers can still deserialize data produced with newer schemas.

### Failover Behavior

**Within a single cluster (automatic)**:
1. If the primary SR instance fails, Kafka group protocol automatically elects a new primary from leader-eligible nodes.
2. Clients configured with multiple SR URLs transparently retry against surviving instances.
3. No service interruption for reads; brief pause for writes during re-election.

**Across separate Kafka clusters (manual)**:
1. Detect primary DC failure (monitoring/alerting required).
2. Promote secondary DC: update Schema Registry configuration to set `leader.eligibility=true` on secondary DC instances.
3. Restart Schema Registry instances in the promoted DC.
4. Redirect producer/consumer traffic to the new primary DC's SR endpoints.
5. Validate schema availability and ID consistency.

**Schema ID synchronization caveat**: MirrorMaker 2 replicates topic data but does **not** guarantee schema ID parity across clusters. Schema IDs in the secondary cluster may differ from the primary. Clients using the Confluent wire format (magic byte + 4-byte schema ID) will look up schemas by ID from their local registry, which must have the same ID-to-schema mapping. Confluent's proprietary **Schema Linking** feature provides ID-preserving replication but requires Confluent Platform (commercial).

### Serialization Format Decision

| Format | Schema Evolution | Compact Binary | Python Support | Schema Registry Support |
|---|---|---|---|---|
| **Avro** | Excellent (native) | Yes | `confluent-kafka[avro]` + `fastavro` | First-class |
| Protobuf | Good | Yes | `confluent-kafka[protobuf]` | Supported |
| JSON Schema | Limited | No (text-based) | `confluent-kafka[json]` | Supported |

**Recommendation**: **Avro** is the best fit for the Kafka Lab. It has the deepest Schema Registry integration, the most mature Python tooling, compact binary encoding, and native schema evolution support. The Confluent Python client's `AvroSerializer`/`AvroDeserializer` handle schema registration and retrieval automatically.

### Python/FastAPI Client Integration

The modern `confluent-kafka-python` API (v2.x+) replaces the deprecated `AvroProducer`/`AvroConsumer` with explicit serializer/deserializer classes:

- `SchemaRegistryClient` — connects to Schema Registry
- `AvroSerializer` — serializes Python dicts to Avro binary, auto-registers schemas
- `AvroDeserializer` — deserializes Avro binary using schema fetched from registry

Key integration patterns for FastAPI:
- Initialize `SchemaRegistryClient`, `AvroSerializer`, and `AvroDeserializer` at application startup (lifespan event).
- Use `Producer` with manual `avro_serializer(data, ctx)` calls for producing.
- Use `Consumer` with manual `avro_deserializer(msg.value(), ctx)` calls for consuming.
- Manage Kafka client lifecycle via FastAPI's startup/shutdown hooks or dependency injection.
- Use background tasks or worker threads for producing/consuming to avoid blocking the async event loop.

## Architecture / Design Decisions

### Decision 1: Deploy Schema Registry Per Cluster (Primary/Secondary Model)

**Decision**: Deploy SR instances in each of the three regions with the following roles:

| Region | Kafka Cluster Role | SR Instances | leader.eligibility | Behavior |
|---|---|---|---|---|
| southcentralus | Primary (active) | 2 instances | `true` | Handles all writes; serves reads |
| mexicocentral | Secondary (active) | 2 instances | `false` | Read-only; forwards writes to primary |
| canadaeast | DR (passive) | 1 instance | `false` | Standby; reads from replicated `_schemas` |

**Rationale**: Each region's applications need low-latency schema lookups (reads). Writes are infrequent (only during schema registration/evolution) and can tolerate cross-region latency to the primary. This avoids a single point of failure while maintaining schema consistency through the single-primary write model.

### Decision 2: Replicate `_schemas` Topic via MirrorMaker 2

**Decision**: Configure MirrorMaker 2 to explicitly replicate the `_schemas` topic from southcentralus to mexicocentral and canadaeast.

**Rationale**: The `_schemas` topic is filtered out by default in MM2. Explicit inclusion ensures all clusters have schema definitions available locally. Combined with local SR instances, this provides read availability even if cross-region connectivity is lost.

**Configuration requirements**:
- MM2 must include `_schemas` in the topic allowlist
- Use `IdentityReplicationPolicy` (no topic name prefixing) to maintain the `_schemas` topic name across clusters
- Set `sync.topic.configs.enabled=true` to replicate topic configuration

### Decision 3: Use BACKWARD Compatibility as Default

**Decision**: Set `schema.compatibility.level=BACKWARD` globally, with the option to override per-subject.

**Rationale**: BACKWARD is the Confluent default and matches the common operational pattern: consumers are upgraded before producers. It safely allows adding optional fields with defaults — the most common schema evolution operation. For critical topics where bidirectional compatibility is needed, FULL can be set per-subject.

### Decision 4: Avro as Serialization Format

**Decision**: Use Apache Avro for all Kafka message serialization.

**Rationale**: Avro provides compact binary encoding, native schema evolution, and the deepest integration with Confluent Schema Registry. The Python `confluent-kafka[avro]` package provides production-ready serializer/deserializer implementations. Avro schemas are defined in JSON, making them easy to version-control and review.

## Configuration Reference

### Schema Registry Server Properties (Primary DC — southcentralus)

```properties
# Network
listeners=https://0.0.0.0:8081
host.name=schema-registry-scus-01

# Kafka backend
kafkastore.bootstrap.servers=SASL_SSL://kafka-scus-01:9093,SASL_SSL://kafka-scus-02:9093,SASL_SSL://kafka-scus-03:9093
kafkastore.topic=_schemas
kafkastore.topic.replication.factor=3

# Leader election (Kafka group protocol, CP 7.x)
leader.eligibility=true

# Schema compatibility default
schema.compatibility.level=BACKWARD

# Security (SASL/SSL to Kafka)
kafkastore.security.protocol=SASL_SSL
kafkastore.sasl.mechanism=PLAIN
kafkastore.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="schema-registry" \
  password="${SR_KAFKA_PASSWORD}";
kafkastore.ssl.truststore.location=/etc/schema-registry/secrets/kafka.truststore.jks
kafkastore.ssl.truststore.password=${TRUSTSTORE_PASSWORD}

# Inter-instance communication
schema.registry.inter.instance.protocol=https
```

### Schema Registry Server Properties (Secondary DC — mexicocentral)

```properties
listeners=https://0.0.0.0:8081
host.name=schema-registry-mxc-01

# Points to LOCAL Kafka cluster (mexicocentral)
kafkastore.bootstrap.servers=SASL_SSL://kafka-mxc-01:9093,SASL_SSL://kafka-mxc-02:9093,SASL_SSL://kafka-mxc-03:9093
kafkastore.topic=_schemas
kafkastore.topic.replication.factor=3

# NOT leader-eligible — read-only, forwards writes to primary
leader.eligibility=false

# URL of the primary SR cluster for write forwarding
schema.registry.url=https://schema-registry-scus-01:8081,https://schema-registry-scus-02:8081

schema.compatibility.level=BACKWARD
```

### `_schemas` Topic Configuration

```properties
# Created automatically by Schema Registry, but verify/enforce these settings
name=_schemas
partitions=1
replication.factor=3
min.insync.replicas=2
cleanup.policy=compact
```

### MirrorMaker 2 Configuration (for `_schemas` replication)

```properties
# Source cluster (southcentralus)
source.cluster.alias=scus
source.cluster.bootstrap.servers=kafka-scus-01:9093,kafka-scus-02:9093,kafka-scus-03:9093

# Target cluster (mexicocentral)
target.cluster.alias=mxc
target.cluster.bootstrap.servers=kafka-mxc-01:9093,kafka-mxc-02:9093,kafka-mxc-03:9093

# Topic allowlist — explicitly include _schemas
topics=_schemas,.*
topics.exclude=__consumer_offsets,__transaction_state

# Preserve topic names (no prefix)
replication.policy.class=org.apache.kafka.connect.mirror.IdentityReplicationPolicy

# Sync topic configs
sync.topic.configs.enabled=true
sync.topic.acls.enabled=false
```

### Python Client Configuration (Producer with Avro)

```python
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import (
    SerializationContext,
    MessageField,
    StringSerializer,
)

# Schema Registry client — multiple URLs for failover
sr_conf = {
    "url": "https://schema-registry-scus-01:8081,https://schema-registry-scus-02:8081",
    "basic.auth.user.info": f"{SR_API_KEY}:{SR_API_SECRET}",
}
schema_registry_client = SchemaRegistryClient(sr_conf)

# Avro schema definition
value_schema_str = """
{
  "namespace": "com.kafkalab",
  "type": "record",
  "name": "SensorReading",
  "fields": [
    {"name": "sensor_id", "type": "string"},
    {"name": "timestamp", "type": "long", "logicalType": "timestamp-millis"},
    {"name": "temperature", "type": "double"},
    {"name": "humidity", "type": ["null", "double"], "default": null}
  ]
}
"""

def sensor_to_dict(sensor: dict, ctx) -> dict:
    return sensor

avro_serializer = AvroSerializer(
    schema_registry_client,
    value_schema_str,
    sensor_to_dict,
)
string_serializer = StringSerializer("utf_8")

producer_conf = {
    "bootstrap.servers": "kafka-scus-01:9093,kafka-scus-02:9093,kafka-scus-03:9093",
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": KAFKA_API_KEY,
    "sasl.password": KAFKA_API_SECRET,
}
producer = Producer(producer_conf)

# Produce a message
topic = "sensor-readings"
data = {
    "sensor_id": "sensor-001",
    "timestamp": 1711584000000,
    "temperature": 23.5,
    "humidity": 65.2,
}
producer.produce(
    topic=topic,
    key=string_serializer(data["sensor_id"]),
    value=avro_serializer(
        data, SerializationContext(topic, MessageField.VALUE)
    ),
)
producer.flush()
```

### Python Client Configuration (Consumer with Avro)

```python
from confluent_kafka import Consumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import (
    SerializationContext,
    MessageField,
    StringDeserializer,
)

sr_conf = {
    "url": "https://schema-registry-scus-01:8081,https://schema-registry-scus-02:8081",
    "basic.auth.user.info": f"{SR_API_KEY}:{SR_API_SECRET}",
}
schema_registry_client = SchemaRegistryClient(sr_conf)

def dict_to_sensor(obj: dict, ctx) -> dict:
    return obj

avro_deserializer = AvroDeserializer(
    schema_registry_client,
    value_schema_str,
    dict_to_sensor,
)
string_deserializer = StringDeserializer("utf_8")

consumer_conf = {
    "bootstrap.servers": "kafka-scus-01:9093,kafka-scus-02:9093,kafka-scus-03:9093",
    "group.id": "sensor-consumer-group",
    "auto.offset.reset": "earliest",
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": KAFKA_API_KEY,
    "sasl.password": KAFKA_API_SECRET,
}
consumer = Consumer(consumer_conf)
consumer.subscribe(["sensor-readings"])

try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"Consumer error: {msg.error()}")
            continue
        sensor = avro_deserializer(
            msg.value(),
            SerializationContext(msg.topic(), MessageField.VALUE),
        )
        print(f"Received: {sensor}")
finally:
    consumer.close()
```

### FastAPI Lifespan Integration Pattern

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize Kafka clients
    app.state.sr_client = SchemaRegistryClient({"url": SR_URL})
    app.state.avro_serializer = AvroSerializer(
        app.state.sr_client, value_schema_str, sensor_to_dict
    )
    app.state.producer = Producer(producer_conf)
    yield
    # Shutdown: flush and cleanup
    app.state.producer.flush(timeout=10)

app = FastAPI(lifespan=lifespan)

@app.post("/produce")
async def produce_event(sensor_id: str, temperature: float):
    data = {"sensor_id": sensor_id, "temperature": temperature, ...}
    app.state.producer.produce(
        topic="sensor-readings",
        value=app.state.avro_serializer(
            data, SerializationContext("sensor-readings", MessageField.VALUE)
        ),
    )
    app.state.producer.poll(0)  # trigger delivery callbacks
    return {"status": "queued"}
```

## Risks and Open Questions

### Risks

1. **Schema ID Divergence Across Clusters**: MirrorMaker 2 replicates `_schemas` topic data but does not guarantee schema ID parity. After failover to a secondary cluster, schema IDs may differ, potentially causing deserialization failures if clients cache IDs or if the wire format IDs don't match the local registry. **Mitigation**: Use Confluent Replicator (commercial) or Schema Linking for ID-preserving replication; alternatively, ensure clients always resolve schemas via the registry rather than caching IDs locally.

2. **Manual Failover Complexity**: Cross-cluster SR failover is not automatic. It requires operational runbooks, monitoring/alerting for primary DC failure detection, and tested procedures for promoting a secondary. **Mitigation**: Document runbooks; automate promotion scripts; test failover regularly.

3. **Write Latency for Secondary DC Clients**: Applications in mexicocentral that need to register new schemas must forward writes through to the primary SR in southcentralus. Cross-region latency (~30-50ms) adds overhead to schema registration. **Mitigation**: Schema registration is infrequent (only during deployment of new schema versions), so this latency is acceptable for normal operations. Pre-register schemas during CI/CD deployment.

4. **Split-Brain Risk**: If network partitions cause both DCs to believe the other is down, and both promote to primary, schema ID conflicts and data inconsistency can occur. **Mitigation**: Use a quorum-based detection mechanism; require manual confirmation before promotion; use fencing tokens.

### Open Questions

1. **Schema Linking vs MirrorMaker 2**: Should we invest in Confluent Schema Linking (requires Confluent Platform license) for guaranteed ID preservation, or is MM2 replication sufficient for the lab's needs? Schema Linking is the cleaner solution but adds licensing cost.

2. **Schema Registry Instance Count**: Is 2 SR instances per active DC sufficient, or should we run 3 for stronger HA? For the lab environment, 2 per active DC and 1 for DR is likely sufficient.

3. **TLS Certificate Configuration**: Schema Registry should use HTTPS in production. How will TLS certificates be provisioned and rotated for SR instances? This ties into the broader Azure Key Vault + Let's Encrypt automation.

4. **Schema Registration in CI/CD**: Should schemas be pre-registered during the CI/CD pipeline (recommended for controlled evolution), or should the producer auto-register at runtime? Auto-registration is simpler but provides less control over schema evolution.

5. **Monitoring and Alerting**: What metrics should be monitored for Schema Registry health? Key candidates: request latency, error rate, leader election events, `_schemas` topic lag on secondary clusters.

## References

- [Confluent Schema Registry Overview](https://docs.confluent.io/platform/current/schema-registry/index.html)
- [Schema Registry Multi-DC Deployment Architectures](https://docs.confluent.io/platform/current/schema-registry/multidc.html)
- [Schema Registry Configuration Reference](https://docs.confluent.io/platform/current/schema-registry/installation/config.html)
- [Schema Evolution and Compatibility](https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html)
- [Schema Registry Client Configurations](https://docs.confluent.io/platform/current/schema-registry/sr-client-configs.html)
- [Running Schema Registry in Production](https://docs.confluent.io/platform/current/schema-registry/installation/deployment.html)
- [Multi-Datacenter Deployment Solutions Overview](https://docs.confluent.io/platform/current/multi-dc-deployments/index.html)
- [Confluent Replicator for Multi-DC](https://docs.confluent.io/platform/current/multi-dc-deployments/replicator/index.html)
- [Python Client for Apache Kafka](https://docs.confluent.io/kafka-clients/python/current/overview.html)
- [confluent-kafka-python GitHub Repository](https://github.com/confluentinc/confluent-kafka-python)
- [Integrate Python Clients with Schema Registry (Confluent Developer)](https://developer.confluent.io/courses/kafka-python/integrate-with-schema-registry/)
- [confluent-kafka PyPI Package](https://pypi.org/project/confluent-kafka/)
- [Schema Registry Multi-DC with Separate Clusters (Confluent Forum)](https://forum.confluent.io/t/schema-registry-multi-dc-setup-using-separate-kafka-clusters/12337)
- [MirrorMaker 2 and Schema Registry (Confluent Forum)](https://forum.confluent.io/t/mirror-maker-2-and-schema-registry/36523)
