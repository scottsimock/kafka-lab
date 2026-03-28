---
id: doc-8
title: FastAPI Producer Consumer App Research
type: other
created_date: '2026-03-28 18:25'
---
# FastAPI Producer Consumer App Research

## Summary

This document captures research findings for the Kafka Lab's two Python/FastAPI web applications — a **producer app** that publishes Avro-serialized messages to Kafka topics via Schema Registry, and a **consumer app** that reads and deserializes those messages for real-time visualization. Both apps use the `confluent-kafka` Python client (librdkafka-based) and must be resilience-aware: handling broker failures gracefully, exposing observability metrics, and supporting chaos experiment validation across the multi-region Confluent Platform 7.x deployment.

The key architectural choices are: use `confluent-kafka` (not `aiokafka`) for production-grade throughput and native Schema Registry support; use FastAPI lifespan context managers for lifecycle management; use manual offset commits for the consumer; expose Prometheus metrics and SSE streams for real-time observability.

## Key Findings

### confluent-kafka Python Library

- The `confluent-kafka` package wraps librdkafka (C library), providing high throughput and low latency — significantly outperforming pure-Python alternatives
- Current recommended version: `confluent-kafka >= 2.3.0` (includes `AvroSerializer`/`AvroDeserializer` classes)
- The library is **not natively async** — blocking calls (`produce`, `poll`, `flush`) must be offloaded to a thread pool (`run_in_executor`) or handled via FastAPI `BackgroundTasks` to avoid blocking the event loop
- Deprecated: `AvroProducer` and `AvroConsumer` classes — replaced by plain `Producer`/`Consumer` with explicit `AvroSerializer`/`AvroDeserializer`
- Dependency: `fastavro` is required for Avro serde operations

### Producer Resilience Configuration

- **`acks='all'` (or `-1`)**: Waits for all in-sync replicas to acknowledge; strongest durability guarantee
- **`enable.idempotence=True`**: Assigns unique producer ID + sequence numbers to deduplicate on the broker; implicitly sets `acks='all'` and `retries > 0`
- **`retries=5`** with **`retry.backoff.ms=200`**: Retries transient failures with backoff
- **`max.in.flight.requests.per.connection=5`**: Maximum parallel requests; safe for idempotent producers (librdkafka handles ordering)
- **`message.timeout.ms=30000`**: Total time allowed for retries before the message is marked failed
- **Delivery callback**: Essential — invoked per message with success/error status; critical for tracking delivery failures during chaos experiments

### Consumer Resilience Configuration

- **`enable.auto.commit=False`**: Manual offset commit after successful processing prevents message loss and double-processing during rebalances
- **`auto.offset.reset='earliest'`**: Start from the beginning if no committed offset exists — safe default for the lab
- **`session.timeout.ms=10000`**: Broker considers consumer dead after 10s without heartbeat
- **`heartbeat.interval.ms=3000`**: Must be less than 1/3 of `session.timeout.ms`
- **`max.poll.interval.ms=300000`**: Maximum time between `poll()` calls before the consumer is evicted — set high enough for processing
- **Static group membership** (`group.instance.id`): Reduces unnecessary rebalances during short outages or rolling restarts (Kafka 2.3+)
- **Rebalance callbacks** (`on_assign`, `on_revoke`): Use to save/restore offsets and clean up resources during partition reassignment

### Reconnection and Broker Failure Handling

- **librdkafka handles reconnection automatically**: Transient network errors and broker restarts are retried transparently without application intervention
- **`error_cb` callback**: Invoked on global errors (e.g., all brokers down); use for logging, alerting, and incrementing error metrics
- **Fatal vs. non-fatal errors**: Check `KafkaError.fatal()` — fatal errors require client restart; non-fatal errors (transport failures, `PARTITION_EOF`) are recovered automatically
- **No manual reconnection code needed**: The application should log errors, track metrics, and let librdkafka handle recovery

### FastAPI Integration Patterns

- **Lifespan context manager** (FastAPI >= 0.88): Preferred over deprecated `on_event("startup")`/`on_event("shutdown")` decorators — centralizes resource initialization and teardown
- **Producer**: Initialize in lifespan `startup`; call `producer.flush()` in `shutdown`; offload `produce()` calls via `asyncio.get_event_loop().run_in_executor(None, ...)`
- **Consumer**: Run consumer poll loop as a background `asyncio.Task` created during lifespan startup; cancel the task and call `consumer.close()` during shutdown
- **Thread safety**: `confluent-kafka` Producer is thread-safe; Consumer is **not** — confine consumer operations to a single task/thread

### Schema Registry Integration

- **`SchemaRegistryClient`**: Connects to Confluent Schema Registry for schema management
- **`AvroSerializer`**: Converts Python dicts to Avro binary with automatic schema registration (`auto.register.schemas=True` by default)
- **`AvroDeserializer`**: Converts Avro binary back to Python dicts; supports custom `from_dict` mapping to domain objects
- **Confluent wire format**: 5-byte header (1 magic byte + 4-byte schema ID) prepended to Avro payload
- **Schema evolution**: Forward/backward compatibility enforced by the registry; configure subject-level compatibility as needed

### Real-Time Visualization

- **Server-Sent Events (SSE)** recommended over WebSocket for this use case — unidirectional server-to-client push is sufficient for message flow visualization
- **`sse-starlette` library**: Integrates SSE with FastAPI; supports `EventSourceResponse` for streaming generators
- **Browser `EventSource` API**: Built-in automatic reconnection; simple JavaScript integration
- **Frontend**: Minimal HTML/JS dashboard using `EventSource` to receive messages and update a live feed/chart

### Observability and Metrics

- **`prometheus_client` library**: Expose `/metrics` endpoint for Prometheus scraping
- **Key application metrics to expose**:
  - `kafka_messages_produced_total` (Counter) — total messages sent
  - `kafka_messages_consumed_total` (Counter) — total messages received
  - `kafka_produce_errors_total` (Counter) — delivery failures
  - `kafka_consume_errors_total` (Counter) — consumer errors
  - `kafka_produce_latency_seconds` (Histogram) — produce-to-ack latency
  - `kafka_consumer_lag` (Gauge) — per-partition lag (highwater - committed offset)
  - `kafka_broker_disconnections_total` (Counter) — tracks broker failure events via `error_cb`
- **`stats_cb` callback**: librdkafka emits internal statistics as JSON every `statistics.interval.ms` — parse and export as Prometheus metrics
- **Health check endpoint** (`/health`): Returns 200 when the app is running and connected to at least one broker; returns 503 otherwise

## Architecture / Design Decisions

### Decision 1: Use `confluent-kafka` over `aiokafka`

**Rationale**: `confluent-kafka` wraps librdkafka (C), delivering higher throughput and lower latency than `aiokafka` (pure Python). It provides native Schema Registry integration (`AvroSerializer`/`AvroDeserializer`) and production-grade reliability. The async gap is bridged by offloading blocking calls to a thread pool via `run_in_executor`.

### Decision 2: Manual offset commit for the consumer

**Rationale**: For a chaos/resilience lab, manual commit (`enable.auto.commit=False`) ensures offsets are only committed after successful processing. This prevents data loss during rebalances and makes the effects of broker failures clearly observable — uncommitted messages will be reprocessed after recovery, which is the desired behavior for demonstrating at-least-once delivery semantics.

### Decision 3: FastAPI lifespan context manager for lifecycle

**Rationale**: The lifespan pattern centralizes producer/consumer initialization and teardown in a single `async with` block, preventing resource leaks. It supersedes the deprecated `on_event` decorators and cleanly integrates with shared application state.

### Decision 4: SSE for real-time message visualization

**Rationale**: The consumer app only needs server-to-client push (displaying consumed messages). SSE is simpler than WebSocket, has built-in browser reconnection, and works through standard HTTP proxies. The `sse-starlette` library provides clean FastAPI integration.

### Decision 5: Prometheus metrics with `stats_cb`

**Rationale**: Combining application-level counters/histograms (via `prometheus_client`) with librdkafka's internal statistics (via `stats_cb`) provides comprehensive observability. This makes chaos experiment outcomes measurable: producer delivery failures, consumer lag spikes, and broker disconnection events all become quantifiable.

### Decision 6: Idempotent producer with `acks=all`

**Rationale**: For a resilience lab, the producer should use the strongest delivery guarantees available. `enable.idempotence=True` + `acks='all'` ensures exactly-once delivery to the broker (no duplicates from retries) with full ISR acknowledgment. This makes it straightforward to validate that messages are not lost during chaos experiments.

## Configuration Reference

### Producer App — Full FastAPI Integration

```python
import asyncio
import json
import logging
from contextlib import asynccontextmanager

from confluent_kafka import Producer, KafkaError
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext, MessageField
from fastapi import FastAPI, HTTPException
from prometheus_client import Counter, Histogram, generate_latest
from fastapi.responses import Response
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# --- Prometheus Metrics ---
PRODUCE_TOTAL = Counter("kafka_messages_produced_total", "Total messages produced")
PRODUCE_ERRORS = Counter("kafka_produce_errors_total", "Total produce delivery failures")
PRODUCE_LATENCY = Histogram("kafka_produce_latency_seconds", "Produce-to-ack latency")
BROKER_ERRORS = Counter("kafka_broker_disconnections_total", "Broker disconnection events")


# --- Callbacks ---
def error_cb(err):
    """Global error callback — invoked on broker-level errors."""
    logger.error("Kafka error: %s", err)
    BROKER_ERRORS.inc()


def delivery_cb(err, msg):
    """Per-message delivery callback."""
    if err:
        logger.error("Delivery failed for %s: %s", msg.topic(), err)
        PRODUCE_ERRORS.inc()
    else:
        PRODUCE_TOTAL.inc()


# --- Avro Schema ---
SCHEMA_STR = json.dumps({
    "type": "record",
    "name": "LabMessage",
    "namespace": "com.kafkalab",
    "fields": [
        {"name": "id", "type": "string"},
        {"name": "timestamp", "type": "long"},
        {"name": "source_region", "type": "string"},
        {"name": "payload", "type": "string"},
    ],
})


# --- Lifespan ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    schema_registry_client = SchemaRegistryClient({"url": "http://schema-registry:8081"})
    avro_serializer = AvroSerializer(schema_registry_client, SCHEMA_STR)

    producer_conf = {
        "bootstrap.servers": "broker-1:9092,broker-2:9092,broker-3:9092",
        "client.id": "kafkalab-producer",
        "acks": "all",
        "enable.idempotence": True,
        "retries": 5,
        "retry.backoff.ms": 200,
        "max.in.flight.requests.per.connection": 5,
        "message.timeout.ms": 30000,
        "statistics.interval.ms": 5000,
        "error_cb": error_cb,
    }
    producer = Producer(producer_conf)

    app.state.producer = producer
    app.state.avro_serializer = avro_serializer
    logger.info("Producer initialized")

    yield

    # Shutdown
    producer.flush(timeout=10)
    logger.info("Producer flushed and shut down")


app = FastAPI(title="Kafka Lab Producer", lifespan=lifespan)


# --- Models ---
class ProduceRequest(BaseModel):
    id: str
    timestamp: int
    source_region: str
    payload: str


# --- Endpoints ---
@app.post("/produce/{topic}")
async def produce_message(topic: str, message: ProduceRequest):
    """Produce an Avro-serialized message to the given topic."""
    loop = asyncio.get_event_loop()
    serializer = app.state.avro_serializer
    producer = app.state.producer

    value = message.model_dump()
    serialized = serializer(value, SerializationContext(topic, MessageField.VALUE))

    try:
        await loop.run_in_executor(None, lambda: producer.produce(
            topic=topic,
            value=serialized,
            callback=delivery_cb,
        ))
        # Trigger delivery report callbacks
        producer.poll(0)
    except BufferError:
        raise HTTPException(status_code=503, detail="Producer queue full")
    return {"status": "queued", "topic": topic, "id": message.id}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type="text/plain")
```

### Consumer App — Full FastAPI Integration with SSE

```python
import asyncio
import json
import logging
from collections import deque
from contextlib import asynccontextmanager

from confluent_kafka import Consumer, KafkaError
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import SerializationContext, MessageField
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, Response
from prometheus_client import Counter, Gauge, generate_latest
from sse_starlette.sse import EventSourceResponse

logger = logging.getLogger(__name__)

# --- Prometheus Metrics ---
CONSUME_TOTAL = Counter("kafka_messages_consumed_total", "Total messages consumed")
CONSUME_ERRORS = Counter("kafka_consume_errors_total", "Total consumer errors")
CONSUMER_LAG = Gauge("kafka_consumer_lag", "Consumer lag per partition",
                     ["topic", "partition"])
BROKER_ERRORS = Counter("kafka_broker_disconnections_total", "Broker disconnection events")

# --- In-memory message buffer for SSE clients ---
MAX_BUFFER = 200
message_buffer: deque = deque(maxlen=MAX_BUFFER)


# --- Callbacks ---
def error_cb(err):
    logger.error("Kafka error: %s", err)
    BROKER_ERRORS.inc()


def on_assign(consumer, partitions):
    logger.info("Partitions assigned: %s", partitions)


def on_revoke(consumer, partitions):
    logger.info("Partitions revoked: %s", partitions)
    try:
        consumer.commit(asynchronous=False)
    except Exception:
        logger.exception("Failed to commit offsets on revoke")


# --- Consumer Poll Loop ---
async def consumer_loop(consumer, deserializer, topic, shutdown_event):
    """Background task that polls Kafka and populates the message buffer."""
    loop = asyncio.get_event_loop()

    while not shutdown_event.is_set():
        msg = await loop.run_in_executor(None, lambda: consumer.poll(1.0))

        if msg is None:
            continue

        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                continue
            logger.error("Consumer error: %s", msg.error())
            CONSUME_ERRORS.inc()
            continue

        try:
            value = deserializer(
                msg.value(),
                SerializationContext(msg.topic(), MessageField.VALUE),
            )
        except Exception:
            logger.exception("Deserialization failed")
            CONSUME_ERRORS.inc()
            continue

        CONSUME_TOTAL.inc()

        # Track consumer lag per partition
        topic_partition = msg.topic()
        partition = msg.partition()
        high_water = consumer.get_watermark_offsets(
            msg.topic_partition(), cached=True
        )[1]
        lag = max(0, high_water - msg.offset() - 1)
        CONSUMER_LAG.labels(topic=topic_partition, partition=str(partition)).set(lag)

        event_data = {
            "topic": msg.topic(),
            "partition": msg.partition(),
            "offset": msg.offset(),
            "value": value,
        }
        message_buffer.append(event_data)

        # Commit offset after successful processing
        consumer.commit(message=msg, asynchronous=False)

    consumer.close()
    logger.info("Consumer closed")


# --- Avro Schema (must match producer) ---
SCHEMA_STR = json.dumps({
    "type": "record",
    "name": "LabMessage",
    "namespace": "com.kafkalab",
    "fields": [
        {"name": "id", "type": "string"},
        {"name": "timestamp", "type": "long"},
        {"name": "source_region", "type": "string"},
        {"name": "payload", "type": "string"},
    ],
})

TOPIC = "lab-messages"


# --- Lifespan ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    schema_registry_client = SchemaRegistryClient({"url": "http://schema-registry:8081"})
    avro_deserializer = AvroDeserializer(schema_registry_client, SCHEMA_STR)

    consumer_conf = {
        "bootstrap.servers": "broker-1:9092,broker-2:9092,broker-3:9092",
        "group.id": "kafkalab-consumer",
        "client.id": "kafkalab-consumer-1",
        "group.instance.id": "consumer-instance-1",  # static membership
        "auto.offset.reset": "earliest",
        "enable.auto.commit": False,
        "session.timeout.ms": 10000,
        "heartbeat.interval.ms": 3000,
        "max.poll.interval.ms": 300000,
        "statistics.interval.ms": 5000,
        "error_cb": error_cb,
    }
    consumer = Consumer(consumer_conf)
    consumer.subscribe([TOPIC], on_assign=on_assign, on_revoke=on_revoke)

    shutdown_event = asyncio.Event()
    task = asyncio.create_task(
        consumer_loop(consumer, avro_deserializer, TOPIC, shutdown_event)
    )

    app.state.consumer_task = task
    app.state.shutdown_event = shutdown_event
    logger.info("Consumer started for topic: %s", TOPIC)

    yield

    shutdown_event.set()
    await task
    logger.info("Consumer shut down")


app = FastAPI(title="Kafka Lab Consumer", lifespan=lifespan)


# --- SSE Stream Endpoint ---
@app.get("/stream")
async def stream_messages(request: Request):
    """Server-Sent Events stream of consumed Kafka messages."""
    last_index = len(message_buffer)

    async def event_generator():
        nonlocal last_index
        while True:
            if await request.is_disconnected():
                break
            current_len = len(message_buffer)
            if current_len > last_index:
                for i in range(last_index, current_len):
                    yield {"event": "message", "data": json.dumps(message_buffer[i])}
                last_index = current_len
            await asyncio.sleep(0.25)

    return EventSourceResponse(event_generator())


# --- REST Endpoints ---
@app.get("/messages")
async def get_messages(limit: int = 50):
    """Return the most recent consumed messages."""
    recent = list(message_buffer)[-limit:]
    return {"count": len(recent), "messages": recent}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type="text/plain")


# --- Minimal Dashboard ---
DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head><title>Kafka Lab — Message Stream</title>
<style>
  body { font-family: monospace; background: #1a1a2e; color: #e0e0e0; padding: 20px; }
  h1 { color: #00d4ff; }
  #messages { max-height: 80vh; overflow-y: auto; }
  .msg { padding: 4px 8px; margin: 2px 0; background: #16213e; border-left: 3px solid #00d4ff; }
  .error { border-left-color: #ff4444; }
  .meta { color: #888; font-size: 0.85em; }
</style>
</head>
<body>
<h1>Kafka Lab — Live Message Stream</h1>
<div>Connected: <span id="status">⏳</span> | Messages: <span id="count">0</span></div>
<div id="messages"></div>
<script>
let count = 0;
const es = new EventSource("/stream");
const container = document.getElementById("messages");
const statusEl = document.getElementById("status");
const countEl = document.getElementById("count");

es.onopen = () => { statusEl.textContent = "✅"; };
es.onerror = () => { statusEl.textContent = "❌ reconnecting..."; };
es.onmessage = (e) => {
  count++;
  countEl.textContent = count;
  const data = JSON.parse(e.data);
  const div = document.createElement("div");
  div.className = "msg";
  div.innerHTML = '<span class="meta">[' + data.topic + ':' + data.partition +
    '@' + data.offset + ']</span> ' + JSON.stringify(data.value);
  container.prepend(div);
  if (container.children.length > 200) container.lastChild.remove();
};
</script>
</body>
</html>
"""


@app.get("/", response_class=HTMLResponse)
async def dashboard():
    return DASHBOARD_HTML
```

### Python Dependencies (`requirements.txt`)

```
confluent-kafka>=2.3.0
fastavro>=1.9.0
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
sse-starlette>=1.8.0
prometheus-client>=0.20.0
pydantic>=2.0
```

### Key Producer Configuration Parameters

| Parameter | Value | Purpose |
|---|---|---|
| `acks` | `all` | Wait for all ISR acknowledgment |
| `enable.idempotence` | `True` | Exactly-once broker delivery (dedup) |
| `retries` | `5` | Retry transient failures |
| `retry.backoff.ms` | `200` | Delay between retries |
| `max.in.flight.requests.per.connection` | `5` | Max parallel requests (safe with idempotence) |
| `message.timeout.ms` | `30000` | Total time before message marked failed |
| `statistics.interval.ms` | `5000` | Emit internal stats for Prometheus |

### Key Consumer Configuration Parameters

| Parameter | Value | Purpose |
|---|---|---|
| `enable.auto.commit` | `False` | Manual commit after processing |
| `auto.offset.reset` | `earliest` | Start from beginning if no offset |
| `session.timeout.ms` | `10000` | Broker eviction timeout |
| `heartbeat.interval.ms` | `3000` | Heartbeat frequency (< 1/3 session timeout) |
| `max.poll.interval.ms` | `300000` | Max time between polls |
| `group.instance.id` | (set per instance) | Static membership — fewer rebalances |
| `statistics.interval.ms` | `5000` | Emit internal stats for Prometheus |

## Risks and Open Questions

### Resolved Questions

**Should the consumer use auto-commit or manual offset commit?**
→ **Manual commit**. For a resilience lab, manual commit after successful processing ensures that the effects of broker failures are visible (uncommitted messages are reprocessed). Auto-commit risks silently advancing offsets for unprocessed messages during rebalances.

**How should FastAPI handle producer/consumer reconnection on broker failure?**
→ **librdkafka handles reconnection automatically**. The application registers `error_cb` for logging/metrics and checks `KafkaError.fatal()` for unrecoverable errors (which would require a full client restart). No manual reconnection logic is needed for transient failures.

**What metrics should the app expose for chaos experiments?**
→ See the observability metrics list above. The critical chaos-observable metrics are: `kafka_produce_errors_total`, `kafka_consumer_lag`, `kafka_broker_disconnections_total`, and `kafka_produce_latency_seconds`. These directly measure the impact of broker kills, network partitions, and rolling restarts.

### Open Questions

1. **Exactly-once semantics (EOS) with transactions**: The current design uses idempotent producer (exactly-once to broker) but not Kafka transactions. Full EOS (produce + consume + commit in a transaction) adds complexity. Is this needed for the lab, or is at-least-once sufficient on the consumer side?

2. **Multiple consumer instances**: The current design runs one consumer per FastAPI app instance. For multi-partition topics, should multiple consumer instances be deployed (e.g., via container replicas), or should one app consume from all partitions?

3. **Schema evolution strategy**: The lab starts with a fixed `LabMessage` schema. If schema evolution is tested later, the compatibility mode (BACKWARD, FORWARD, FULL) on the Schema Registry subjects must be decided.

4. **Dead letter queue (DLQ)**: Messages that fail deserialization are logged and skipped. Should a DLQ topic be configured to capture poison-pill messages for inspection?

5. **TLS/SASL authentication**: The code examples use plaintext connections. Production deployment in the Azure environment will require SASL_SSL configuration for broker and Schema Registry connections — specific credentials and CA certs are TBD.

6. **Consumer app scaling**: With SSE, each browser client maintains a long-lived HTTP connection. If many clients connect, this could exhaust connections. Consider whether a single dashboard instance is sufficient or if a pub/sub broadcast layer (e.g., Redis) is needed.

## References

- [Confluent Kafka Python Client Documentation](https://docs.confluent.io/platform/current/clients/confluent-kafka-python/html/index.html)
- [Confluent Kafka Python Client Overview](https://docs.confluent.io/kafka-clients/python/current/overview.html)
- [Confluent Producer Configuration Reference](https://docs.confluent.io/platform/current/installation/configuration/producer-configs.html)
- [Confluent Consumer Configuration Reference](https://docs.confluent.io/platform/current/installation/configuration/consumer-configs.html)
- [Confluent Kafka Producer Guide](https://docs.confluent.io/platform/current/clients/producer.html)
- [Confluent Kafka Consumer Guide](https://docs.confluent.io/platform/current/clients/consumer.html)
- [confluent-kafka-python GitHub — Avro Consumer Example](https://github.com/confluentinc/confluent-kafka-python/blob/master/examples/avro_consumer.py)
- [librdkafka Wiki — Error Handling](https://github.com/confluentinc/librdkafka/wiki/Error-handling)
- [prometheus_kafka_metrics — Prometheus Metrics for confluent-kafka-python](https://github.com/shakti-garg/prometheus_kafka_metrics)
- [FastAPI Server-Sent Events Documentation](https://fastapi.tiangolo.com/tutorial/server-sent-events/)
- [sse-starlette PyPI](https://pypi.org/project/sse-starlette/)
- [AvroSerializer Deprecation Migration Guide](https://www.markhneedham.com/blog/2023/07/25/confluent-kafka-avroproducer-deprecated-use-avroserializer/)
