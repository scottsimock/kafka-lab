---
id: TASK-31
title: SP4 — Kafka Ecosystem Services
status: In Progress
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:57'
labels:
  - sprint
milestone: m-4
dependencies: []
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Kafka ecosystem services sprint covering Schema Registry deployment, Kafka Connect deployment with Azure Blob Storage sink connector, topic management, and end-to-end ecosystem verification.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Schema Registry is deployed, secured, and serving Avro/JSON schemas over HTTPS
- [ ] #2 Kafka Connect cluster is running with the Azure Blob Storage sink connector configured
- [ ] #3 Application topics are created with appropriate partitioning and replication settings
- [ ] #4 Schemas are registered in Schema Registry and validated for compatibility
- [ ] #5 Ecosystem verification playbook confirms Schema Registry, Connect, and sink connector operate end-to-end
<!-- AC:END -->
