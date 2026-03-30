---
id: TASK-29.2
title: SP2.002 — ZooKeeper VM Instances
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
ordinal: 2002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Instantiate 3 ZooKeeper VMs using the virtual-machine module. Each VM uses D2s_v5 SKU in southcentralus Zone 1, placed in snet-zookeeper subnet. Static IPs: 10.1.2.4, 10.1.2.5, 10.1.2.6. Each VM gets a 64 GB P6 OS disk and 128 GB data disk for ZooKeeper data/txn logs. Tag each with component=zookeeper for Ansible inventory discovery.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 3 ZooKeeper VMs provisioned using the VM module (D2s_v5, Zone 1)
- [ ] #2 VMs placed in snet-zookeeper subnet with static IPs 10.1.2.4, 10.1.2.5, 10.1.2.6
- [ ] #3 Each VM tagged component=zookeeper, environment=dev, region=southcentralus
- [ ] #4 64 GB Premium SSD OS disk + 128 GB Premium SSD data disk per node
- [ ] #5 UAMI assigned to each VM
- [ ] #6 terraform validate passes
<!-- AC:END -->
