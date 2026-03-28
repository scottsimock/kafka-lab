---
id: TASK-1.4
title: 'Research: Confluent Kafka Connect — Lab Deployment'
status: Done
assignee: []
created_date: '2026-03-27 20:43'
updated_date: '2026-03-28 18:24'
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
- [x] #1 Connect worker distributed mode configuration documented
- [x] #2 Connector types relevant to lab identified
- [x] #3 Connect HA and failover behavior documented
- [x] #4 Integration with Schema Registry for Avro-serialized data documented
- [x] #5 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Kafka Connect Lab Deployment Research**

The doc must cover:

- Worker modes (standalone vs distributed) with lab recommendation
- Relevant connector types for the lab use case
- Decision: Connect for data generation vs FastAPI producer app
- Connect HA and failover behavior
- Integration with Schema Registry for Avro serialization
- VM placement recommendation (dedicated vs co-located with brokers)
- Minimum distributed mode configuration

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
