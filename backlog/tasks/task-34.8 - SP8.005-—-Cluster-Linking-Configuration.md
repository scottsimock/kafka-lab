---
id: TASK-34.8
title: SP8.005 — Cluster Linking Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:50'
updated_date: '2026-03-31 21:59'
labels:
  - story
milestone: m-7
dependencies:
  - TASK-34.2
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-9
parent_task_id: TASK-34
priority: high
ordinal: 7005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Confluent Cluster Linking between the three regional Kafka clusters. Create links from southcentralus (source) to mexicocentral and canadaeast (destinations), plus mexicocentral to canadaeast for DR failover. Configure auto-create mirror topics, consumer offset sync, and SASL_SSL authentication per link. Per doc-9.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Cluster Link scus-to-mexicocentral created on mexicocentral cluster
- [ ] #2 Cluster Link scus-to-canadaeast created on canadaeast cluster
- [ ] #3 Cluster Link mxc-to-canadaeast created on canadaeast cluster (failover path)
- [ ] #4 Auto-create mirror topics enabled on all links
- [ ] #5 Consumer offset sync enabled (30s interval)
- [ ] #6 SASL_SSL authentication configured for all links
- [ ] #7 Link status shows ACTIVE for all links
<!-- AC:END -->
