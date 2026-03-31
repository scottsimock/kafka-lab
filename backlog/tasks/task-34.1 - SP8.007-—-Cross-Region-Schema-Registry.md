---
id: TASK-34.1
title: SP8.007 — Cross-Region Schema Registry
status: To Do
assignee: []
created_date: '2026-03-30 16:50'
updated_date: '2026-03-31 21:59'
labels:
  - story
milestone: m-7
dependencies:
  - TASK-34.2
references:
  - ansible/roles/schema-registry/
documentation:
  - doc-6
parent_task_id: TASK-34
priority: medium
ordinal: 7007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Schema Registry instances in secondary and DR regions as read-only followers. Set leader.eligibility=false on non-primary instances. All instances share the same group.id and connect to the regional Kafka cluster. Writes automatically forward to the primary. Per doc-6, SR uses Kafka group protocol for leader election.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Schema Registry in mexicocentral configured with leader.eligibility=false
- [ ] #2 Schema Registry in canadaeast configured with leader.eligibility=false
- [ ] #3 All SR instances share the same schema.registry.group.id
- [ ] #4 Writes forward to primary automatically
- [ ] #5 Reads served from local instance in each region
- [ ] #6 Cross-region SR communication verified
<!-- AC:END -->
