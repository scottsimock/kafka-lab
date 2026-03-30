---
id: TASK-30.4
title: SP3.003 — Ansible Group and Host Variables
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.8
  - TASK-30.1
references:
  - ansible/inventory/group_vars/
  - ansible/inventory/host_vars/
documentation:
  - doc-13
parent_task_id: TASK-30
priority: medium
ordinal: 3003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create Ansible group_vars and host_vars files for ZooKeeper and Kafka broker configuration. group_vars/zookeeper.yml defines ensemble settings. group_vars/kafka_broker.yml defines broker defaults. host_vars/ files define per-host values: broker.id, myid, broker.rack, static IP. Follow the variable hierarchy from doc-13.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 group_vars/zookeeper.yml defines ZooKeeper-specific variables
- [ ] #2 group_vars/kafka_broker.yml defines broker-specific variables
- [ ] #3 host_vars/ files define per-host broker.id and myid
- [ ] #4 Variables follow Ansible precedence hierarchy from doc-13
- [ ] #5 All variable files use snake_case naming
<!-- AC:END -->
