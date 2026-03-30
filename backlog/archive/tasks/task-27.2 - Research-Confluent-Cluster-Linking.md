---
id: TASK-27.2
title: 'Research: Confluent Cluster Linking'
status: To Do
assignee: []
created_date: '2026-03-30 13:36'
labels:
  - research
  - SP0P1
milestone: m-0
dependencies: []
references:
  - >-
    https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/overview.html
  - >-
    https://docs.confluent.io/platform/current/multi-dc-deployments/replication/index.html
  - >-
    https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/mirror-topics-cp.html
documentation:
  - doc-SP0.002-confluent-cluster-linking
parent_task_id: TASK-27
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Confluent Cluster Linking for multi-datacenter replication and disaster recovery. This is the core mechanism for replicating data across the project's three Azure regions. Cover mirror topics, consumer offset synchronization, ACL sync, and failover procedures.

Focus areas:
- Cluster Link architecture and data flow
- Mirror topics: creation, sync lag, promotion to writable
- Active-passive vs active-active topology tradeoffs
- Failover workflow: automated detection → link promotion → client redirect
- Configuration properties for cross-region links
- RPO/RTO expectations and how to monitor them
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document explains Cluster Linking mechanics: mirror topics, consumer offset sync, ACL sync
- [ ] #2 Document compares active-passive vs active-active topologies with tradeoffs
- [ ] #3 Document covers failover procedure: detection, promotion, client redirection
- [ ] #4 Document covers configuration for cross-region linking (southcentralus ↔ mexicocentral ↔ canadaeast)
- [ ] #5 Document addresses RPO/RTO targets achievable with Cluster Linking
- [ ] #6 Document includes link configuration example (properties format)
- [ ] #7 All findings cite official Confluent documentation with URLs
- [ ] #8 Executive summary (≤300 words) leads the document
<!-- AC:END -->
