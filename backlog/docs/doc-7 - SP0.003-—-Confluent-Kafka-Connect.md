---
id: doc-7
title: SP0.003 — Confluent Kafka Connect
type: other
created_date: '2026-03-30 15:40'
---
# SP0.003 — Confluent Kafka Connect

## Executive Summary

Kafka Connect is the integration framework within Confluent Platform 7.8.x that reliably streams data between Apache Kafka and external systems at scale. It is a free, open-source component that provides a data-centric pipeline abstraction: connectors define where data should be copied to or from, tasks execute the actual data movement in parallel, workers are the JVM processes that host connectors and tasks, and converters translate between Kafka's binary wire format and the external system's native format. In Confluent Platform 7.8.x, Kafka Connect ships with the full Confluent enterprise feature set, including enhanced Avro/Protobuf/JSON Schema converter support via Schema Registry, role-based access control integration, centralized license management, and a curated catalog of pre-built enterprise connectors available through Confluent Hub. The distributed worker model uses Kafka's consumer group protocol to coordinate work across the cluster, store all state (connector configs, offsets, and task statuses) durably in compacted Kafka topics, and automatically rebalance when workers join or leave.

For the kafka-lab project, Kafka Connect serves as the tiered storage and data archival layer. The Azure Blob Storage Sink Connector exports processed Kafka topic data to Azure Blob Storage containers for long-term retention, cost-optimised cold storage, and downstream batch analytics. Because all kafka-lab resources operate within private Azure VNets with no public endpoints, the Connect worker communicates with Azure Blob Storage exclusively through Azure Private Endpoints, with DNS resolution handled by Azure Private DNS Zones linked to the VNet. This design satisfies the project's compliance requirements for data in transit (TLS 1.2+), data at rest (CMEK on the storage account), and authentication (User Assigned Managed Identity). The Connect worker itself runs on a D2s_v5 VM in the `southcentralus` primary region, deployed into the private subnet of the VNet.

Operationally, Kafka Connect exposes a REST API on port 8083 that serves as the primary management interface for deploying, updating, pausing, resuming, and deleting connectors without any worker restart. JMX metrics provide deep visibility into worker, connector, and task performance. Error handling is configurable per connector: invalid or unprocessable records can be tolerated and routed to a Dead Letter Queue (DLQ) Kafka topic, preserving original error context in record headers for forensic analysis. Together, these capabilities make Kafka Connect the preferred integration runtime for the kafka-lab project — reliable, operationally straightforward, and deeply observable.

---

## Distributed Mode Configuration

In distributed mode, all workers sharing the same `group.id` form a single Connect cluster. Workers elect a leader via Kafka's consumer group protocol. The leader is responsible for assigning connectors and tasks to workers. All cluster configuration, offset, and status state is stored in dedicated Kafka topics, meaning the cluster is stateless from a process perspective — any worker can be killed and replaced with no data loss.

### Core Worker Properties

The following properties are required in `connect-distributed.properties` for every distributed worker.

| Property | Purpose | Notes |
|---|---|---|
| `bootstrap.servers` | Kafka broker list for initial connection | Use all brokers: `broker1:9092,broker2:9092,broker3:9092` |
| `group.id` | Identifies which Connect cluster this worker belongs to | Must be identical across all workers in the same cluster; use a descriptive, environment-scoped name |
| `config.storage.topic` | Kafka topic where connector and task configurations are durably stored | Must be identical for all workers with the same `group.id`; must be a single-partition compacted topic |
| `offset.storage.topic` | Kafka topic where connector offsets are stored | Must be identical for all workers with the same `group.id`; use compacted topic with ≥25 partitions |
| `status.storage.topic` | Kafka topic where connector and task status updates are stored | Must be identical for all workers with the same `group.id`; use compacted topic with ≥5 partitions |
| `key.converter` | Converter class for message keys | Common: `org.apache.kafka.connect.json.JsonConverter` or `io.confluent.connect.avro.AvroConverter` |
| `value.converter` | Converter class for message values | Common: `io.confluent.connect.avro.AvroConverter` with Schema Registry |
| `plugin.path` | Comma-separated paths to directories containing connector plugin JARs | e.g., `/usr/share/java,/usr/share/confluent-hub-components` |
| `rest.port` | Port for the Connect REST API | Default: `8083` |
| `rest.advertised.host.name` | Hostname advertised to other workers for inter-worker communication | Set to the VM's private IP or DNS name; required when behind a private VNet |

### Internal Topic Replication

For production (3+ brokers), always set replication factors ≥ 3:

```properties
config.storage.replication.factor=3
offset.storage.replication.factor=3
status.storage.replication.factor=3
```

For a single-broker dev environment (D2s_v5), set these to `1`.

### Topic Cleanup Policy

Internal topics must use `cleanup.policy=compact`. Connect attempts to auto-create them on startup, but pre-creating them with the correct settings is recommended for production:

```bash
# Pre-create internal Connect topics (run once per cluster)
kafka-topics --bootstrap-server broker:9092 \
  --create --topic connect-configs \
  --partitions 1 --replication-factor 3 \
  --config cleanup.policy=compact

kafka-topics --bootstrap-server broker:9092 \
  --create --topic connect-offsets \
  --partitions 25 --replication-factor 3 \
  --config cleanup.policy=compact

kafka-topics --bootstrap-server broker:9092 \
  --create --topic connect-status \
  --partitions 5 --replication-factor 3 \
  --config cleanup.policy=compact
```

### Security (SASL/SSL for Kafka Communication)

When the Kafka cluster requires mutual TLS or SASL authentication, add the following to `connect-distributed.properties`:

```properties
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="connect-worker" \
  password="<password>";
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.jks
ssl.truststore.password=<password>
```

### Offset Flush

```properties
# Interval at which tasks commit offsets (milliseconds)
offset.flush.interval.ms=10000
```

---

## Connector Lifecycle Management

The Kafka Connect REST API runs on port `8083` by default. In distributed mode, requests can be sent to any worker — the receiving worker forwards to the cluster leader as needed. The API is the **only** mechanism for managing connectors; there are no CLI tools in distributed mode.

All requests require the header `Content-Type: application/json`. Sensitive fields (passwords, keys) are masked with `***` in API responses.

### Health Check

```bash
# Verify worker is up; returns version, git commit, and Kafka cluster ID
curl -s http://connect-worker:8083/ | jq
```

Example response:
```json
{
  "version": "7.8.0-ce",
  "commit": "e5741b90cde98052",
  "kafka_cluster_id": "I4ZmrWqfT2e-upky_4fdPA"
}
```

### List Connectors

```bash
# List all deployed connectors
curl -s http://connect-worker:8083/connectors | jq

# List with status expanded
curl -s "http://connect-worker:8083/connectors?expand=status" | jq

# List with config and status expanded
curl -s "http://connect-worker:8083/connectors?expand=status&expand=info" | jq
```

### Deploy (Create) a Connector

```bash
curl -s -X POST http://connect-worker:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "azure-blob-sink",
    "config": {
      "connector.class": "io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector",
      "tasks.max": "2",
      "topics": "my-topic",
      "azblob.account.name": "myaccount",
      "azblob.account.key": "<key>",
      "azblob.container.name": "kafka-archive",
      "format.class": "io.confluent.connect.azure.blob.format.avro.AvroFormat",
      "flush.size": "1000"
    }
  }' | jq
```

Returns `201 Created` on success, `409 Conflict` if a rebalance is in progress.

### Get Connector Status

```bash
curl -s http://connect-worker:8083/connectors/azure-blob-sink/status | jq
```

Example response:
```json
{
  "name": "azure-blob-sink",
  "connector": {
    "state": "RUNNING",
    "worker_id": "10.0.0.5:8083"
  },
  "tasks": [
    { "id": 0, "state": "RUNNING", "worker_id": "10.0.0.5:8083" },
    { "id": 1, "state": "RUNNING", "worker_id": "10.0.0.5:8083" }
  ],
  "type": "sink"
}
```

Possible states: `UNASSIGNED`, `RUNNING`, `PAUSED`, `STOPPED`, `FAILED`.

### Update Connector Configuration

```bash
# PUT replaces the entire config; note: no "config" wrapper unlike POST
curl -s -X PUT http://connect-worker:8083/connectors/azure-blob-sink/config \
  -H "Content-Type: application/json" \
  -d '{ "connector.class": "...", "tasks.max": "4", ... }' | jq
```

### Pause a Connector

```bash
# Pause suspends all tasks without deleting the connector or losing offsets
curl -s -X PUT http://connect-worker:8083/connectors/azure-blob-sink/pause
# Returns 202 Accepted
```

Useful for temporarily stopping data flow during downstream maintenance.

### Resume a Paused Connector

```bash
curl -s -X PUT http://connect-worker:8083/connectors/azure-blob-sink/resume
# Returns 202 Accepted
```

### Restart a Connector (and Optionally Its Tasks)

```bash
# Restart connector instance only (not tasks)
curl -s -X POST http://connect-worker:8083/connectors/azure-blob-sink/restart

# Restart connector and all failed tasks
curl -s -X POST "http://connect-worker:8083/connectors/azure-blob-sink/restart?includeTasks=true&onlyFailed=true"
# Returns 202 Accepted with status showing RESTARTING tasks
```

Note: restarting the connector does **not** automatically restart tasks. Use `includeTasks=true` to restart tasks.

### Restart an Individual Task

```bash
# Restart task ID 0
curl -s -X POST http://connect-worker:8083/connectors/azure-blob-sink/tasks/0/restart
```

### Stop a Connector (Without Deleting)

```bash
# Stop halts all tasks but retains connector config and offsets
curl -s -X PUT http://connect-worker:8083/connectors/azure-blob-sink/stop
# Returns 202 Accepted
```

### Delete a Connector

```bash
# Permanently deletes the connector, halting all tasks and removing config
curl -s -X DELETE http://connect-worker:8083/connectors/azure-blob-sink
# Returns 204 No Content
```

### List Installed Connector Plugins

```bash
curl -s http://connect-worker:8083/connector-plugins | jq
```

---

## Azure Blob Storage Sink Connector

The Azure Blob Storage Sink Connector (`io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector`) exports data from Kafka topics to Azure Blob Storage containers. It periodically polls Kafka, batches records according to a configurable flush strategy, and uploads objects to Blob Storage using the Azure SDK.

### Install the Connector Plugin

```bash
# Install the latest version via Confluent Hub CLI
confluent connect plugin install confluentinc/kafka-connect-azure-blob-storage:latest

# Or a specific version
confluent connect plugin install confluentinc/kafka-connect-azure-blob-storage:2.2.0
```

The JAR is placed in `$CONFLUENT_HOME/share/confluent-hub-components/`. Ensure `plugin.path` in `connect-distributed.properties` includes this directory.

### Key Configuration Properties

| Property | Description | Required |
|---|---|---|
| `connector.class` | `io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector` | Yes |
| `tasks.max` | Number of parallel tasks | Yes |
| `topics` | Comma-separated list of source Kafka topics | Yes |
| `azblob.account.name` | Azure Storage account name (3–24 alphanumeric characters) | Yes |
| `azblob.account.key` | Storage account key (password type — masked in API responses) | Yes* |
| `azblob.container.name` | Target container name (3–63 alphanumeric + `-`) | Yes |
| `format.class` | Output format class | Yes |
| `flush.size` | Number of records per Blob Storage object before rotating | Yes |
| `rotate.interval.ms` | Time-based rotation threshold in milliseconds (`-1` = disabled) | No |
| `partitioner.class` | Partitioner for organizing objects in blob paths | No |
| `schema.compatibility` | Schema evolution strategy: `NONE`, `BACKWARD`, `FORWARD`, `FULL` | No |
| `storage.class` | Storage implementation class | No |
| `topics.dir` | Top-level directory prefix in the container | No |

*`azblob.account.key` is the standard authentication method. See UAMI note below.

### Format Classes

| Format | `format.class` value |
|---|---|
| Avro | `io.confluent.connect.azure.blob.format.avro.AvroFormat` |
| Parquet | `io.confluent.connect.azure.blob.format.parquet.ParquetFormat` |
| JSON | `io.confluent.connect.azure.blob.format.json.JsonFormat` |
| Bytes | `io.confluent.connect.azure.blob.format.bytearray.ByteArrayFormat` |

### Partitioner Classes

| Partitioner | Class | Key config |
|---|---|---|
| Default (by Kafka partition) | `io.confluent.connect.storage.partitioner.DefaultPartitioner` | None |
| Time-based | `io.confluent.connect.storage.partitioner.TimeBasedPartitioner` | `path.format`, `partition.duration.ms`, `timezone`, `timestamp.extractor` |
| Field-based | `io.confluent.connect.storage.partitioner.FieldPartitioner` | `partition.field.name` |

### Object Naming

Objects in Blob Storage follow the pattern:
```
{topics.dir}/{topic}/{partition}/{topic}+{partition}+{start-offset}.{extension}
```

With `TimeBasedPartitioner` and `path.format='year'=YYYY/'month'=MM/'day'=dd/'hour'=HH`:
```
topics/my-topic/year=2025/month=01/day=15/hour=08/my-topic+0+0000000000.avro
```

### Private Endpoint and CMEK

#### Private Endpoint
Azure Private Endpoints for Blob Storage use the DNS zone `privatelink.blob.core.windows.net`. When the Connect worker's VNet has a Private DNS Zone linked with an A record for `<account-name>.privatelink.blob.core.windows.net` → private endpoint NIC IP, the Azure SDK in the connector resolves `<account-name>.blob.core.windows.net` through the CNAME chain to the private endpoint IP automatically. No connector-level configuration change is required — connectivity is entirely at the network and DNS layer.

Key steps:
1. Create a Private Endpoint for the Azure Blob Storage account in the Connect worker's VNet
2. Create a Private DNS Zone: `privatelink.blob.core.windows.net`
3. Link the Private DNS Zone to the Connect worker's VNet
4. Add an A record: `<account-name>` → private endpoint NIC IP
5. Set `public_network_access_enabled = false` on the storage account
6. The connector's `azblob.account.name` remains the storage account name — DNS resolution handles routing

#### CMEK (Customer Managed Key)
CMEK encryption is configured at the Azure Storage Account level, not in the connector. When an Azure Key Vault key is assigned to the storage account as the CMEK, all blobs written by the connector are transparently encrypted with that key. No connector-side configuration is needed.

Azure setup:
1. Create an Azure Key Vault with the CMK and appropriate key permissions
2. Enable the storage account's customer-managed key feature, pointing to the Key Vault key
3. Grant the storage account's managed identity the `Key Vault Crypto User` role on the Key Vault

#### UAMI Authentication
The Confluent Azure Blob connector's primary authentication method is `azblob.account.key`. For kafka-lab's UAMI requirement:

**Recommended approach:** Assign the Connect worker VM's User Assigned Managed Identity the `Storage Blob Data Contributor` role on the target container. Generate a User Delegation SAS token (scoped to the container) using the UAMI's credential, store it in Azure Key Vault, and inject it as an environment variable (`AZBLOB_SAS_TOKEN`). Reference it in the connector config via an environment variable substitution or Secrets Management integration.

Alternatively, use the Azure Blob Connector's `azblob.connection.string` property with a connection string that points to the private endpoint hostname — this gives flexibility to inject auth credentials without embedding them in the connector config.

For a zero-secrets approach using DefaultAzureCredential (picking up the UAMI from the VM metadata service), ensure the connector version supports MSI and configure:
```json
"azblob.account.name": "<account-name>",
"azblob.use.managed.identity": "true"
```
Note: verify this property is available in the specific connector version installed, as it may differ by connector release.

### Exactly-Once Delivery

The connector supports exactly-once semantics when using `DefaultPartitioner` or `FieldPartitioner`. With `TimeBasedPartitioner`, exactly-once requires `timestamp.extractor=Record` (or `RecordField`) **and** `rotate.interval.ms` (not `rotate.schedule.interval.ms`). Using `rotate.schedule.interval.ms` invalidates exactly-once guarantees.

### Schema Evolution

`schema.compatibility` controls behavior when Kafka record schemas change:
- `NONE` (default): Each schema change creates a new file; no cross-schema projections
- `BACKWARD`: New schema used to read all data; records with older schemas are projected forward
- `FORWARD`: Old schema used to read all data; newer fields are dropped on write
- `FULL`: Combines BACKWARD and FORWARD behavior

---

## Monitoring Connect Workers

### REST API Health Check

The simplest liveness check — verify the worker is up and connected to the Kafka cluster:

```bash
# Worker version and Kafka cluster connectivity
curl -s http://connect-worker:8083/ | jq '.version'

# All connectors with status
curl -s "http://connect-worker:8083/connectors?expand=status" | jq '
  to_entries[] | {
    name: .key,
    state: .value.status.connector.state,
    tasks: [.value.status.tasks[] | {id: .id, state: .state}]
  }'
```

A `200 OK` with a valid JSON body confirms the worker process is running. Check that all connectors show `"state": "RUNNING"` and all tasks show `"state": "RUNNING"`.

### JMX Configuration

Enable JMX on the Connect worker by setting these environment variables before starting the process:

```bash
export KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote \
  -Dcom.sun.management.jmxremote.port=9999 \
  -Dcom.sun.management.jmxremote.rmi.port=9999 \
  -Dcom.sun.management.jmxremote.authenticate=false \
  -Dcom.sun.management.jmxremote.ssl=false \
  -Djava.rmi.server.hostname=<worker-private-ip>"
```

For production, enable authentication and SSL on JMX. For the dev D2s_v5 environment, the above is acceptable within the private VNet.

### Key JMX MBeans and Metrics

#### Connector Metrics
**MBean:** `kafka.connect:type=connector-metrics,connector="{name}"`

| Metric | Description | Alert Threshold |
|---|---|---|
| `status` | Current state: running, paused, stopped | Alert if not `running` |
| `connector-type` | source or sink | Informational |
| `connector-version` | Plugin version | Informational |

#### Task Metrics (Common)
**MBean:** `kafka.connect:type=connector-task-metrics,connector="{name}",task="{id}"`

| Metric | Description | Alert Threshold |
|---|---|---|
| `status` | Task state: running, paused, failed, unassigned | Alert if `failed` |
| `running-ratio` | Fraction of time task spent running (0.0–1.0) | Alert if < 0.9 |
| `pause-ratio` | Fraction of time task spent paused | Alert if > 0.1 unexpectedly |
| `offset-commit-success-percentage` | % of offset commits that succeeded | Alert if < 99% |
| `offset-commit-avg-time-ms` | Average time to commit offsets (ms) | Alert if > 5000 ms |
| `batch-size-avg` | Average batch size processed | Informational |

#### Sink Task Metrics
**MBean:** `kafka.connect:type=sink-task-metrics,connector="{name}",task="{id}"`

| Metric | Description | Alert Threshold |
|---|---|---|
| `sink-record-read-rate` | Records/sec read from Kafka | Alert if 0 when expected non-zero |
| `sink-record-send-rate` | Records/sec sent to sink after transforms | Monitor for drops |
| `sink-record-active-count` | Records read but not yet committed to sink | Alert if consistently growing |
| `put-batch-avg-time-ms` | Avg time per batch write to Azure Blob | Alert if > 30000 ms |
| `offset-commit-completion-rate` | Successful offset commits/sec | Alert if 0 |

#### Worker Metrics
**MBean:** `kafka.connect:type=connect-worker-metrics`

| Metric | Description | Alert Threshold |
|---|---|---|
| `connector-count` | Number of connectors running on this worker | Informational |
| `task-count` | Number of tasks running on this worker | Informational |
| `connector-startup-failure-total` | Total failed connector starts | Alert if > 0 and growing |
| `task-startup-failure-total` | Total failed task starts | Alert if > 0 and growing |

#### Worker Rebalance Metrics
**MBean:** `kafka.connect:type=connect-worker-rebalance-metrics`

| Metric | Description | Alert Threshold |
|---|---|---|
| `rebalancing` | Whether the worker is currently rebalancing | Alert if `true` for > 60 s |
| `rebalance-avg-time-ms` | Average time to complete a rebalance | Alert if > 30000 ms |
| `time-since-last-rebalance-ms` | Milliseconds since last rebalance | Alert if rebalancing too frequently |
| `completed-rebalances-total` | Total rebalances completed | Monitor rate of increase |

#### Task Error Metrics
**MBean:** `kafka.connect:type=task-error-metrics,connector="{name}",task="{id}"`

| Metric | Description | Alert Threshold |
|---|---|---|
| `total-record-errors` | Records that caused errors | Alert if > 0 (with `errors.tolerance=none`) |
| `total-records-skipped` | Records skipped due to errors (with tolerance=all) | Alert if > acceptable threshold |
| `deadletterqueue-produce-failures` | Failed writes to DLQ | Alert if > 0 |
| `last-error-timestamp` | Epoch ms of last error | Alert if recent |

---

## Error Handling

### errors.tolerance

The `errors.tolerance` connector configuration property controls how the connector handles records that cannot be processed:

| Value | Behavior |
|---|---|
| `none` (default) | Any error causes the task to fail immediately. The connector enters `FAILED` state. Requires manual investigation and restart. |
| `all` | All errors are tolerated. Failed records are silently skipped (or written to DLQ if configured). Processing continues. |

```json
"errors.tolerance": "all"
```

**Recommendation for kafka-lab:** Use `errors.tolerance=all` with a DLQ configured so no records are silently lost and all failures are observable.

### Dead Letter Queue (DLQ)

The DLQ is only available for **sink connectors** when `errors.tolerance=all`. Failed records are produced to a designated Kafka topic instead of being dropped.

#### Required Configuration

```json
"errors.tolerance": "all",
"errors.deadletterqueue.topic.name": "dlq-azure-blob-sink",
"errors.deadletterqueue.topic.replication.factor": "3",
"errors.deadletterqueue.context.headers.enable": "true"
```

- `errors.deadletterqueue.topic.name`: The Kafka topic to receive failed records. Connect auto-creates this topic if it does not exist.
- `errors.deadletterqueue.topic.replication.factor`: Replication factor for the DLQ topic. Use `3` for production, `1` for single-broker dev.
- `errors.deadletterqueue.context.headers.enable`: When `true`, each DLQ record includes headers with the original exception class, message, and stack trace. Header keys are prefixed with `_connect.errors`. Default: `false`.

#### Inspecting DLQ Records

```bash
# Read DLQ records and view error headers (requires kafkacat / kcat)
kcat -b broker:9092 -t dlq-azure-blob-sink -C -f '%h\n%s\n---\n'

# With kafka-console-consumer:
kafka-console-consumer --bootstrap-server broker:9092 \
  --topic dlq-azure-blob-sink \
  --from-beginning \
  --property print.headers=true
```

#### Error Logging

By default, `errors.tolerance=all` suppresses error logs. To restore verbose error logging:

```json
"errors.log.enable": "true",
"errors.log.include.messages": "true"
```

This logs error details to the Connect worker log at `WARN` level, including the original record value.

### Retry Settings

The Azure Blob Storage Sink Connector inherits retry behavior from the Azure SDK and the connector framework:

| Property | Default | Description |
|---|---|---|
| `azblob.retry.type` | `EXPONENTIAL` | Retry backoff strategy: `EXPONENTIAL` or `FIXED` |
| `azblob.retry.retries` | `3` | Maximum retry attempts for Azure SDK operations |
| `azblob.retry.backoff.ms` | `4000` | Initial retry delay in ms |
| `azblob.retry.max.backoff.ms` | `120000` | Maximum retry delay in ms |
| `retry.backoff.ms` | `5000` | Framework-level retry backoff — notifies Kafka Connect to retry delivering a message batch on transient exceptions |

For the kafka-lab private VNet environment, increase `azblob.connection.timeout.ms` beyond the default `30000` ms for large object uploads:

```json
"azblob.connection.timeout.ms": "120000"
```

---

## Example Configuration

### worker.properties — Dev (D2s_v5, Single Worker)

The D2s_v5 SKU provides 2 vCPUs and 8 GiB RAM. The following configuration is appropriate for a single Connect worker in a development environment. Adjust replication factors to match the number of Kafka brokers (set to `1` for single-broker dev, `3` for production).

```properties
# =============================================================
# Kafka Connect Distributed Worker — kafka-lab dev (D2s_v5)
# =============================================================

# Kafka cluster
bootstrap.servers=broker1.private.kafkalab.internal:9092,broker2.private.kafkalab.internal:9092,broker3.private.kafkalab.internal:9092
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="connect-worker" \
  password="${file:/etc/kafka/connect.secrets:sasl.password}";
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.jks
ssl.truststore.password=${file:/etc/kafka/connect.secrets:truststore.password}

# Worker identity
group.id=connect-cluster-dev

# Internal storage topics
config.storage.topic=connect-dev-configs
offset.storage.topic=connect-dev-offsets
status.storage.topic=connect-dev-status

# Dev: replication factor 1 (single broker); set to 3 for prod
config.storage.replication.factor=1
offset.storage.replication.factor=1
status.storage.replication.factor=1
offset.storage.partitions=3
status.storage.partitions=3

# Default converters (Avro with Schema Registry)
key.converter=io.confluent.connect.avro.AvroConverter
key.converter.schema.registry.url=http://schema-registry.private.kafkalab.internal:8081
value.converter=io.confluent.connect.avro.AvroConverter
value.converter.schema.registry.url=http://schema-registry.private.kafkalab.internal:8081

# Plugins
plugin.path=/usr/share/java,/usr/share/confluent-hub-components

# REST API — bind to private IP only
listeners=http://0.0.0.0:8083
rest.advertised.host.name=10.0.1.10
rest.advertised.port=8083

# Offset commit tuning
offset.flush.interval.ms=10000
offset.flush.timeout.ms=5000

# Graceful shutdown
task.shutdown.graceful.timeout.ms=10000
```

#### JVM Heap (set in environment before starting Connect)

```bash
export KAFKA_HEAP_OPTS="-Xms1g -Xmx4g"
export KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote \
  -Dcom.sun.management.jmxremote.port=9999 \
  -Dcom.sun.management.jmxremote.rmi.port=9999 \
  -Dcom.sun.management.jmxremote.authenticate=false \
  -Dcom.sun.management.jmxremote.ssl=false \
  -Djava.rmi.server.hostname=10.0.1.10"
```

#### Start the Worker

```bash
bin/connect-distributed etc/kafka/connect-distributed.properties
```

---

### Azure Blob Storage Sink Connector — Dev Configuration

This configuration archives data from a Kafka topic to an Azure Blob Storage container via private endpoint, with time-based partitioning for efficient downstream querying.

```json
{
  "name": "azure-blob-sink-archive",
  "config": {
    "connector.class": "io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector",
    "tasks.max": "2",

    "topics": "kafkalab-events",

    "azblob.account.name": "klcblobkafkalab",
    "azblob.account.key": "${file:/etc/kafka/connect.secrets:azblob.account.key}",
    "azblob.container.name": "kafka-archive",

    "format.class": "io.confluent.connect.azure.blob.format.avro.AvroFormat",
    "schema.compatibility": "NONE",

    "flush.size": "1000",
    "rotate.interval.ms": "600000",

    "partitioner.class": "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
    "path.format": "'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH",
    "partition.duration.ms": "3600000",
    "locale": "en-US",
    "timezone": "UTC",
    "timestamp.extractor": "Record",

    "topics.dir": "topics",
    "storage.class": "io.confluent.connect.azure.blob.storage.AzureBlobStorage",

    "azblob.block.size": "26214400",
    "azblob.retry.type": "EXPONENTIAL",
    "azblob.retry.retries": "5",
    "azblob.retry.backoff.ms": "4000",
    "azblob.retry.max.backoff.ms": "120000",
    "azblob.connection.timeout.ms": "120000",

    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry.private.kafkalab.internal:8081",

    "errors.tolerance": "all",
    "errors.deadletterqueue.topic.name": "dlq-azure-blob-sink-archive",
    "errors.deadletterqueue.topic.replication.factor": "1",
    "errors.deadletterqueue.context.headers.enable": "true",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true",

    "retry.backoff.ms": "5000",

    "behavior.on.null.values": "ignore"
  }
}
```

#### Deploy via REST API

```bash
curl -s -X POST http://10.0.1.10:8083/connectors \
  -H "Content-Type: application/json" \
  -d @azure-blob-sink-archive.json | jq
```

#### Verify

```bash
# Check status
curl -s http://10.0.1.10:8083/connectors/azure-blob-sink-archive/status | jq

# Watch task errors
curl -s http://10.0.1.10:8083/connectors/azure-blob-sink-archive/status | \
  jq '.tasks[] | select(.state != "RUNNING")'
```

#### Private DNS Verification

```bash
# Confirm storage account resolves to private endpoint IP (not public)
nslookup klcblobkafkalab.blob.core.windows.net
# Expected: CNAME → klcblobkafkalab.privatelink.blob.core.windows.net → 10.x.x.x (private IP)
```

---

## References

- Confluent Platform Kafka Connect Overview — https://docs.confluent.io/platform/current/connect/index.html
- Kafka Connect Concepts (Dead Letter Queue, Converters, Workers) — https://docs.confluent.io/platform/current/connect/concepts.html
- Kafka Connect User Guide (Distributed Mode, Plugin Install) — https://docs.confluent.io/platform/current/connect/userguide.html
- Kafka Connect Worker Configuration Properties — https://docs.confluent.io/platform/current/connect/references/allconfigs.html
- Kafka Connect REST API Reference — https://docs.confluent.io/platform/current/connect/references/restapi.html
- Kafka Connect Monitoring (JMX Metrics) — https://docs.confluent.io/platform/current/connect/monitoring.html
- Azure Blob Storage Sink Connector Overview — https://docs.confluent.io/kafka-connectors/azure-blob-storage-sink/current/overview.html
- Azure Blob Storage Sink Connector Configuration Reference — https://docs.confluent.io/kafka-connectors/azure-blob-storage-sink/current/configuration_options.html
- Confluent Hub: Azure Blob Storage Sink Connector — https://www.confluent.io/hub/confluentinc/kafka-connect-azure-blob-storage
- Azure Private Endpoint DNS for Blob Storage — https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#storage-subresources
- Azure Blob Storage Customer-Managed Keys — https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-overview
