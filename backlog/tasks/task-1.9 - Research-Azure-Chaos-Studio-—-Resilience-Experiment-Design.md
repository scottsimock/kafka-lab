---
id: TASK-1.9
title: 'Research: Azure Chaos Studio — Resilience Experiment Design'
status: Done
assignee: []
created_date: '2026-03-27 20:44'
updated_date: '2026-03-28 18:26'
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
- [x] #1 Chaos Studio fault providers for VMs and networking identified
- [x] #2 AZ-level failure experiment design documented (targeting 1 zone's VMs)
- [x] #3 Region-level failure experiment design documented (simulating full region outage)
- [x] #4 VM shutdown, CPU pressure, and network disconnect fault configurations described
- [x] #5 Kafka broker failure fault experiment designed
- [x] #6 Experiment sequencing and observation strategy documented
- [x] #7 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Research Complete: Azure Chaos Studio Experiment Design

### What was delivered
Comprehensive research document (doc-9) covering Azure Chaos Studio architecture, fault providers, experiment design patterns, RBAC requirements, and observability integration for the Kafka Lab's multi-region Confluent Platform deployment.

### Key findings
- **Service-direct faults** (VM shutdown, VMSS zone shutdown) operate at the Azure control plane — no agent required
- **Agent-based faults** (CPU pressure, memory pressure, network disconnect, process kill) require the `ChaosAgentLinux` VM extension and operate inside the guest OS
- AZ failure simulation uses List-type selectors grouping VMs by zone with `urn:csci:microsoft:virtualMachine:shutdown/1.0`
- Region failure requires shutting down all VMs in a region or combining `networkDisconnect` with NSG manipulation
- Kafka broker process kill uses `urn:csci:microsoft:agent:killProcess/1.0` with `processName: "java"`
- Each experiment requires a UAMI with `Virtual Machine Contributor` for shutdown faults and `Reader` for agent-based faults

### Design decisions
1. One UAMI per experiment category (AZ, region, VM, Kafka-level)
2. Explicit List selectors over VMSS dynamic targeting (lab uses individual VMs)
3. Dual-mode target onboarding (service-direct + agent-based) on all broker VMs
4. Azure Monitor integration with alert-driven auto-cancel for SLO breaches

### Artifacts
- Backlog document: doc-9 "Azure Chaos Studio Experiment Research"
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
