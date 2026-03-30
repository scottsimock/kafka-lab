---
id: TASK-27.1
title: SP0.003 — Confluent Kafka Connect
status: Done
assignee:
  - tester-2
created_date: '2026-03-30 15:20'
updated_date: '2026-03-30 15:44'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/connect/index.html'
parent_task_id: TASK-27
priority: medium
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Kafka Connect 7.8.x deployment in distributed mode, connector types, lifecycle management, and specifically the Azure Blob Storage sink connector for tiered storage integration. Kafka Connect is the bridge between Kafka and external systems in the kafka-lab project.\n\n**Sources:**\n- https://docs.confluent.io/platform/current/connect/index.html\n- https://docs.confluent.io/kafka-connectors/azure-blob-storage-sink/current/overview.html\n- https://docs.confluent.io/platform/current/connect/references/restapi.html\n- Confluent Connect configuration reference\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of Kafka Connect architecture and role\n- Distributed mode configuration (worker properties, group.id, offset/config/status topics)\n- Connector lifecycle management (REST API, deploy/pause/resume/restart)\n- Azure Blob Storage sink connector configuration (connection string, container, format, partitioning)\n- Monitoring Connect workers (JMX metrics, health checks)\n- Error handling and dead letter queues\n- Example configuration for dev environment (1 Connect worker on D2s_v5)\n- References with URLs\n\n**Scope:**\n- Include: Distributed mode, connector lifecycle, Azure Blob sink, monitoring, error handling\n- Exclude: Schema Registry integration details (SP0.002), custom connector development, source connectors
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document covers distributed mode configuration (worker properties, internal topics)
- [ ] #2 Document covers connector lifecycle management via REST API
- [ ] #3 Document covers Azure Blob Storage sink connector configuration with private endpoint and CMEK
- [ ] #4 Document covers monitoring Kafka Connect workers (JMX metrics, health checks)
- [ ] #5 Document includes example configuration for dev environment (D2s_v5)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T15:40:00Z
- Completed research for SP0.003 — Confluent Kafka Connect
- Created backlog document: doc-7
- Sources consulted:
  - https://docs.confluent.io/platform/current/connect/index.html
  - https://docs.confluent.io/platform/current/connect/concepts.html
  - https://docs.confluent.io/platform/current/connect/userguide.html
  - https://docs.confluent.io/platform/current/connect/references/allconfigs.html
  - https://docs.confluent.io/platform/current/connect/references/restapi.html
  - https://docs.confluent.io/platform/current/connect/monitoring.html
  - https://docs.confluent.io/kafka-connectors/azure-blob-storage-sink/current/overview.html
  - https://docs.confluent.io/kafka-connectors/azure-blob-storage-sink/current/configuration_options.html
- Score self-assessment: Addressed all 5 AC items
  - AC1: Distributed mode worker.properties documented (group.id, bootstrap.servers, config/offset/status topics, key/value converters, replication factors, topic cleanup policy)
  - AC2: Connector lifecycle REST API documented with curl examples for deploy, list, status, pause, resume, restart, stop, delete, and task-level restart
  - AC3: Azure Blob Storage sink connector documented with private endpoint DNS resolution, CMEK (storage account level), and UAMI authentication guidance
  - AC4: JMX MBeans documented for connector, task (common, sink, source, error), worker, and rebalance metrics with alert thresholds
  - AC5: Complete dev example config for D2s_v5 (worker.properties + connector JSON) included with JVM heap settings

## [Tester] 2026-03-30T16:00:00Z
- PASS — Score: 95.8%
- Accuracy: 93/100 (30%) — All core facts are correct for CP 7.8.x: REST API endpoints, HTTP methods, response codes, JMX MBean names, Azure Blob connector class, distributed mode properties, DLQ config. Minor uncertainty: `azblob.use.managed.identity` noted as unverified against specific connector version — document handles this honestly with a recommended SAS token workaround. Small deduction only.
- Completeness: 97/100 (25%) — All 5 AC items fully addressed. Scope from task description (distributed mode, lifecycle, Azure Blob sink, monitoring, error handling, dev example) completely covered. Bonus: exactly-once delivery semantics, schema evolution, retry settings, object naming patterns.
- Sources: 98/100 (20%) — 10 references all with explicit URLs. All primary/official sources: Confluent docs (connect index, concepts, userguide, allconfigs, REST API, monitoring, Azure Blob sink overview + config reference, Confluent Hub) and Microsoft docs (Private Endpoint DNS). Specific page URLs, not homepages.
- Documentation Quality: 97/100 (15%) — Executive summary present and well-structured. Clear heading hierarchy. Extensive use of tables (properties, format classes, partitioners, metrics, alert thresholds). Annotated code examples throughout (bash curl, JSON, properties, shell commands). Private DNS verification step adds operational completeness.
- Actionability: 95/100 (10%) — Dev config is specific and deployable: real-looking private DNS names, private IP (10.0.1.10), realistic storage account name, file-based secret injection (not hardcoded keys), DLQ configured, JVM heap tuned for D2s_v5 (8 GiB), JMX on private IP. nslookup verification command included.
- Summary: Exceptionally thorough research document. All acceptance criteria met with depth. Private endpoint and CMEK integration explained at the right level of detail for implementation. Dev environment example is directly usable. UAMI limitation acknowledged honestly with a practical workaround. Alert thresholds on JMX metrics provide immediate operational value.
<!-- SECTION:NOTES:END -->
