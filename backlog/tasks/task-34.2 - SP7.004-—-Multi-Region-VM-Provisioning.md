---
id: TASK-34.2
title: SP7.004 — Multi-Region VM Provisioning
status: To Do
assignee: []
created_date: '2026-03-30 16:50'
updated_date: '2026-03-30 16:50'
labels:
  - story
milestone: m-7
dependencies:
  - TASK-34.6
  - TASK-34.3
references:
  - terraform/modules/virtual-machine/
documentation:
  - doc-12
parent_task_id: TASK-34
priority: high
ordinal: 7004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Provision Kafka brokers, ZooKeeper observers, and Schema Registry instances in mexicocentral and canadaeast regions using the VM module. Brokers: 3x D4s_v5 per region. ZK: 1 observer per region. SR: 1 instance per region. All VMs tagged for Ansible inventory discovery. Per doc-12.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 3 Kafka brokers provisioned in mexicocentral Zone 1 (D4s_v5)
- [ ] #2 3 Kafka brokers provisioned in canadaeast Zone 1 (D4s_v5)
- [ ] #3 ZooKeeper observers provisioned in secondary/DR regions
- [ ] #4 Schema Registry instances provisioned in secondary/DR regions
- [ ] #5 All VMs tagged with correct component, environment, region tags
- [ ] #6 Ansible dynamic inventory discovers all new VMs
- [ ] #7 terraform validate passes
<!-- AC:END -->
