---
id: TASK-28.8
title: SP1.007 — NSG Instances for All Subnets
status: To Do
assignee: []
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 16:40'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.10
  - TASK-28.5
references:
  - terraform/modules/network-security-group/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: medium
ordinal: 1007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using the NSG module from SP1.006, instantiate 7 NSGs (one per subnet) with security rules matching the research doc-10 specifications. nsg-kafka-brokers: allow ports 9092/9093 from connect, web-app, broker subnets; port 9021 from management; SSH from management. nsg-zookeeper: allow 2181 from brokers, 2888/3888 from ZK peers, SSH from management. nsg-schema-registry: allow 8081 from brokers, connect, web-app. nsg-connect: allow 8083 from management, web-app. nsg-web-app: allow 443 inbound. nsg-management: allow SSH, monitoring ports.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 NSG nsg-kafka-brokers created with rules per doc-10 (ports 9092, 9093, 9021, 22)
- [ ] #2 NSG nsg-zookeeper created with rules per doc-10 (ports 2181, 2888, 3888, 22)
- [ ] #3 NSG nsg-schema-registry created with rules (ports 8081, 22)
- [ ] #4 NSG nsg-connect created with rules (ports 8083, 22)
- [ ] #5 NSG nsg-web-app created with rules (ports 443, 22)
- [ ] #6 NSG nsg-private-endpoints created with appropriate rules
- [ ] #7 NSG nsg-management created with management access rules
- [ ] #8 All NSGs associated with their respective subnets
- [ ] #9 terraform validate passes
<!-- AC:END -->
