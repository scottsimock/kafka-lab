---
id: TASK-36
title: SP0.003 — Schema Registry and Kafka Connect Research
status: In Progress
assignee:
  - coder-3
created_date: '2026-03-30 13:42'
updated_date: '2026-03-30 13:46'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/schema-registry/index.html'
  - 'https://docs.confluent.io/platform/current/connect/index.html'
priority: medium
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Schema Registry deployment patterns and Kafka Connect worker configuration for the kafka-lab project. Cover SR leader election in multi-DC setups, Connect distributed mode, and connectors for Azure Blob Storage (tiered storage sink).\n\nKey areas:\n- Schema Registry deployment: single instance for dev, leader-follower for multi-region\n- SR leader election mechanism and failover behavior\n- Schema compatibility modes and recommended defaults\n- Kafka Connect distributed mode worker configuration\n- Azure Blob Storage Sink Connector for tiered storage offloading\n- Connect plugin installation and management\n- Resource sizing validation (D2s_v5 for SR and Connect)\n\nExpected output: backlog document doc-SP0.003-schema-registry-kafka-connect
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Schema Registry deployment topology documented for single-region and multi-region
- [ ] #2 Leader election and failover behavior for SR documented
- [ ] #3 Recommended schema compatibility mode identified with rationale
- [ ] #4 Kafka Connect distributed mode configuration documented
- [ ] #5 Azure Blob Storage Sink Connector configuration documented
- [ ] #6 Connect plugin installation process documented
- [ ] #7 Resource requirements validated for D2s_v5 SKU
- [ ] #8 All findings reference official Confluent documentation
<!-- AC:END -->
