---
id: TASK-1.9
title: 'Research: Azure Chaos Studio — Resilience Experiment Design'
status: To Do
assignee: []
created_date: '2026-03-27 20:44'
updated_date: '2026-03-28 18:13'
labels:
  - research
  - azure
  - chaos-studio
  - resilience-testing
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview'
  - >-
    https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-library
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Azure Chaos Studio capabilities for designing resilience experiments targeting the Kafka Lab: AZ failures, region failures, VM-level faults, and Kafka process-level faults.

## Goals
- Understand Azure Chaos Studio architecture: experiments, targets, fault providers, agents
- Map the lab's chaos scenarios to available Chaos Studio fault providers:
  - AZ failure: shutting down all VMs in a zone
  - Region failure: shutting down all VMs in a region or blocking cross-region networking
  - VM-level: VM shutdown, CPU pressure, memory pressure, network disconnect
  - Kafka-level: process kill (via VM agent executing `systemctl stop confluent-kafka`)
- Research Chaos Studio experiment RBAC and UAMI requirements
- Understand how to instrument the lab to observe the blast radius (metrics, alerts)

## Key Questions
- What is the difference between Chaos Studio service-direct faults vs agent-based faults?
- Can Chaos Studio target all VMs in a specific AZ in one experiment step?
- How does Chaos Studio integrate with Azure Monitor for experiment observability?

## Primary References (from README)
- https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Chaos Studio fault providers for VMs and networking identified
- [ ] #2 AZ-level failure experiment design documented (targeting 1 zone's VMs)
- [ ] #3 Region-level failure experiment design documented (simulating full region outage)
- [ ] #4 VM shutdown, CPU pressure, and network disconnect fault configurations described
- [ ] #5 Kafka broker failure fault experiment designed
- [ ] #6 Experiment sequencing and observation strategy documented
- [ ] #7 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Azure Chaos Studio Experiment Research**

The doc must cover:

- Chaos Studio architecture: experiments, targets, fault providers, agents
- Service-direct vs agent-based fault comparison
- AZ-level failure experiment design
- Region-level failure experiment design
- VM shutdown, CPU pressure, and network disconnect configurations
- Kafka broker process kill experiment design
- Experiment sequencing and observation strategy
- RBAC and UAMI requirements for experiments

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
