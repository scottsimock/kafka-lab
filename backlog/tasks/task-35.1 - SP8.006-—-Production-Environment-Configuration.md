---
id: TASK-35.1
title: SP8.006 — Production Environment Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:51'
labels:
  - story
milestone: m-8
dependencies: []
references:
  - terraform/
documentation:
  - doc-17
parent_task_id: TASK-35
priority: medium
ordinal: 8006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create production environment configuration overlays. Production tfvars with full broker counts, production-grade disk sizes, hardened replication settings, extended retention policies. Lock down Key Vault access policies. Ensure all compliance tags are applied.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Production tfvars with production-grade VM counts and sizes
- [ ] #2 Replication factor=3 and min.insync.replicas=2 enforced
- [ ] #3 Tiered storage retention configured for production retention policy
- [ ] #4 Key Vault access policies locked to production UAMIs only
- [ ] #5 All resources tagged with environment=production
- [ ] #6 Terraform plan shows no drift from production configuration
<!-- AC:END -->
