---
id: TASK-27.4
title: 'Research: Confluent Kafka Connect'
status: To Do
assignee: []
created_date: '2026-03-30 13:36'
labels:
  - research
  - SP0P1
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/connect/index.html'
  - 'https://docs.confluent.io/platform/current/connect/concepts.html'
  - 'https://docs.confluent.io/platform/current/connect/monitoring.html'
documentation:
  - doc-SP0.004-confluent-kafka-connect
parent_task_id: TASK-27
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Confluent Kafka Connect architecture and deployment patterns. Identify which connectors are relevant for the kafka-lab project and how to deploy Connect workers alongside Kafka brokers on Azure VMs.

Focus areas:
- Connect worker architecture: distributed vs standalone mode
- Task and connector lifecycle management
- Relevant connectors for the lab (Azure Blob Storage Sink, file connectors, etc.)
- Configuration: worker properties, connector configs, secret management
- Monitoring via JMX and REST API
- Dead letter queue and error handling patterns
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document explains Kafka Connect architecture: workers, tasks, connectors, offset management
- [ ] #2 Document compares standalone vs distributed deployment modes with recommendations
- [ ] #3 Document identifies connectors relevant to the lab (Azure Blob Sink, File Source/Sink, etc.)
- [ ] #4 Document covers configuration management: worker properties, connector configs, secrets
- [ ] #5 Document covers monitoring: JMX metrics, REST API health checks, dead letter queues
- [ ] #6 All findings cite official Confluent documentation with URLs
- [ ] #7 Executive summary (≤300 words) leads the document
<!-- AC:END -->
