---
id: TASK-1.2
title: 'Research: Confluent Platform 7.x Architecture and Components'
status: To Do
assignee: []
created_date: '2026-03-27 20:43'
labels:
  - research
  - confluent
  - architecture
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/platform.html'
  - 'https://docs.confluent.io/kafka/introduction.html'
  - >-
    https://docs.confluent.io/platform/current/installation/system-requirements.html
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deep-dive into Confluent Platform 7.x overall architecture to understand how all components fit together before designing the lab topology.

## Goals
- Understand the role of each component: Kafka brokers, ZooKeeper, Schema Registry, Connect, Cluster Linking, Control Center
- Identify required ports, network dependencies, and component co-location constraints
- Understand minimum hardware/VM requirements for a 3-broker lab cluster
- Identify which components must be HA and which can be single-node in a lab context

## Key Questions
- Which components are strictly required vs optional for the resilience lab?
- What is the recommended deployment topology for ZooKeeper with 3 Kafka brokers?
- What are the inter-component communication patterns and port requirements?

## Primary References (from README)
- https://docs.confluent.io/platform/current/platform.html
- https://docs.confluent.io/kafka/introduction.html
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Component inventory documented with HA requirements and port map
- [ ] #2 VM sizing recommendations per component identified
- [ ] #3 ZooKeeper + 3-broker topology diagram drafted
- [ ] #4 Required vs optional components classified for the lab
<!-- AC:END -->
