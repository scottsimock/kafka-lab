---
id: TASK-1.4
title: 'Research: Confluent Kafka Connect — Lab Deployment'
status: To Do
assignee: []
created_date: '2026-03-27 20:43'
labels:
  - research
  - confluent
  - kafka-connect
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/connect/index.html'
parent_task_id: TASK-1
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Confluent Kafka Connect to understand its role in the lab and how it should be deployed alongside the Kafka clusters.

## Goals
- Understand Kafka Connect worker modes (standalone vs distributed) and which is appropriate for the lab
- Identify which connector types are relevant (e.g., source and sink for generating test data or forwarding messages between regions)
- Understand Connect worker failover and HA behavior
- Research how Connect integrates with Schema Registry

## Key Questions
- Does the lab require Kafka Connect for data generation, or is the FastAPI producer app sufficient?
- If Connect is used, should it run on dedicated VMs or co-located with brokers?
- What is the minimum Connect configuration for distributed mode?

## Primary References (from README)
- https://docs.confluent.io/platform/current/connect/index.html
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Connect worker distributed mode configuration documented
- [ ] #2 Connector types relevant to lab identified
- [ ] #3 Connect HA and failover behavior documented
- [ ] #4 Integration with Schema Registry for Avro-serialized data documented
<!-- AC:END -->
