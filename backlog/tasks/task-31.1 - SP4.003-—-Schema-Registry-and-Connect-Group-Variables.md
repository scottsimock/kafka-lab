---
id: TASK-31.1
title: SP4.003 — Schema Registry and Connect Group Variables
status: To Do
assignee: []
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 16:45'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-31.3
  - TASK-31.6
references:
  - ansible/inventory/group_vars/
documentation:
  - doc-6
  - doc-7
  - doc-13
parent_task_id: TASK-31
priority: medium
ordinal: 4003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create Ansible group_vars files for Schema Registry and Kafka Connect. group_vars/schema_registry.yml defines bootstrap servers, security protocol, JVM heap (512m dev), schema compatibility level. group_vars/kafka_connect.yml defines bootstrap servers, group.id, converter classes, plugin path, REST API settings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 group_vars/schema_registry.yml defines SR-specific variables
- [ ] #2 group_vars/kafka_connect.yml defines Connect-specific variables
- [ ] #3 Variables include bootstrap servers, security settings, JVM heap sizes
- [ ] #4 SR JVM heap set to 512m for dev
- [ ] #5 Connect converter classes configured for Avro with Schema Registry
<!-- AC:END -->
