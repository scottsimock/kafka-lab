---
id: TASK-29.10
title: SP2.009 — Schema Registry and Kafka Connect VM Instances
status: To Do
assignee: []
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 16:43'
labels:
  - story
milestone: m-2
dependencies:
  - TASK-29.1
references:
  - terraform/modules/virtual-machine/
documentation:
  - doc-12
parent_task_id: TASK-29
priority: medium
ordinal: 2009
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Instantiate VMs for Schema Registry and Kafka Connect using the virtual-machine module. Schema Registry: 1x D2s_v5 in Zone 1, snet-schema-registry subnet, IP 10.1.3.4, tagged component=schema_registry. Kafka Connect: 1x D2s_v5 in Zone 1, snet-connect subnet, IP 10.1.4.4, tagged component=kafka_connect. Both get 64 GB OS disk and 128 GB data disk.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 1 Schema Registry VM provisioned using the VM module (D2s_v5, Zone 1)
- [ ] #2 VM placed in snet-schema-registry subnet with static IP 10.1.3.4
- [ ] #3 VM tagged component=schema_registry, environment=dev, region=southcentralus
- [ ] #4 1 Kafka Connect VM provisioned using the VM module (D2s_v5, Zone 1)
- [ ] #5 Connect VM placed in snet-connect subnet with static IP 10.1.4.4
- [ ] #6 Connect VM tagged component=kafka_connect, environment=dev, region=southcentralus
- [ ] #7 terraform validate passes
<!-- AC:END -->
