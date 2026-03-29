---
name: python
description: Develop Python applications for the Kafka lab project. Use when agents need to write Python code for Azure Functions, Kafka producers/consumers, REST APIs, data processing, or automation scripts. Covers the confluent-kafka library, azure-functions SDK, and Python best practices.
---

# Python

Python is the primary application language for this project. It powers Azure Functions (serverless endpoints), Kafka producers and consumers (via the `confluent-kafka` library), and automation scripts. The project targets Python 3.11+ with the v2 Azure Functions programming model.

## Key Libraries

| Library | Purpose | Install |
|---|---|---|
| `confluent-kafka` | Kafka producer/consumer with librdkafka backend | `pip install confluent-kafka` |
| `confluent-kafka[schemaregistry]` | Schema Registry integration (Avro/Protobuf/JSON) | `pip install confluent-kafka[schemaregistry]` |
| `azure-functions` | Azure Functions runtime types and decorators | `pip install azure-functions` |
| `azure-identity` | Azure authentication (DefaultAzureCredential) | `pip install azure-identity` |
| `pydantic` | Data validation and settings management | `pip install pydantic` |

## Kafka Producer

The `confluent-kafka` Python library wraps `librdkafka` for high-performance Kafka integration.

### Basic Producer

See [getting-started/producer.py](sample_codes/getting-started/producer.py) for a complete producer with delivery callbacks and error handling.

### Key Producer Configuration

| Setting | Purpose | Recommended |
|---|---|---|
| `bootstrap.servers` | Kafka broker addresses | All broker addresses |
| `acks` | Delivery acknowledgment level | `all` for reliability |
| `compression.type` | Message compression | `lz4` or `snappy` |
| `linger.ms` | Batching delay | `10` for throughput |
| `retries` | Retry count on failure | `3` or higher |
| `enable.idempotence` | Exactly-once per partition | `true` for critical data |

## Kafka Consumer

### Basic Consumer

See [getting-started/consumer.py](sample_codes/getting-started/consumer.py) for a consumer with manual offset commits and graceful shutdown.

### Key Consumer Configuration

| Setting | Purpose | Recommended |
|---|---|---|
| `bootstrap.servers` | Kafka broker addresses | All broker addresses |
| `group.id` | Consumer group ID | Descriptive name per service |
| `auto.offset.reset` | Start position for new groups | `earliest` or `latest` |
| `enable.auto.commit` | Automatic offset commits | `false` for reliability |

## Azure Functions (Python v2)

The v2 programming model uses decorators directly in `function_app.py`. See the `azure-function-apps` skill for infrastructure provisioning.

### Quick Example

See [common-patterns/function_kafka_producer.py](sample_codes/common-patterns/function_kafka_producer.py) for an Azure Function that produces messages to Kafka.

## Common Patterns

### Schema Registry Integration

See [common-patterns/avro_producer.py](sample_codes/common-patterns/avro_producer.py) for producing Avro-encoded messages with Schema Registry validation.

## Project Structure

```text
src/
├── function_app.py           # Azure Functions entry point
├── requirements.txt          # Dependencies
├── host.json                 # Functions host configuration
├── kafka/
│   ├── __init__.py
│   ├── producer.py           # Reusable Kafka producer
│   ├── consumer.py           # Reusable Kafka consumer
│   └── config.py             # Configuration from environment
└── tests/
    ├── test_producer.py
    └── test_consumer.py
```

## Best Practices

- **Do**: Use `confluent-kafka` over `kafka-python` for production (librdkafka backend)
- **Do**: Set `enable.auto.commit=false` and commit offsets manually after processing
- **Do**: Always call `producer.flush()` on shutdown
- **Do**: Use delivery callbacks to track message delivery status
- **Do**: Use `pydantic` for configuration validation
- **Do**: Use `azure-identity.DefaultAzureCredential` for Azure service authentication
- **Avoid**: Blocking the event loop in async Functions
- **Avoid**: Hardcoding broker addresses or credentials; use environment variables

## Troubleshooting

| Issue | Solution |
|---|---|
| `confluent-kafka` install fails | Install `librdkafka-dev` system package first |
| `KafkaException: No brokers available` | Check `bootstrap.servers` config, verify network connectivity |
| Consumer lag increasing | Scale consumers (max = partition count), check processing time |
| Schema Registry 409 conflict | Schema evolution compatibility check failed; review schema changes |

## Learn More

| Topic | How to Find |
|---|---|
| confluent-kafka API | See [confluent-kafka docs](https://docs.confluent.io/kafka-clients/python/current/overview.html) |
| Azure Functions Python | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/azure-functions/functions-reference-python")` |
| Schema Registry | See [Schema Registry docs](https://docs.confluent.io/platform/current/schema-registry/index.html) |
| Python best practices | `microsoft_docs_search(query="python azure functions best practices")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
