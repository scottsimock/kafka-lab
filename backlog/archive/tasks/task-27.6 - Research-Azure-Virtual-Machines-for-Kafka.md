---
id: TASK-27.6
title: 'Research: Azure Virtual Machines for Kafka'
status: To Do
assignee: []
created_date: '2026-03-30 13:37'
labels:
  - research
  - SP0P1
milestone: m-0
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/virtual-machines/overview'
  - 'https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types'
  - >-
    https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview
  - >-
    https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview
documentation:
  - doc-SP0.006-azure-vms-for-kafka
parent_task_id: TASK-27
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Azure Virtual Machine sizing, disk configuration, and deployment patterns for running Confluent Platform components. Each component type (broker, ZooKeeper, Connect, Schema Registry) has different resource requirements.

Focus areas:
- VM SKU recommendations for each Confluent component type
- Disk configuration: premium SSD vs ultra disk, data disk count and striping for Kafka log segments
- Availability zone placement for HA within each region
- UAMI setup for authenticating VMs to Azure services (Key Vault, Storage)
- Accelerated networking for low-latency inter-broker communication
- Cost optimization: reserved instances, spot for dev/test
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document recommends VM SKUs for Kafka brokers, ZooKeeper, Connect, and Schema Registry with justification
- [ ] #2 Document covers disk configuration: OS disk, data disks, managed disk types, IOPS/throughput requirements
- [ ] #3 Document covers availability zone placement strategy across the 3 regions
- [ ] #4 Document covers managed identity (UAMI) configuration for VM-to-Azure-service authentication
- [ ] #5 Document covers VM networking: accelerated networking, proximity placement groups
- [ ] #6 Document addresses auto-scaling considerations and VM lifecycle management
- [ ] #7 All findings cite official Microsoft Learn documentation with URLs
- [ ] #8 Executive summary of 300 words or fewer leads the document
<!-- AC:END -->
