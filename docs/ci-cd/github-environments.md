# GitHub Environments and Protection Rules

This document describes the GitHub Environment configuration for the kafka-lab repository, including protection rules, UAMI (User-Assigned Managed Identity) setup, federated credentials for OIDC authentication, and environment-scoped secrets.

## Environment Overview

The repository uses three GitHub Environments to gate deployments through progressively stricter controls.

| Environment | Branches Allowed | Required Reviewers | Wait Timer | Auto-Deploy |
|---|---|---|---|---|
| `dev` | Any branch | None | None | On push to `develop` |
| `staging` | `main`, `release/*` | 1 reviewer | None | On merge to `main` |
| `prod` | `main` only | 2 reviewers (min 1 from ops team) | 15 minutes | Never (manual only) |

### Design Principles

- **No long-lived secrets** — all Azure authentication uses OIDC with short-lived tokens.
- **Least-privilege per workflow** — each workflow gets its own UAMI with only the RBAC roles it needs.
- **Environment-scoped secrets** — secrets are set per environment, not at repository level, so `dev` credentials cannot access `prod` resources.
- **Progressive gating** — `dev` auto-deploys for fast iteration, `staging` requires one approval, `prod` requires two approvals plus a wait timer.

## Setup Instructions

GitHub Environments are configured through the repository settings UI. These steps require repository admin access.

### Step 1 — Create Environments

1. Navigate to **Settings → Environments** in the kafka-lab repository.
2. Click **New environment** for each of the three environments: `dev`, `staging`, `prod`.

### Step 2 — Configure dev Environment

The `dev` environment has no protection rules and allows auto-deployment.

1. Open the `dev` environment.
2. Under **Deployment branches and tags**, select **All branches**.
3. Leave **Required reviewers** unchecked.
4. Leave **Wait timer** empty.
5. Click **Save protection rules**.

### Step 3 — Configure staging Environment

1. Open the `staging` environment.
2. Under **Required reviewers**, check the box and add **1 reviewer** (a team lead or senior engineer).
3. Under **Deployment branches and tags**, select **Selected branches and tags**, then add:
   - `main`
   - `release/*`
4. Leave **Wait timer** empty.
5. Click **Save protection rules**.

### Step 4 — Configure prod Environment

1. Open the `prod` environment.
2. Under **Required reviewers**, check the box and add **2 reviewers**. At least one must be from the ops team.
3. Under **Wait timer**, set to **15 minutes**.
4. Under **Deployment branches and tags**, select **Selected branches and tags**, then add:
   - `main`
5. Click **Save protection rules**.

### Verification

After creating all three environments, the **Settings → Environments** page should list:

| Environment | Protection Rules Summary |
|---|---|
| `dev` | No protection rules · All branches |
| `staging` | 1 required reviewer · `main`, `release/*` |
| `prod` | 2 required reviewers · 15 min wait · `main` only |

## User-Assigned Managed Identity (UAMI) Setup

Each GitHub Actions workflow authenticates to Azure through a dedicated UAMI. This avoids shared credentials and enforces least-privilege access.

### UAMI Matrix

| UAMI Name | Used By | RBAC Roles |
|---|---|---|
| `uami-gha-terraform-deploy` | Terraform plan/apply workflows | Contributor, Storage Blob Data Contributor |
| `uami-gha-ansible-config` | Ansible configuration workflows | Reader (for inventory), SSH access via Key Vault |
| `uami-gha-app-deploy` | Application deployment workflows | Website Contributor on Function App |

### Creating a UAMI

Use the Azure CLI to create each identity in the shared resource group.

```bash
# Set variables
RG="rg-kafkalab-shared-scus"
LOCATION="southcentralus"

# Create the UAMI
az identity create \
  --name uami-gha-terraform-deploy \
  --resource-group "$RG" \
  --location "$LOCATION"
```

Record the output values — you will need `clientId`, `principalId`, and `tenantId`.

### Assigning RBAC Roles

Assign roles scoped to the appropriate resource group or resource.

```bash
# Example: Contributor on the target resource group
UAMI_PRINCIPAL_ID=$(az identity show \
  --name uami-gha-terraform-deploy \
  --resource-group "$RG" \
  --query principalId -o tsv)

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az role assignment create \
  --assignee-object-id "$UAMI_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create \
  --assignee-object-id "$UAMI_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"
```

Repeat for each UAMI with its respective roles:

**uami-gha-ansible-config:**

```bash
az role assignment create \
  --assignee-object-id "$UAMI_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

Grant Key Vault access for SSH key retrieval:

```bash
az keyvault set-policy \
  --name klc-kv-kafkalab-scus \
  --object-id "$UAMI_PRINCIPAL_ID" \
  --secret-permissions get list
```

**uami-gha-app-deploy:**

```bash
az role assignment create \
  --assignee-object-id "$UAMI_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Website Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.Web/sites/<function-app-name>"
```

## Federated Credential Configuration

Federated credentials establish the trust between GitHub Actions OIDC tokens and each UAMI. GitHub issues a JWT at workflow runtime; Azure validates it against the configured subject claim.

### Subject Claims

Each UAMI requires a federated credential for every environment it operates in, plus an additional credential for the `main` branch (used by drift detection).

| UAMI | Subject Claim | Purpose |
|---|---|---|
| `uami-gha-terraform-deploy` | `repo:org/kafka-lab:environment:dev` | Terraform apply to dev |
| `uami-gha-terraform-deploy` | `repo:org/kafka-lab:environment:staging` | Terraform apply to staging |
| `uami-gha-terraform-deploy` | `repo:org/kafka-lab:environment:prod` | Terraform apply to prod |
| `uami-gha-terraform-deploy` | `repo:org/kafka-lab:ref:refs/heads/main` | Drift detection (scheduled) |
| `uami-gha-ansible-config` | `repo:org/kafka-lab:environment:dev` | Ansible config in dev |
| `uami-gha-ansible-config` | `repo:org/kafka-lab:environment:staging` | Ansible config in staging |
| `uami-gha-ansible-config` | `repo:org/kafka-lab:environment:prod` | Ansible config in prod |
| `uami-gha-app-deploy` | `repo:org/kafka-lab:environment:dev` | App deploy to dev |
| `uami-gha-app-deploy` | `repo:org/kafka-lab:environment:staging` | App deploy to staging |
| `uami-gha-app-deploy` | `repo:org/kafka-lab:environment:prod` | App deploy to prod |

### Creating Federated Credentials

```bash
UAMI_NAME="uami-gha-terraform-deploy"
RG="rg-kafkalab-shared-scus"

# Environment-scoped credential (repeat for dev, staging, prod)
az identity federated-credential create \
  --name "github-env-prod" \
  --identity-name "$UAMI_NAME" \
  --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:org/kafka-lab:environment:prod" \
  --audiences "api://AzureADTokenExchange"

# Branch-scoped credential for drift detection
az identity federated-credential create \
  --name "github-ref-main" \
  --identity-name "$UAMI_NAME" \
  --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:org/kafka-lab:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange"
```

Replace `org` with the actual GitHub organization name. The `--subject` value must match exactly — a mismatch causes `AADSTS700024` errors at login time.

### Federated Credential Naming Convention

Use a consistent naming pattern for the `--name` parameter:

| Pattern | Example |
|---|---|
| `github-env-{environment}` | `github-env-prod` |
| `github-ref-{branch}` | `github-ref-main` |

## Secret Configuration

Each environment requires four secrets. These are set in the GitHub UI under **Settings → Environments → {env} → Environment secrets**.

### Secrets Per Environment

| Secret Name | Value Source | Description |
|---|---|---|
| `AZURE_CLIENT_ID` | UAMI `clientId` output | Identifies which managed identity to authenticate as |
| `AZURE_TENANT_ID` | `az account show --query tenantId` | Microsoft Entra ID (Azure AD) tenant |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id` | Target Azure subscription |
| `KEYVAULT_NAME` | `klc-kv-kafkalab-scus` | Key Vault resource name for secret retrieval |

### Setting Secrets via GitHub CLI

```bash
# Set secrets for the dev environment
gh secret set AZURE_CLIENT_ID \
  --env dev \
  --body "<uami-client-id-for-dev>"

gh secret set AZURE_TENANT_ID \
  --env dev \
  --body "<tenant-id>"

gh secret set AZURE_SUBSCRIPTION_ID \
  --env dev \
  --body "<subscription-id>"

gh secret set KEYVAULT_NAME \
  --env dev \
  --body "klc-kv-kafkalab-scus"
```

Repeat for `staging` and `prod`. Each environment may use a different `AZURE_CLIENT_ID` if separate UAMIs are provisioned per environment, or the same UAMI if the federated credential subjects cover all environments.

### Why Environment-Scoped Secrets

Repository-level secrets are accessible to all workflows on all branches. Environment-scoped secrets are only available to jobs that declare `environment: <name>`, which means:

- A workflow running on a feature branch cannot read `prod` secrets.
- The `prod` environment's branch restriction to `main` prevents unauthorized access even if a workflow references `environment: prod`.

## Workflow Usage

Workflows reference environments in job definitions. The `azure/login` action uses OIDC automatically when `id-token: write` permission is set.

```yaml
name: Deploy Infrastructure

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: prod
    env:
      ARM_USE_OIDC: 'true'
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # Deployment steps follow...
```

The `ARM_USE_OIDC` and `ARM_*` environment variables configure the Terraform AzAPI/AzureRM providers to use the same OIDC token without additional authentication blocks.

## Verification Steps

### 1 — Verify Environments Exist

```bash
# List environments (requires admin access)
gh api repos/{owner}/{repo}/environments --jq '.environments[].name'
```

Expected output:

```text
dev
staging
prod
```

### 2 — Verify Protection Rules

```bash
gh api repos/{owner}/{repo}/environments/prod \
  --jq '{
    reviewers: .protection_rules[] | select(.type == "required_reviewers") | .reviewers | length,
    wait_timer: .protection_rules[] | select(.type == "wait_timer") | .wait_timer,
    branch_policy: .deployment_branch_policy
  }'
```

Expected: 2 reviewers, 15-minute wait, branch policy with `main` only.

### 3 — Verify OIDC Login

Create a minimal test workflow:

```yaml
name: Verify OIDC Login
on: workflow_dispatch

permissions:
  id-token: write
  contents: read

jobs:
  test-login:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Confirm identity
        run: az account show --query '{subscription:id, tenant:tenantId, user:user.name}'
```

Trigger with `gh workflow run "Verify OIDC Login"` and confirm the job completes with the expected identity.

### 4 — Verify Federated Credentials

```bash
az identity federated-credential list \
  --identity-name uami-gha-terraform-deploy \
  --resource-group rg-kafkalab-shared-scus \
  --query '[].{name:name, subject:subject}' \
  -o table
```

Confirm each expected subject claim is present.

### 5 — Verify Branch Restrictions

Push a test workflow that references `environment: prod` from a feature branch. The workflow run should be blocked by the branch policy and show a "waiting for deployment review" status that cannot be approved.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `AADSTS700024: Client assertion is not within its valid time range` | Clock skew or expired token | Retry the workflow; check runner time sync |
| `AADSTS70021: No matching federated identity record found` | Subject claim mismatch | Verify the `--subject` value matches exactly (case-sensitive, org name, environment name) |
| `AuthorizationFailed` after successful login | Missing RBAC role assignment | Add the required role to the UAMI's `principalId` |
| Workflow stuck on "Waiting for review" | Environment protection rules active | Approve the deployment in the GitHub UI or verify branch is allowed |
| Secrets not available in workflow | Job missing `environment:` key | Add `environment: <name>` to the job definition |
