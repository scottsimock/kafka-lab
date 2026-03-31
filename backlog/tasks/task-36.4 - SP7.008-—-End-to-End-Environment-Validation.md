---
id: TASK-36.4
title: SP7.008 — End-to-End Environment Validation
status: To Do
assignee: []
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:01'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.1
references:
  - terraform/environments/
  - ansible/
parent_task_id: TASK-36
priority: high
ordinal: 6508
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a comprehensive E2E validation suite that checks the full dev environment stack: VM health (all VMs reachable), Kafka cluster health (brokers in ISR, ZooKeeper quorum), Schema Registry health, Kafka Connect health, Function App health, web app accessibility, inter-component connectivity (web app can reach Kafka through Function App). Produces a structured health report.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Health check: all VMs reachable and reporting healthy
- [ ] #2 Health check: Kafka cluster has all brokers in ISR with elected controller
- [ ] #3 Health check: ZooKeeper ensemble has quorum
- [ ] #4 Health check: Schema Registry responding on expected port
- [ ] #5 Health check: Kafka Connect worker responding on expected port
- [ ] #6 Health check: Function App returns healthy from health endpoint
- [ ] #7 Health check: web app pages load through the full stack
- [ ] #8 Health check: data flow validation (produce then consume round-trip)
- [ ] #9 Structured health report generated with pass/fail per component
<!-- AC:END -->
