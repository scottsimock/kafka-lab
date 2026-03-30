---
id: TASK-35.2
title: SP8.001 — Chaos Studio Target Onboarding
status: To Do
assignee: []
created_date: '2026-03-30 16:51'
labels:
  - story
milestone: m-8
dependencies: []
references:
  - terraform/modules/virtual-machine/
documentation:
  - doc-15
parent_task_id: TASK-35
priority: high
ordinal: 8001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Provision Azure Chaos Studio target resources and capabilities on all Kafka VMs. Create Chaos Studio targets (service-direct and agent-based) as child resources of each VM. Install the Chaos Agent VM extension. Enable fault capabilities: VM shutdown, process kill, CPU pressure, network disconnect. Configure UAMI permissions. Per doc-15.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Terraform provisions Chaos Studio targets on all Kafka VMs
- [ ] #2 Service-direct targets (Microsoft-VirtualMachine) enabled on all VMs
- [ ] #3 Agent-based targets (Microsoft-Agent) enabled on all VMs
- [ ] #4 Chaos Agent VM extension installed on all VMs via Terraform
- [ ] #5 Capabilities enabled: shutdown, killProcess, cpuPressure, networkDisconnect
- [ ] #6 UAMI with Reader role assigned for agent-based targets
- [ ] #7 Experiment UAMI with VM Contributor role for service-direct faults
<!-- AC:END -->
