---
id: TASK-31.7
title: SP4.004 — Azure Blob Storage Sink Connector
status: To Do
assignee: []
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 16:45'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-31.6
references:
  - ansible/roles/kafka-connect/
documentation:
  - doc-7
parent_task_id: TASK-31
priority: medium
ordinal: 4004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Install and configure the Azure Blob Storage Sink Connector for Kafka Connect. Install via confluent-hub CLI. Create a connector configuration JSON file that sinks data from specified topics to Azure Blob Storage using Avro format. Configure UAMI-based authentication (no storage keys), DLQ for error handling, and flush.size for batching. Per doc-7, connectors are managed via REST API.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Ansible task installs Azure Blob Storage Sink Connector via confluent-hub install
- [ ] #2 Connector JAR placed in plugin.path directory
- [ ] #3 Connector configuration JSON file created for Azure Blob sink
- [ ] #4 Configuration includes storage account, container, format (Avro), flush.size
- [ ] #5 Authentication uses UAMI (no storage account keys)
- [ ] #6 Dead Letter Queue (DLQ) topic configured for error handling
<!-- AC:END -->
