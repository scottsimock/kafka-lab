---
id: TASK-27.11
title: 'Research: Azure Chaos Studio for Kafka Resiliency'
status: To Do
assignee: []
created_date: '2026-03-30 13:38'
labels:
  - research
  - SP0P1
milestone: m-0
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview'
  - >-
    https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-library
  - >-
    https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-agent-based-portal
documentation:
  - doc-SP0.010-azure-chaos-studio
parent_task_id: TASK-27
priority: high
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Azure Chaos Studio experiment types and patterns for testing Kafka cluster resiliency. The lab must validate that the Confluent deployment survives VM failures, network partitions, and resource pressure across regions.

Focus areas:
- Chaos Studio experiment types: VM shutdown, network disconnect, disk I/O, CPU/memory stress
- Targeting strategies: by VM role, region, availability zone
- Abort conditions and safety: automatic rollback, experiment duration limits
- Integration with Azure Monitor for observing Kafka behavior during chaos
- Scenario design: at least 5 scenarios for validating broker failover, partition reassignment, and Cluster Linking resilience
- Prerequisites: Chaos Agent installation, RBAC permissions, UAMI requirements
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document catalogs Chaos Studio experiment types relevant to Kafka: VM shutdown, network disconnect, disk I/O pressure, CPU/memory stress
- [ ] #2 Document covers experiment targeting: how to target specific VMs by role, region, and AZ
- [ ] #3 Document covers abort conditions and safety mechanisms (automatic rollback, duration limits)
- [ ] #4 Document covers integration with Azure Monitor for observing chaos impact on Kafka metrics
- [ ] #5 Document defines at least 5 chaos scenarios for validating Kafka cluster resiliency
- [ ] #6 Document covers prerequisites: agent installation, RBAC permissions, managed identity requirements
- [ ] #7 All findings cite official Microsoft Learn documentation with URLs
- [ ] #8 Executive summary of 300 words or fewer leads the document
<!-- AC:END -->
