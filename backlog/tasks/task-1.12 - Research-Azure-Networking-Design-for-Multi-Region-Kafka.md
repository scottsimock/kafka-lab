---
id: TASK-1.12
title: 'Research: Azure Networking Design for Multi-Region Kafka'
status: Done
assignee: []
created_date: '2026-03-27 20:45'
updated_date: '2026-03-28 18:31'
labels:
  - research
  - azure
  - networking
  - infrastructure
dependencies: []
references:
  - >-
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview
  - >-
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Azure networking design for the Kafka Lab, covering VNet topology, cross-region connectivity for Cluster Linking, and NSG rules for Confluent Platform ports.

## Goals
- Design VNet topology for each region: subnets per tier (Kafka brokers, ZooKeeper, Schema Registry, Connect, management)
- Research cross-region connectivity options for Cluster Linking traffic between southcentralus and mexicocentral
- Understand NSG rules required for all Confluent inter-component and client communication ports
- Research private endpoints for Kafka listeners (no public IPs on broker VMs)
- Understand Azure DNS configuration for Kafka broker hostname resolution across regions

## Key Questions
- Should Kafka brokers use private IPs only, and how do cross-region clients resolve hostnames?
- What is the recommended cross-region connectivity method for Cluster Linking (VNet peering vs VPN Gateway)?
- How does Azure networking affect Kafka advertised listeners configuration?

## Primary References (from README)
- https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview
- https://learn.microsoft.com/en-us/azure/virtual-machines/overview
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 VNet design for each region documented (address space, subnets per tier)
- [x] #2 VNet peering strategy between southcentralus and mexicocentral documented
- [x] #3 ExpressRoute vs VPN Gateway vs VNet peering decision documented for cross-region Kafka traffic
- [x] #4 NSG rules for Kafka broker, ZooKeeper, Schema Registry, and Connect ports documented
- [x] #5 Private endpoint vs public endpoint decision for each Confluent component documented
- [x] #6 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Azure Networking Multi-Region Design Research**

The doc must cover:

- VNet topology per region: address spaces, subnets per tier
- Cross-region connectivity for Cluster Linking (VNet peering vs VPN Gateway vs ExpressRoute)
- NSG rules for all Confluent component ports
- Private endpoint vs public endpoint decision per component
- Azure DNS configuration for broker hostname resolution across regions
- Kafka advertised listeners configuration with Azure networking

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
