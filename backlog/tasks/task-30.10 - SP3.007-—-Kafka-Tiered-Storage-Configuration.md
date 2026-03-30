---
id: TASK-30.10
title: SP3.007 — Kafka Tiered Storage Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.5
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-8
parent_task_id: TASK-30
priority: medium
ordinal: 3007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Confluent Tiered Storage on Kafka brokers to offload warm log segments to Azure Blob Storage. Add tiered storage properties to the broker server.properties template: enable tier feature, configure Azure Blob Storage backend with the storage account from SP1.011, set hotset retention period. Per doc-8, tiered storage uses a single log.dirs path (no JBOD). Authentication uses UAMI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tiered storage properties added to server.properties template
- [ ] #2 confluent.tier.feature=true and confluent.tier.enable=true set
- [ ] #3 Azure Blob Storage configured as remote storage backend
- [ ] #4 Storage account credentials reference UAMI authentication
- [ ] #5 confluent.tier.local.hotset.ms configurable (default 24h)
- [ ] #6 Broker restarts with tiered storage enabled
- [ ] #7 Verification: topic with remote storage shows segments offloading
<!-- AC:END -->
