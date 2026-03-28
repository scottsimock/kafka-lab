---
id: TASK-1.3
title: 'Research: Confluent Schema Registry — Multi-DC Deployment'
status: Done
assignee: []
created_date: '2026-03-27 20:43'
updated_date: '2026-03-28 18:23'
labels:
  - research
  - confluent
  - schema-registry
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/schema-registry/index.html'
  - 'https://docs.confluent.io/platform/current/schema-registry/multidc.html'
parent_task_id: TASK-1
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Confluent Schema Registry for multi-datacenter deployment, focusing on how it integrates with the 2-active-cluster topology.

## Goals
- Understand Schema Registry architecture and HA options
- Research multi-DC Schema Registry deployment patterns (primary/secondary, active-active)
- Understand schema compatibility modes and their impact on producers/consumers during failover
- Understand how Python FastAPI clients integrate with Schema Registry (Avro/Protobuf/JSON serialization)

## Key Questions
- Should Schema Registry be deployed once (centrally) or per cluster?
- How does Schema Registry handle failover when the primary cluster goes down?
- What serialization format is most appropriate for the lab (Avro recommended)?
- How do Python producers/consumers register and retrieve schemas?

## Primary References (from README)
- https://docs.confluent.io/platform/current/schema-registry/index.html
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Multi-DC Schema Registry deployment options documented (primary/secondary)
- [x] #2 Schema compatibility modes and their effect on failover documented
- [x] #3 Schema Registry HA configuration identified
- [x] #4 Integration with Kafka clients (Python) documented
- [x] #5 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Schema Registry Multi-DC Deployment Research**

The doc must cover:

- Schema Registry architecture and HA options
- Multi-DC deployment patterns (primary/secondary vs active-active)
- Schema compatibility modes and impact on failover
- Failover behavior when primary cluster goes down
- Recommended serialization format (Avro) and rationale
- Python client integration for schema registration and retrieval

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
