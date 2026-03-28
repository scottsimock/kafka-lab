---
id: TASK-1.5
title: 'Research: Azure VM Infrastructure for Kafka Brokers'
status: Done
assignee: []
created_date: '2026-03-27 20:44'
updated_date: '2026-03-28 18:24'
labels:
  - research
  - azure
  - virtual-machines
  - infrastructure
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/virtual-machines/overview'
  - >-
    https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview
  - 'https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types'
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Azure Virtual Machine options and configuration requirements for hosting Confluent Platform 7.x components on Ubuntu 22.04 LTS, across multiple AZs and regions.

## Goals
- Identify appropriate VM SKUs for Kafka brokers (storage-optimized), ZooKeeper nodes, and ancillary services
- Understand disk configuration for Kafka data directories (Premium SSD, striping, mount options)
- Research availability zone placement for 3 brokers across AZs (1 broker per zone recommended)
- Understand Azure VM extensions relevant to the lab (monitoring agents, diagnostics)
- Research VM scale sets vs individual VMs for broker nodes in a lab context

## Key Questions
- What disk type and configuration is recommended for Kafka data logs on Azure?
- How are individual VMs spread across AZs (availability sets vs zone pinning)?
- What VM SKU provides the right balance of CPU, memory, and network for a lab?

## Primary References (from README)
- https://learn.microsoft.com/en-us/azure/virtual-machines/overview
- https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 VM SKU recommendations per component (broker, ZooKeeper, Schema Registry, Connect) documented
- [x] #2 Disk sizing and IOPS requirements for Kafka data logs documented
- [x] #3 Availability Zone placement strategy for 3-broker cluster documented
- [x] #4 Azure VM extension and monitoring agent requirements identified
- [x] #5 Ubuntu 22.04 LTS-specific Azure VM considerations noted
- [x] #6 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Azure VM Infrastructure for Kafka Research**

The doc must cover:

- VM SKU recommendations per component (broker, ZooKeeper, Schema Registry, Connect)
- Disk configuration for Kafka data directories (type, IOPS, mount options)
- Availability Zone placement strategy for 3-broker clusters
- VM scale sets vs individual VMs decision for lab
- Azure VM extensions and monitoring agents
- Ubuntu 22.04 LTS Azure-specific considerations

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
