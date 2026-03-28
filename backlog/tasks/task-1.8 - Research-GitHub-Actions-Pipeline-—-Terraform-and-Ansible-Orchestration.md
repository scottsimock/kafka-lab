---
id: TASK-1.8
title: 'Research: GitHub Actions Pipeline — Terraform and Ansible Orchestration'
status: Done
assignee: []
created_date: '2026-03-27 20:44'
updated_date: '2026-03-28 18:25'
labels:
  - research
  - github-actions
  - terraform
  - ansible
  - ci-cd
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/developer/github/github-actions'
  - >-
    https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview
  - >-
    https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research GitHub Actions pipeline design for orchestrating Terraform infrastructure provisioning followed by Ansible configuration management in Azure.

## Goals
- Understand GitHub Actions workflow structure for a Terraform → Ansible deployment pipeline
- Research Azure authentication from GitHub Actions using OIDC with a UAMI (no long-lived secrets)
- Understand how Terraform outputs (VM IPs, resource IDs) are passed to the Ansible stage
- Research GitHub Actions environment protection rules and deployment gates
- Research self-hosted vs GitHub-hosted runners for Azure deployments

## Key Questions
- How is OIDC federated identity configured between GitHub Actions and Azure UAMI?
- How are Terraform state outputs consumed by the Ansible stage in the same workflow?
- Should runners be GitHub-hosted or self-hosted for this lab?

## Primary References (from README)
- https://learn.microsoft.com/en-us/azure/developer/github/github-actions
- https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GitHub Actions workflow structure for Terraform + Ansible pipeline designed
- [x] #2 Azure OIDC/UAMI authentication from GitHub Actions documented
- [x] #3 Secret and variable management strategy (GitHub Secrets vs Key Vault) documented
- [x] #4 Stage gates between Terraform and Ansible runs defined
- [x] #5 Workflow trigger strategy (push, manual, scheduled) outlined
- [x] #6 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **GitHub Actions Pipeline Research**

The doc must cover:

- Workflow structure for Terraform → Ansible deployment pipeline
- Azure OIDC/UAMI authentication from GitHub Actions
- Terraform output → Ansible variable handoff mechanism
- Secret and variable management (GitHub Secrets vs Key Vault)
- Stage gates between Terraform and Ansible runs
- Workflow trigger strategy (push, manual, scheduled)
- Self-hosted vs GitHub-hosted runner recommendation

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
