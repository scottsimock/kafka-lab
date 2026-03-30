---
id: TASK-29.9
title: SP2.010 — Ansible Site Playbook
status: To Do
assignee: []
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 16:43'
labels:
  - story
milestone: m-2
dependencies:
  - TASK-29.4
  - TASK-29.8
references:
  - ansible/site.yml
documentation:
  - doc-13
parent_task_id: TASK-29
priority: medium
ordinal: 2010
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the master Ansible playbook at ansible/site.yml that orchestrates the full Confluent Platform deployment. Define plays for each component group targeting Ansible inventory groups. Apply roles in order: common, disk-setup, java, confluent-common, then component-specific roles (to be created in SP3). Use serial: 1 for ZooKeeper and broker plays to ensure rolling deployment safety.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 site.yml playbook defines plays for all component groups
- [ ] #2 Each play targets the correct Ansible inventory group (zookeeper, kafka_broker, schema_registry, kafka_connect)
- [ ] #3 Roles applied in dependency order: common -> disk-setup -> java -> confluent-common
- [ ] #4 serial: 1 set for broker and zookeeper plays
- [ ] #5 become: true set where required
- [ ] #6 Playbook syntax check passes (ansible-playbook --syntax-check)
<!-- AC:END -->
