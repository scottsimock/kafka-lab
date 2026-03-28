---
id: TASK-1.10
title: 'Research: Python FastAPI Producer and Consumer App Design'
status: Done
assignee: []
created_date: '2026-03-27 20:44'
updated_date: '2026-03-28 18:25'
labels:
  - research
  - python
  - fastapi
  - confluent-client
  - application
dependencies: []
references:
  - 'https://docs.confluent.io/kafka-clients/python/current/overview.html'
parent_task_id: TASK-1
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research the Python/FastAPI application design for the producer and consumer apps, focusing on Confluent Kafka client integration and resilience-aware configuration.

## Goals
- Research the `confluent-kafka` Python library (librdkafka-based) for producer and consumer apps
- Understand Kafka producer configuration for resilience (acks, retries, idempotence, delivery guarantees)
- Understand Kafka consumer configuration for resilience (group rebalance, offset commit strategy, session timeout)
- Research FastAPI async patterns for Kafka producers and consumers (background tasks, lifespan events)
- Research Schema Registry client for Python (Avro serialization/deserialization)
- Design a minimal UI (or REST API endpoint) to visualize message flow and failures in real time

## Key Questions
- Should the consumer use auto-commit or manual offset commit for the lab?
- How should the FastAPI app handle producer/consumer reconnection on broker failure?
- What metrics should the app expose to make chaos experiment outcomes observable?

## Additional References
- https://docs.confluent.io/kafka-clients/python/current/overview.html
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Confluent Python client (confluent-kafka) producer and consumer API documented
- [x] #2 FastAPI integration pattern with async Kafka producer/consumer documented
- [x] #3 Schema Registry client integration for Avro serialization documented
- [x] #4 Consumer group failover behavior during broker unavailability described
- [x] #5 Observability instrumentation for the app (metrics endpoint, health check) outlined
- [x] #6 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **FastAPI Producer Consumer App Research**

The doc must cover:

- confluent-kafka Python library (librdkafka) producer and consumer API
- Producer config for resilience: acks, retries, idempotence, delivery guarantees
- Consumer config for resilience: group rebalance, offset commit, session timeout
- FastAPI async patterns with Kafka (background tasks, lifespan events)
- Schema Registry client integration for Avro serialization
- Observability instrumentation (metrics endpoint, health check)
- Reconnection handling during broker failures

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## TASK-1.10 Completion Summary

**Research document created**: `doc-8 — FastAPI Producer Consumer App Research`

### What was researched
- **confluent-kafka Python client** (librdkafka-based) — producer and consumer APIs, deprecation of AvroProducer/AvroConsumer in favor of AvroSerializer/AvroDeserializer
- **Producer resilience config** — acks=all, enable.idempotence=True, retries, delivery callbacks
- **Consumer resilience config** — manual offset commit, session timeout, heartbeat, static group membership, rebalance callbacks
- **FastAPI integration** — lifespan context manager pattern, run_in_executor for blocking calls, asyncio.Task for consumer loop
- **Schema Registry** — SchemaRegistryClient + AvroSerializer/AvroDeserializer with Confluent wire format
- **Real-time visualization** — SSE via sse-starlette with EventSourceResponse, minimal HTML/JS dashboard
- **Observability** — prometheus_client metrics endpoint, stats_cb for librdkafka internals, consumer lag tracking
- **Reconnection handling** — librdkafka auto-reconnects; error_cb for logging; KafkaError.fatal() for unrecoverable errors

### Key decisions documented
1. Use confluent-kafka (not aiokafka) for production-grade throughput and native Schema Registry support
2. Manual offset commit for observable resilience behavior during chaos experiments
3. FastAPI lifespan context manager for clean lifecycle management
4. SSE over WebSocket for unidirectional message visualization
5. Prometheus metrics with stats_cb for comprehensive chaos experiment observability
6. Idempotent producer with acks=all for strongest delivery guarantees

### Deliverables
- Full Python code examples for producer app, consumer app, SSE stream, and minimal dashboard
- Complete configuration parameter tables for producer and consumer
- requirements.txt with all dependencies
- 6 open questions documented for future sprint planning
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
