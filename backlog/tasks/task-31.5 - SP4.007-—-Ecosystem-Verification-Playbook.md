---
id: TASK-31.5
title: SP4.007 — Ecosystem Verification Playbook
status: To Do
assignee: []
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 16:45'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-31.4
  - TASK-31.7
references:
  - ansible/playbooks/verify-ecosystem.yml
documentation:
  - doc-6
  - doc-7
  - doc-8
parent_task_id: TASK-31
priority: high
ordinal: 4007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible playbook that verifies the complete Kafka ecosystem is operational. Check all component services are running, verify internal topics exist, deploy the Azure Blob sink connector via REST API, and perform an end-to-end test: produce an Avro-encoded message, consume with Schema Registry deserialization, and verify data appears in Blob Storage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Internal Connect topics verified (connect-configs, connect-offsets, connect-status)
- [ ] #2 Schema Registry _schemas topic verified
- [ ] #3 Azure Blob connector deployed and RUNNING status confirmed via REST API
- [ ] #4 End-to-end test: produce Avro message -> consume with schema -> sink to blob storage
- [ ] #5 All component systemd services running (systemctl status shows active)
<!-- AC:END -->
