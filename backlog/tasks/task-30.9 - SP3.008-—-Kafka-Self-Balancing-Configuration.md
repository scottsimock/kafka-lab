---
id: TASK-30.9
title: SP3.008 — Kafka Self-Balancing Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.5
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-8
parent_task_id: TASK-30
priority: medium
ordinal: 3008
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Confluent Self-Balancing Clusters on Kafka brokers. Add properties to server.properties: enable balancer, set trigger mode, configure throttle rates for partition movement, and enable the metrics reporter. Per doc-8, self-balancing automatically redistributes partitions when broker topology changes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Self-balancing properties added to server.properties template
- [ ] #2 confluent.balancer.enable=true set
- [ ] #3 confluent.balancer.heal.uneven.load.trigger=ANY_UNEVEN_LOAD
- [ ] #4 Broker throttle rate configured for rebalancing
- [ ] #5 Metrics reporter configured for self-balancing decisions
<!-- AC:END -->
