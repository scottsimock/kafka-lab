---
id: TASK-29.3
title: SP2.003 — Kafka Broker VM Instances
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
priority: high
ordinal: 2003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Instantiate 3 Kafka broker VMs using the virtual-machine module. Each VM uses D4s_v5 SKU in southcentralus Zone 1, placed in snet-kafka-brokers subnet. Static IPs: 10.1.1.4, 10.1.1.5, 10.1.1.6. Each broker gets a 64 GB P6 OS disk and 2 TB P40 data disk for Kafka log directories. Tag each with component=kafka_broker for Ansible inventory discovery.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 3 Kafka broker VMs provisioned using the VM module (D4s_v5, Zone 1)
- [ ] #2 VMs placed in snet-kafka-brokers subnet with static IPs 10.1.1.4, 10.1.1.5, 10.1.1.6
- [ ] #3 Each VM tagged component=kafka_broker, environment=dev, region=southcentralus
- [ ] #4 64 GB Premium SSD OS disk + 2 TB P40 data disk per broker
- [ ] #5 UAMI assigned to each VM
- [ ] #6 terraform validate passes
<!-- AC:END -->
