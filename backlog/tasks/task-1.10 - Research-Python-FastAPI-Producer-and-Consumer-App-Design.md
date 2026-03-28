---
id: TASK-1.10
title: 'Research: Python FastAPI Producer and Consumer App Design'
status: To Do
assignee: []
created_date: '2026-03-27 20:44'
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
- [ ] #1 Confluent Python client (confluent-kafka) producer and consumer API documented
- [ ] #2 FastAPI integration pattern with async Kafka producer/consumer documented
- [ ] #3 Schema Registry client integration for Avro serialization documented
- [ ] #4 Consumer group failover behavior during broker unavailability described
- [ ] #5 Observability instrumentation for the app (metrics endpoint, health check) outlined
<!-- AC:END -->
