---
id: TASK-27.3
title: 'Research: Confluent Platform Architecture'
status: To Do
assignee: []
created_date: '2026-03-30 13:36'
labels:
  - research
  - SP0P1
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/platform.html'
  - 'https://docs.confluent.io/kafka/introduction.html'
  - 'https://docs.confluent.io/platform/current/kafka/tiered-storage.html'
  - 'https://docs.confluent.io/platform/current/kafka/sbc/index.html'
documentation:
  - doc-SP0.001-confluent-platform-architecture
parent_task_id: TASK-27
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research the Confluent Platform architecture as it applies to deployment on Azure VMs. Cover broker topology and partition management, ZooKeeper coordination (and KRaft migration path), tiered storage with Azure Blob Storage, and self-balancing cluster features. The output document must provide enough detail for a coder to design the Terraform + Ansible deployment in SP1.

Focus areas:
- Broker internals: partitions, replication, ISR, leader election
- ZooKeeper: quorum sizing, session management, planned deprecation
- Tiered storage: local vs remote segments, retrieval latency, Azure Blob integration
- Self-balancing: automatic partition reassignment, rack awareness, throttling
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document covers Kafka broker architecture: partitions, replication factor, ISR, leader election
- [ ] #2 Document covers ZooKeeper role, coordination model, and planned KRaft migration path
- [ ] #3 Document covers tiered storage: how it works, configuration, cost/performance tradeoffs on Azure Blob Storage
- [ ] #4 Document covers self-balancing clusters: trigger conditions, rebalance strategies, monitoring hooks
- [ ] #5 Document includes recommended VM-to-broker mapping for a 3-region Azure deployment
- [ ] #6 Document includes deployment topology diagram (text-based) showing brokers, ZK nodes, and storage tiers
- [ ] #7 All findings cite official Confluent documentation with URLs
- [ ] #8 Executive summary (≤300 words) leads the document
<!-- AC:END -->
