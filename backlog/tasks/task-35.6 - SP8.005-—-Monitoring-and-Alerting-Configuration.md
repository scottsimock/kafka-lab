---
id: TASK-35.6
title: SP8.005 — Monitoring and Alerting Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:51'
labels:
  - story
milestone: m-8
dependencies: []
references:
  - ansible/roles/
documentation:
  - doc-8
parent_task_id: TASK-35
priority: medium
ordinal: 8005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure monitoring and alerting for the Kafka cluster. Export JMX metrics from brokers, ZooKeeper, Schema Registry, and Connect workers. Define key operational metrics: under-replicated partitions, offline partitions, consumer lag, broker count. Configure Azure Monitor for VM metrics. Create alert rules for critical conditions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 JMX metrics exported from all Kafka components
- [ ] #2 Broker metrics: UnderReplicatedPartitions, ActiveControllerCount, OfflinePartitionsCount
- [ ] #3 Consumer lag metrics collected for all consumer groups
- [ ] #4 Azure Monitor integration for VM-level metrics
- [ ] #5 Alerting rules for critical conditions (all brokers down, quorum lost, high lag)
- [ ] #6 Dashboard or query templates for key operational metrics
<!-- AC:END -->
