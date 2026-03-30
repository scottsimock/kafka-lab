---
id: TASK-28.3
title: SP1.003 — User Assigned Managed Identity Module
status: To Do
assignee: []
created_date: '2026-03-30 16:38'
updated_date: '2026-03-30 16:40'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
references:
  - terraform/modules/managed-identity/
documentation:
  - doc-14
parent_task_id: TASK-28
priority: high
ordinal: 1003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/managed-identity/ that provisions a User Assigned Managed Identity (UAMI) using azapi_resource with type Microsoft.ManagedIdentity/userAssignedIdentities. The module accepts name, location, resource_group_id, and tags as inputs. Outputs: uami_id, uami_principal_id, uami_client_id. Create the first UAMI instance for Terraform operations (uami-terraform) in the root module.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module exists at terraform/modules/managed-identity/
- [ ] #2 Module has main.tf, variables.tf, outputs.tf, versions.tf
- [ ] #3 Uses azapi_resource with Microsoft.ManagedIdentity/userAssignedIdentities
- [ ] #4 Outputs uami_id, uami_principal_id, uami_client_id
- [ ] #5 Root module instantiates uami-terraform identity
- [ ] #6 terraform validate passes
<!-- AC:END -->
