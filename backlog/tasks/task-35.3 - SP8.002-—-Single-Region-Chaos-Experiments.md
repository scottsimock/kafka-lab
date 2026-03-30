---
id: TASK-35.3
title: SP8.002 — Single-Region Chaos Experiments
status: To Do
assignee: []
created_date: '2026-03-30 16:51'
updated_date: '2026-03-30 16:51'
labels:
  - story
milestone: m-8
dependencies:
  - TASK-35.2
references:
  - terraform/
documentation:
  - doc-15
parent_task_id: TASK-35
priority: high
ordinal: 8002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create Chaos Studio experiments for single-region resiliency testing. Define experiments: single broker VM shutdown (ISR recovery), ZK node failure (quorum), Kafka process kill (recovery time), CPU pressure (self-balancing). Each experiment defined as azapi_resource with steps, branches, and actions. Include abort conditions. Per doc-15.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Experiment: single broker shutdown (verify partition leadership transfer)
- [ ] #2 Experiment: ZooKeeper node failure (verify quorum maintained)
- [ ] #3 Experiment: Kafka process kill (verify systemd restart and broker recovery)
- [ ] #4 Experiment: CPU pressure on broker (verify self-balancing response)
- [ ] #5 All experiments defined as Terraform azapi_resource with Microsoft.Chaos/experiments
- [ ] #6 Experiments include abort conditions based on Azure Monitor metrics
<!-- AC:END -->
