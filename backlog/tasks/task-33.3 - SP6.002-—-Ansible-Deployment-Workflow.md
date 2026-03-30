---
id: TASK-33.3
title: SP6.002 — Ansible Deployment Workflow
status: To Do
assignee: []
created_date: '2026-03-30 16:47'
labels:
  - story
milestone: m-6
dependencies: []
references:
  - .github/workflows/ansible-deploy.yml
documentation:
  - doc-17
parent_task_id: TASK-33
priority: high
ordinal: 6002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable GitHub Actions workflow for Ansible deployment. The workflow authenticates via OIDC, installs Ansible with azure.azcollection, and runs the specified playbook with Azure dynamic inventory. Per doc-17.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Reusable workflow at .github/workflows/ansible-deploy.yml
- [ ] #2 Accepts inputs: environment, playbook_path, inventory_path
- [ ] #3 Authenticates via OIDC and configures Azure environment for Ansible
- [ ] #4 Installs Ansible and azure.azcollection collection
- [ ] #5 Runs ansible-playbook with dynamic inventory
- [ ] #6 Captures playbook output as workflow artifact
<!-- AC:END -->
