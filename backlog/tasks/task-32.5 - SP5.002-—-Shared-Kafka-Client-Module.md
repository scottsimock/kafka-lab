---
id: TASK-32.5
title: SP5.002 — Shared Kafka Client Module
status: Dev Complete
assignee:
  - Dallas
created_date: '2026-03-30 16:46'
updated_date: '2026-03-31 19:12'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.4
references:
  - webapp/lib/kafka.ts
documentation:
  - doc-16
parent_task_id: TASK-32
priority: high
ordinal: 5002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a shared Kafka client module at webapp/lib/kafka.ts using @confluentinc/kafka-javascript. Implement singleton pattern for Kafka client reuse across requests. Configure SASL_SSL connection with credentials from environment variables (KAFKA_BROKERS, KAFKA_USERNAME, KAFKA_PASSWORD, KAFKA_SSL_CA). Export helper functions for admin, producer, consumer. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Shared Kafka client module at webapp/lib/kafka.ts
- [ ] #2 Singleton pattern: one Kafka instance per Function App warm instance
- [ ] #3 Configures SASL_SSL with credentials from environment variables
- [ ] #4 Exports getAdmin(), getProducer(), getConsumer() helper functions
- [ ] #5 Graceful disconnect on process shutdown (SIGTERM handler)
- [ ] #6 TypeScript types defined for Kafka configuration
<!-- AC:END -->
