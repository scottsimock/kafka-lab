---
id: TASK-33.1
title: SP6.008 — Environment-Specific Configurations
status: To Do
assignee: []
created_date: '2026-03-30 16:47'
labels:
  - story
milestone: m-6
dependencies: []
references:
  - terraform/
  - ansible/inventory/group_vars/
documentation:
  - doc-17
parent_task_id: TASK-33
priority: medium
ordinal: 6008
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create environment-specific configuration files for dev and production. Terraform tfvars files with environment-specific values (VM counts, disk sizes, replication factors). Ansible environment group_vars with environment-specific tuning. Next.js environment variable documentation. Per doc-17.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 terraform.dev.tfvars created with dev environment values
- [ ] #2 terraform.prod.tfvars created with production environment values
- [ ] #3 Ansible group_vars/env_dev.yml and group_vars/env_production.yml created
- [ ] #4 Environment-specific Next.js .env files documented
- [ ] #5 README documents how to switch between environments
<!-- AC:END -->
