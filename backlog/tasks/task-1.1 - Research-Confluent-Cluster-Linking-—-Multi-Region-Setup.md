---
id: TASK-1.1
title: 'Research: Confluent Cluster Linking — Multi-Region Setup'
status: To Do
assignee: []
created_date: '2026-03-27 20:43'
updated_date: '2026-03-28 18:13'
labels:
  - research
  - confluent
  - cluster-linking
  - multi-region
  - disaster-recovery
dependencies: []
references:
  - >-
    https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/overview.html
  - >-
    https://docs.confluent.io/platform/current/multi-dc-deployments/replication/index.html
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Confluent Cluster Linking to understand how to replicate topics between the primary (southcentralus) and secondary (mexicocentral) active clusters, and to the passive DR cluster (canadaeast).

## Goals
- Understand Cluster Linking architecture, prerequisites, and configuration
- Understand how Cluster Linking differs from MirrorMaker 2
- Research failover and failback procedures for Cluster Linking
- Understand offset translation and consumer group migration
- Identify Cluster Linking behavior during network partitions and region failures (ties directly to chaos experiments)

## Key Questions
- How is Cluster Linking configured between 3 clusters (2 active + 1 passive DR)?
- What are the network requirements between clusters (VNet peering, private endpoints, public)?
- How does consumer group offset sync work across clusters?
- What is the RTO/RPO profile of Cluster Linking?

## Primary References (from README)
- https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/overview.html
- https://docs.confluent.io/platform/current/multi-dc-deployments/replication/index.html
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Cluster Linking configuration requirements documented
- [ ] #2 Offset sync and failover/failback procedures outlined
- [ ] #3 Network requirements between clusters identified
- [ ] #4 RTO/RPO characteristics documented
- [ ] #5 Differences from MirrorMaker 2 noted
- [ ] #6 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Confluent Cluster Linking — Multi-Region Research**

The doc must cover:

- Cluster Linking architecture and how it connects the 3 clusters (SCUS primary, MXC secondary, CAE passive DR)
- Configuration requirements and prerequisites
- Offset sync and consumer group migration procedures
- Failover and failback procedures with RTO/RPO profile
- Comparison with MirrorMaker 2
- Network requirements between clusters
- Behavior during network partitions (input for chaos experiments)

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
