---
id: TASK-30.3
title: SP3.010 — Kafka ACL Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.6
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: medium
ordinal: 3010
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Kafka ACLs for all service principals created in SP3.006. Define least-privilege access for each service: web-app gets read/write on app topics, schema-registry gets _schemas topic access, connect-worker gets connect internal topics, admin gets cluster-wide access. Create an Ansible task file that applies ACLs using kafka-acls CLI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Kafka ACLs configured for each service principal (web-app, schema-registry, connect-worker)
- [ ] #2 web-app user has read/write on application topics, read on consumer groups
- [ ] #3 schema-registry user has full access to _schemas topic
- [ ] #4 connect-worker user has access to connect-* internal topics and configured data topics
- [ ] #5 admin user has cluster-wide access
- [ ] #6 ACLs verified with kafka-acls --list
<!-- AC:END -->
