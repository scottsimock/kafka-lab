---
id: TASK-1.2
title: 'Research: Confluent Platform 7.x Architecture and Components'
status: Done
assignee: []
created_date: '2026-03-27 20:43'
updated_date: '2026-03-28 18:24'
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
- [x] #1 Component inventory documented with HA requirements and port map
- [x] #2 VM sizing recommendations per component identified
- [x] #3 ZooKeeper + 3-broker topology diagram drafted
- [x] #4 Required vs optional components classified for the lab
- [x] #5 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Confluent Platform 7.x Architecture Research**

The doc must cover:

- Component inventory: Kafka brokers, ZooKeeper, Schema Registry, Connect, Cluster Linking, Control Center
- HA requirements per component (required vs optional for lab)
- Port map for all inter-component communication
- VM sizing recommendations per component
- ZooKeeper + 3-broker topology design
- Component co-location constraints and deployment topology

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Research completed via web search across Confluent official documentation, architecture white papers, and community guides. All findings published to backlog doc-3. Key deliverables:\n\n- Full component inventory with HA classification and port map\n- VM sizing table for all 6 components using Azure D-series SKUs\n- ASCII topology diagrams for ZK ensemble + 3-broker layout\n- Required vs optional component matrix for the resilience lab\n- Configuration reference with server.properties, ZK config, SR config, Connect config, and Cluster Linking setup\n- 5 risks and 6 open questions identified for follow-up
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
