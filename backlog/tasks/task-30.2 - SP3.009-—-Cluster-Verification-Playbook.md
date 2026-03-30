---
id: TASK-30.2
title: SP3.009 — Cluster Verification Playbook
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.5
  - TASK-30.6
references:
  - ansible/playbooks/verify-cluster.yml
documentation:
  - doc-8
parent_task_id: TASK-30
priority: high
ordinal: 3009
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible playbook or task file that performs end-to-end verification of the Kafka cluster. Create a test topic, produce messages, consume messages, and verify broker/ZK health. This validates the entire SP2/SP3 deployment pipeline: VMs, ZooKeeper, brokers, security, and connectivity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Ansible playbook creates a test topic with RF=3 and 6 partitions
- [ ] #2 kafka-topics --describe shows topic with correct configuration
- [ ] #3 Producer can write messages to the test topic using SASL_SSL
- [ ] #4 Consumer can read messages from the test topic using SASL_SSL
- [ ] #5 Broker cluster status shows all 3 brokers registered
- [ ] #6 ZooKeeper ensemble status shows leader elected and quorum healthy
<!-- AC:END -->
