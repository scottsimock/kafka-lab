---
id: TASK-33.1
title: SP6.008 — Environment-Specific Configurations
status: Done
assignee:
  - Zorg
created_date: '2026-03-30 16:47'
updated_date: '2026-03-31 21:20'
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
- [x] #1 terraform.dev.tfvars created with dev environment values
- [x] #2 terraform.prod.tfvars created with production environment values
- [x] #3 Ansible group_vars/env_dev.yml and group_vars/env_production.yml created
- [x] #4 Environment-specific Next.js .env files documented
- [x] #5 README documents how to switch between environments
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Zorg] 2025-07-17
- Created `terraform.dev.tfvars` and `terraform.prod.tfvars` with env-specific values (secrets left empty for CI/CD injection)
- Created `env_dev.yml` (low-resource: 2g heap, replication=1, features off) and `env_production.yml` (full: 6g heap, replication=3, all features on)
- Created `docs/ci-cd/environment-configs.md` covering Terraform tfvars usage, Ansible group_vars layering, and Next.js env files
- Updated `.gitignore` to track non-secret tfvars files
- Commit: 19b2de6

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 93%**
- AC: 5/5 met
- tfvars: dev and prod with appropriate values, secrets left empty with comments
- Ansible group_vars: well-differentiated (dev: 2g heap, repl=1, features off; prod: 6g heap, repl=3, features on)
- environment-configs.md: comprehensive doc covering Terraform, Ansible, and Next.js env layers
- Info: Both tfvars in `terraform/environments/dev/` — prod tfvars should move to `terraform/environments/prod/` when that directory is created
- Info: Next.js env files are documented but not created — AC says 'documented' which is satisfied
<!-- SECTION:NOTES:END -->
