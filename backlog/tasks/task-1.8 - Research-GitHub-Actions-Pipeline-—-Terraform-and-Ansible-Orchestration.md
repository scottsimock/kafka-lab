---
id: TASK-1.8
title: 'Research: GitHub Actions Pipeline — Terraform and Ansible Orchestration'
status: To Do
assignee: []
created_date: '2026-03-27 20:44'
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
- [ ] #1 GitHub Actions workflow structure for Terraform + Ansible pipeline designed
- [ ] #2 Azure OIDC/UAMI authentication from GitHub Actions documented
- [ ] #3 Secret and variable management strategy (GitHub Secrets vs Key Vault) documented
- [ ] #4 Stage gates between Terraform and Ansible runs defined
- [ ] #5 Workflow trigger strategy (push, manual, scheduled) outlined
<!-- AC:END -->
