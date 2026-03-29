---
name: github-actions-azure
description: Build CI/CD workflows with GitHub Actions for Azure deployments. Use when agents need to create workflows for Terraform plan/apply, Azure login with OIDC, infrastructure deployment, drift detection, or application deployment to Azure.
---

# GitHub Actions for Azure

GitHub Actions automates CI/CD workflows directly from GitHub repositories. For Azure infrastructure deployments, workflows authenticate via OpenID Connect (OIDC) with federated credentials, run Terraform plan/apply cycles, and manage deployment approvals through GitHub Environments.

## Overview

- **Category**: CI/CD / DevOps
- **Key capability**: Automated infrastructure and application deployment to Azure
- **When to use**: Any deployment pipeline requiring Terraform plan/apply, code deployment, or infrastructure drift detection

## Key Concepts

### OIDC Authentication

GitHub Actions authenticates to Azure using OpenID Connect (OIDC) with federated credentials. No client secrets are stored; GitHub's OIDC token is exchanged for an Azure access token at runtime. Requires an Azure AD App Registration with federated credentials configured for the repository.

### GitHub Environments

Environments provide deployment targets with protection rules (required reviewers, wait timers, branch restrictions). Use environments to gate production deployments behind manual approval.

### Workflow Triggers

| Trigger | Use Case |
|---|---|
| `push` to main | Apply infrastructure changes |
| `pull_request` | Run terraform plan and post PR comment |
| `workflow_dispatch` | Manual trigger for on-demand operations |
| `schedule` | Periodic drift detection |

### Terraform State Backend

Terraform state must persist between workflow runs. Store state in an Azure Storage Account with the `azurerm` backend. The storage account should be provisioned separately from the main infrastructure.

## Quick Start

See [getting-started/terraform-deploy.yml](sample_codes/getting-started/terraform-deploy.yml) for a complete Terraform plan/apply workflow.

## Common Patterns

### Terraform Plan on PR + Apply on Merge

See [common-patterns/terraform-ci-cd.yml](sample_codes/common-patterns/terraform-ci-cd.yml).

### Drift Detection on Schedule

See [common-patterns/drift-detection.yml](sample_codes/common-patterns/drift-detection.yml).

## Required GitHub Secrets

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | App Registration client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |

These are set on the GitHub Environment (not repository-level) for environment-scoped access.

## Key Actions

| Action | Purpose | Version |
|---|---|---|
| `azure/login` | Authenticate to Azure via OIDC | `v2` |
| `hashicorp/setup-terraform` | Install Terraform CLI | `v3` |
| `actions/checkout` | Clone repository | `v4` |
| `actions/upload-artifact` | Store plan files between jobs | `v4` |
| `actions/download-artifact` | Retrieve plan files | `v4` |

## Workflow Structure

```yaml
name: Infrastructure Deployment
on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

permissions:
  id-token: write    # Required for OIDC
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    steps: [...]

  apply:
    needs: plan
    if: github.ref == 'refs/heads/main'
    environment: production
    runs-on: ubuntu-latest
    steps: [...]
```

## Best Practices

- **Do**: Use OIDC authentication (no stored secrets)
- **Do**: Separate plan and apply into distinct jobs
- **Do**: Require environment approval for production apply
- **Do**: Pin action versions to full SHA for security
- **Do**: Store Terraform plan as artifact between plan and apply jobs
- **Do**: Use `paths` filter to trigger only on relevant file changes
- **Avoid**: Running `terraform apply` without a saved plan file
- **Avoid**: Storing Azure credentials as repository secrets (use OIDC)
- **Avoid**: Auto-applying without human review for production

## Troubleshooting

| Issue | Solution |
|---|---|
| OIDC token exchange fails | Verify federated credential entity type matches (Environment, Branch, or PR) |
| Terraform state lock | Check for orphaned locks in the storage account; use `terraform force-unlock` |
| Plan shows unexpected changes | Run drift detection to identify out-of-band changes |
| Permissions error on PR comment | Ensure `pull-requests: write` in workflow permissions |

For more issues: `microsoft_docs_search(query="github actions azure troubleshoot {symptom}")`

## Learn More

| Topic | How to Find |
|---|---|
| Azure login action | `microsoft_docs_search(query="github actions azure login OIDC federated credentials")` |
| Terraform on GitHub Actions | `microsoft_docs_fetch(url="https://learn.microsoft.com/devops/deliver/iac-github-actions")` |
| GitHub Environments | `microsoft_docs_search(query="github actions environments protection rules")` |
| Azure OIDC setup | `microsoft_docs_search(query="azure developer github connect openid connect")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
