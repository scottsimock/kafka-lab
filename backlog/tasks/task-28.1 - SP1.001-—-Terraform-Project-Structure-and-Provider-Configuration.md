---
id: TASK-28.1
title: SP1.001 — Terraform Project Structure and Provider Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:37'
labels:
  - story
milestone: m-1
dependencies: []
references:
  - terraform/
  - terraform/versions.tf
  - terraform/variables.tf
documentation:
  - doc-14
parent_task_id: TASK-28
priority: high
ordinal: 1001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Terraform project directory structure with modules layout. Configure the AzAPI provider in versions.tf with required_version >= 1.6.0, azapi >= 2.0, and random >= 3.6. Create main.tf, variables.tf, outputs.tf, and locals.tf at root level. Define core variables: subscription_id, environment (default "dev"), primary_location (default "southcentralus"), resource_group_name (default "klc-rg-kafkalab-scus").
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 terraform/ directory exists with modules/ subdirectory
- [ ] #2 versions.tf declares azapi >= 2.0 and random >= 3.6 providers
- [ ] #3 main.tf, variables.tf, outputs.tf, locals.tf exist at terraform/ root
- [ ] #4 variables.tf defines subscription_id, environment, primary_location, resource_group_name
- [ ] #5 terraform validate passes with no errors
- [ ] #6 terraform fmt -check passes
<!-- AC:END -->
