---
id: TASK-31
title: SP0.006 — Azure VM and Networking for Kafka Research
status: To Do
assignee: []
created_date: '2026-03-30 13:42'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/virtual-machines/overview'
  - >-
    https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview
priority: medium
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Azure VM sizing, disk configuration, and networking architecture for Kafka cluster deployment across 3 regions. Validate VM SKUs, design VNet topology, and define NSG rules for Kafka ports.\n\nKey areas:\n- VM SKU validation: D4s_v5 (brokers), D2s_v5 (ZK, SR, Connect) — vCPU, memory, network bandwidth\n- Disk configuration: Premium SSD v2 or Premium SSD for Kafka log directories, OS disk sizing\n- VNet design: one VNet per region (southcentralus, mexicocentral, canadaeast)\n- Subnet layout: separate subnets for Kafka brokers, ZooKeeper, management, and private endpoints\n- VNet peering: full mesh or hub-spoke between 3 regional VNets\n- NSG rules: Kafka (9092-9094), ZooKeeper (2181, 2888, 3888), Schema Registry (8081), Connect (8083), JMX, SSH\n- Private DNS zones for internal service discovery\n- Availability zone placement strategy for VMs\n- Azure Accelerated Networking for Kafka VMs\n\nExpected output: backlog document doc-SP0.006-azure-vm-networking
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 VM SKU specifications validated with vCPU, memory, disk, and network throughput
- [ ] #2 Disk configuration recommended for Kafka log directories with IOPS/throughput estimates
- [ ] #3 VNet CIDR ranges defined for all 3 regions without overlap
- [ ] #4 Subnet layout documented with IP range allocation
- [ ] #5 VNet peering topology recommended with rationale
- [ ] #6 NSG rules documented for all Kafka component ports
- [ ] #7 Private DNS zone names and records structure documented
- [ ] #8 AZ placement strategy documented for each VM role
- [ ] #9 All findings reference official Azure documentation
<!-- AC:END -->
