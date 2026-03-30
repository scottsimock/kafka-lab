---
id: TASK-29
title: SP0.001 — Confluent Platform Architecture Research
status: In Progress
assignee:
  - coder-1
created_date: '2026-03-30 13:42'
updated_date: '2026-03-30 13:46'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/platform.html'
  - 'https://docs.confluent.io/kafka/introduction.html'
priority: medium
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Confluent Platform 7.8.x architecture for multi-region Kafka deployment. Cover broker configuration, ZooKeeper setup, cluster topology patterns, and key broker properties. Focus on settings required for multi-AZ deployment within a single region and cross-region replication readiness.\n\nKey areas:\n- Kafka broker configuration properties for 7.8.x (listeners, log dirs, replication factor, min ISR)\n- ZooKeeper ensemble sizing and configuration (3-node ensemble)\n- Cluster topology for primary region (southcentralus) with 3 brokers across 2 AZs\n- Rack awareness configuration for AZ-aware replica placement\n- JMX metrics exposure for Prometheus monitoring\n- Resource requirements validation (D4s_v5 for brokers, D2s_v5 for ZK)\n\nExpected output: backlog document doc-SP0.001-confluent-platform-architecture
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document covers Kafka broker properties for 7.8.x with recommended values and rationale
- [ ] #2 ZooKeeper ensemble configuration documented with connection strings and tick time settings
- [ ] #3 Cluster topology diagram or description for 3-broker, 2-AZ deployment
- [ ] #4 Rack awareness configuration for AZ-aware replica placement documented
- [ ] #5 JMX configuration for Prometheus integration specified
- [ ] #6 Dev environment resource requirements validated against D4s_v5 and D2s_v5 SKUs
- [ ] #7 All findings reference official Confluent 7.8.x documentation
<!-- AC:END -->
