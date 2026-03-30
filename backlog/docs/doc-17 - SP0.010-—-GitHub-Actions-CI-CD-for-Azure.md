---
id: doc-17
title: SP0.010 — GitHub Actions CI/CD for Azure
type: other
created_date: '2026-03-30 16:09'
---
## Executive Summary

This document defines the GitHub Actions CI/CD strategy for the Kafka Lab project. All Azure deployments follow a unified, one-click pipeline: **Terraform → Ansible → Application**. Authentication is exclusively via OpenID Connect (OIDC) with User-Assigned Managed Identities (UAMI) — no long-lived service principal secrets are stored anywhere.

The pipeline is structured around:

- **Reusable workflows** (`workflow_call`) for Terraform, Ansible, and application deployment phases, promoting DRY composition.
- **`workflow_dispatch`** for manual, one-click deployments with environment and component selection inputs.
- **GitHub Environments** (dev, staging, prod) with protection rules (required reviewers, wait timers, branch restrictions) as the primary approval gate for production changes.
- **OIDC federated credentials** on dedicated UAMIs — one per workflow — exchanged at runtime for short-lived Azure access tokens.
- **Drift detection** via a nightly scheduled workflow that detects and reports Terraform state drift without applying changes.

This strategy achieves elite-tier DORA metrics targets: high deployment frequency, low lead time, low change failure rate, and fast MTTR through automated rollback and observability instrumentation.

---

## OIDC Authentication Setup

### Overview

OIDC eliminates long-lived credentials. GitHub's OIDC provider issues a short-lived JWT at workflow runtime. Azure validates this JWT against a pre-configured **federated credential trust** and issues a scoped access token. The exchange is transparent to the workflow author — no secrets rotation, no credential sprawl.

### Authentication Options

Microsoft supports two federation targets:

| Option | When to Use |
|---|---|
| Entra ID App Registration + Service Principal | Cross-tenant or complex permission scenarios |
| **User-Assigned Managed Identity (UAMI)** | **Preferred for this project** — one UAMI per workflow, least-privilege RBAC |

The project mandates UAMI per workflow (see `azure-environment.instructions.md`).

### Setup Steps

#### 1. Create a UAMI per workflow

For each workflow (e.g., `terraform-deploy`, `ansible-config`, `app-deploy`), create a dedicated UAMI:

```bash
az identity create \
  --name "uami-gha-terraform-deploy" \
  --resource-group "klc-rg-kafkalab-scus" \
  --location "southcentralus"
```

Capture `clientId`, `tenantId`, and the subscription ID for use as GitHub secrets.

#### 2. Assign RBAC roles (least privilege)

```bash
# Terraform UAMI: Contributor on resource group + Storage Blob Data Contributor for state
az role assignment create \
  --assignee "<uami-client-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/klc-rg-kafkalab-scus"

az role assignment create \
  --assignee "<uami-client-id>" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Storage/storageAccounts/<tfstate-sa>"
```

#### 3. Configure federated credentials on the UAMI

Navigate to **Azure Portal → Managed Identities → `uami-gha-terraform-deploy` → Federated credentials → Add credential**.

Select **GitHub Actions deploying Azure resources** and configure one credential per subject scope:

| Subject | Purpose |
|---|---|
| `repo:org/kafka-lab:environment:prod` | Production deployment jobs |
| `repo:org/kafka-lab:environment:staging` | Staging deployment jobs |
| `repo:org/kafka-lab:environment:dev` | Dev deployment jobs |
| `repo:org/kafka-lab:ref:refs/heads/main` | Drift detection on main |

The **audience** must be `api://AzureADTokenExchange` (default for `azure/login`).

> **Security rule:** Never create a wildcard subject (`repo:org/kafka-lab:*`). Restrict each credential to the minimum subject scope required.

#### 4. Create GitHub secrets

In **Repository Settings → Secrets and Variables → Actions**, create environment-scoped secrets (not repository-level) for each deployment environment:

| Secret Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | UAMI Client ID |
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |

For public repositories or high-security requirements, scope these secrets to the specific GitHub Environment (e.g., `prod`) so they are only accessible after approval gates pass.

#### 5. Workflow permissions

Every job that uses OIDC must declare:

```yaml
permissions:
  id-token: write   # Required to fetch the OIDC token
  contents: read    # Required to checkout code
```

The `id-token: write` permission does not grant write access to repository contents. It only allows the job to request an OIDC token for external service authentication.

#### 6. Azure login step

```yaml
- name: Azure login
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

## Workflow Structure

### Job Dependency Graph

```
workflow_dispatch (manual trigger)
        │
        ▼
┌───────────────┐
│  terraform    │  Init → Plan (PR comment) → Apply (approval gate)
└──────┬────────┘
       │ needs: terraform
       ▼
┌───────────────┐
│    ansible    │  Dynamic inventory → Playbook execution
└──────┬────────┘
       │ needs: ansible
       ▼
┌───────────────┐
│  app-deploy   │  Next.js build + Function App deploy
└───────────────┘
```

Each phase can be selected independently via `workflow_dispatch` inputs. The default (`all`) runs the full chain.

### Reusable Workflows

Reusable workflows live under `.github/workflows/` and use `on: workflow_call:`. Caller workflows invoke them at the **job level** (not step level):

```
.github/workflows/
├── deploy.yml              # Main orchestrator (workflow_dispatch)
├── terraform.yml           # Reusable: terraform init/plan/apply
├── ansible.yml             # Reusable: ansible playbook execution
├── app-deploy.yml          # Reusable: Next.js + Function App deploy
└── drift-detection.yml     # Scheduled: nightly terraform drift check
```

#### Reusable workflow signature example (`terraform.yml`):

```yaml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string        # dev | staging | prod
      working_directory:
        required: false
        type: string
        default: terraform/
      action:
        required: true
        type: string        # plan | apply
    secrets:
      AZURE_CLIENT_ID:
        required: true
      AZURE_TENANT_ID:
        required: true
      AZURE_SUBSCRIPTION_ID:
        required: true
```

### Matrix Strategy

For multi-region deployments, use a matrix to fan out jobs:

```yaml
strategy:
  matrix:
    region: [southcentralus, mexicocentral]
  fail-fast: false
```

`fail-fast: false` ensures a failure in one region does not cancel other regions mid-flight.

### Environment Keys on Jobs

The `environment:` key on a job is the bridge to GitHub's protection rules and environment-scoped secrets:

```yaml
jobs:
  apply:
    runs-on: ubuntu-latest
    environment:
      name: ${{ inputs.environment }}
      url: https://portal.azure.com/#resource/subscriptions/${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

## Terraform Jobs

### Action Versions

- `hashicorp/setup-terraform@v3` — installs Terraform CLI
- `actions/cache@v4` — caches provider plugins

### Environment Variables for OIDC

Terraform's AzureRM provider and AzAPI provider support OIDC natively. Set these env vars at the job level:

```yaml
env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_USE_OIDC: "true"
  ARM_USE_AZUREAD: "true"   # Required for AzureAD-based backend auth
```

No `ARM_CLIENT_SECRET` is set — the OIDC token is exchanged transparently.

### Terraform Backend (Azure Blob Storage with OIDC)

```hcl
terraform {
  backend "azurerm" {
    use_oidc             = true
    resource_group_name  = "klc-rg-kafkalab-scus"
    storage_account_name = "klctfstatestoragescus"
    container_name       = "tfstate"
    key                  = "kafka-lab/${environment}.tfstate"
  }
}
```

### Plan Job with PR Comment

```yaml
- name: Terraform plan
  id: plan
  run: terraform plan -no-color -out=tfplan 2>&1 | tee plan-output.txt
  working-directory: ${{ inputs.working_directory }}
  continue-on-error: true

- name: Post plan as PR comment
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      const fs = require('fs');
      const plan = fs.readFileSync('${{ inputs.working_directory }}plan-output.txt', 'utf8');
      const truncated = plan.length > 60000 ? plan.substring(0, 60000) + '\n...[truncated]' : plan;
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## Terraform Plan — \`${{ inputs.environment }}\`\n\`\`\`\n${truncated}\n\`\`\``
      });
```

### Apply Job (with Approval Gate)

The `environment:` key on the apply job enforces the protection rules configured in GitHub. The job waits for approval before proceeding:

```yaml
apply:
  needs: plan
  runs-on: ubuntu-latest
  environment: ${{ inputs.environment }}   # Protection rules enforced here
  steps:
    - name: Terraform apply
      run: terraform apply -auto-approve tfplan
      working-directory: ${{ inputs.working_directory }}
```

### Drift Detection (Nightly Schedule)

`terraform plan -detailed-exitcode` returns:
- `0` — no changes (no drift)
- `1` — error
- `2` — changes detected (drift)

```yaml
name: Terraform Drift Detection
on:
  schedule:
    - cron: '0 3 * * *'   # Nightly at 03:00 UTC

jobs:
  drift:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      issues: write
    environment: prod
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_USE_OIDC: "true"
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform init
        run: terraform init
        working-directory: terraform/
      - name: Terraform plan (drift check)
        id: drift
        run: |
          terraform plan -detailed-exitcode -no-color -out=tfplan 2>&1 | tee drift-output.txt
          echo "exit_code=${PIPESTATUS[0]}" >> $GITHUB_OUTPUT
        working-directory: terraform/
        continue-on-error: true
      - name: Open GitHub issue on drift
        if: steps.drift.outputs.exit_code == '2'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const output = fs.readFileSync('terraform/drift-output.txt', 'utf8');
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🚨 Terraform drift detected — ' + new Date().toISOString().split('T')[0],
              body: `Nightly drift check detected configuration drift.\n\n\`\`\`\n${output.substring(0, 10000)}\n\`\`\``
            });
```

---

## Ansible Jobs

### Runner Requirements

Ansible dynamic inventory with UAMI requires a **self-hosted runner** running on an Azure VM with the UAMI attached. GitHub-hosted runners do not support Azure MSI (they run outside Azure and have no VM identity context).

```yaml
runs-on: [self-hosted, linux, azure, ansible]
```

The self-hosted runner VM must have:
- The Ansible UAMI assigned (`uami-gha-ansible-config`)
- RBAC: `Reader` on the resource group for inventory queries
- SSH access to target VMs (SSH key retrieved from Key Vault at runtime)

### Dynamic Inventory Configuration (`azure_rm.yml`)

```yaml
plugin: azure.azcollection.azure_rm
include_vm_resource_groups:
  - klc-rg-kafkalab-scus
auth_source: msi
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: tags.Environment
    prefix: env
filters:
  tag:Environment: "{{ lookup('env', 'TARGET_ENV') }}"
```

`auth_source: msi` instructs the Azure SDK to use the VM's managed identity. For UAMI, set `AZURE_CLIENT_ID` to the UAMI's client ID.

### Workflow Job

```yaml
ansible:
  needs: terraform
  runs-on: [self-hosted, linux, azure, ansible]
  environment: ${{ inputs.environment }}
  env:
    AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    AZURE_USE_MSI: "true"
    TARGET_ENV: ${{ inputs.environment }}
  steps:
    - uses: actions/checkout@v4

    - name: Install Ansible Azure collection
      run: |
        pip3 install --upgrade pip
        pip3 install ansible azure-identity
        ansible-galaxy collection install azure.azcollection --force

    - name: Retrieve SSH key from Key Vault
      run: |
        SSH_KEY=$(az keyvault secret show \
          --vault-name "klc-kv-kafkalab-scus" \
          --name "ansible-ssh-private-key" \
          --query value -o tsv)
        echo "::add-mask::$SSH_KEY"
        echo "$SSH_KEY" > ~/.ssh/ansible_id_rsa
        chmod 600 ~/.ssh/ansible_id_rsa

    - name: Run Ansible playbook
      run: |
        ansible-playbook \
          -i ansible/inventory/azure_rm.yml \
          ansible/site.yml \
          --private-key ~/.ssh/ansible_id_rsa \
          --extra-vars "env=${{ inputs.environment }}"

    - name: Clean up SSH key
      if: always()
      run: rm -f ~/.ssh/ansible_id_rsa
```

### Ansible Vault Integration

Ansible Vault encrypts secrets within Ansible roles. The vault password is stored in Azure Key Vault and retrieved at runtime:

```yaml
- name: Retrieve Ansible Vault password
  run: |
    VAULT_PASS=$(az keyvault secret show \
      --vault-name "klc-kv-kafkalab-scus" \
      --name "ansible-vault-password" \
      --query value -o tsv)
    echo "::add-mask::$VAULT_PASS"
    echo "$VAULT_PASS" > ~/.vault_pass
    chmod 600 ~/.vault_pass

- name: Run Ansible playbook with vault
  run: |
    ansible-playbook \
      -i ansible/inventory/azure_rm.yml \
      ansible/site.yml \
      --vault-password-file ~/.vault_pass

- name: Clean up vault password file
  if: always()
  run: rm -f ~/.vault_pass
```

---

## Application Deployment Jobs

### Next.js Web Application

The Next.js app is deployed to Azure Static Web Apps using `Azure/static-web-apps-deploy@v1`, or to Azure App Service using `azure/webapps-deploy@v3` for SSR workloads. For the Kafka Lab management UI (App Service with SSR):

```yaml
app-deploy:
  needs: ansible
  runs-on: ubuntu-latest
  environment: ${{ inputs.environment }}
  permissions:
    id-token: write
    contents: read
  steps:
    - uses: actions/checkout@v4

    - name: Set up Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: app/package-lock.json

    - name: Install dependencies
      run: npm ci
      working-directory: app/

    - name: Build Next.js app
      run: npm run build
      working-directory: app/
      env:
        NODE_ENV: production
        NEXT_PUBLIC_ENV: ${{ inputs.environment }}

    - name: Azure login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Deploy to Azure App Service
      uses: azure/webapps-deploy@v3
      with:
        app-name: "klc-app-kafkalab-${{ inputs.environment }}-scus"
        package: app/
```

For **static export** to Azure Static Web Apps:

```yaml
    - name: Deploy to Azure Static Web Apps
      uses: Azure/static-web-apps-deploy@v1
      with:
        azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
        repo_token: ${{ secrets.GITHUB_TOKEN }}
        action: "upload"
        app_location: "app/"
        output_location: "out"
```

### Azure Function App Deployment

Python Azure Functions are deployed using `azure/functions-action@v1`. OIDC authentication from the preceding `azure/login` step is inherited:

```yaml
    - name: Deploy Azure Functions
      uses: azure/functions-action@v1
      with:
        app-name: "klc-func-kafkalab-${{ inputs.environment }}-scus"
        package: functions/
        scm-do-build-during-deployment: true
        enable-oryx-build: true
```

`scm-do-build-during-deployment: true` triggers server-side pip install, avoiding the need to bundle dependencies in the package.

---

## workflow_dispatch Configuration

The main orchestrator workflow (`deploy.yml`) exposes a `workflow_dispatch` trigger with structured inputs for one-click deployment:

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target deployment environment'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod
        default: dev
      component:
        description: 'Component(s) to deploy'
        required: true
        type: choice
        options:
          - all
          - terraform
          - ansible
          - app
        default: all
      terraform_action:
        description: 'Terraform action (only applies if component includes terraform)'
        required: false
        type: choice
        options:
          - plan
          - apply
        default: plan
      dry_run:
        description: 'Dry run — plan only, no apply or deploy'
        required: false
        type: boolean
        default: false
```

#### Using inputs in job conditions:

```yaml
jobs:
  terraform:
    if: inputs.component == 'all' || inputs.component == 'terraform'
    uses: ./.github/workflows/terraform.yml
    with:
      environment: ${{ inputs.environment }}
      action: ${{ inputs.dry_run && 'plan' || inputs.terraform_action }}
    secrets: inherit

  ansible:
    needs: terraform
    if: |
      always() &&
      !failure() &&
      (inputs.component == 'all' || inputs.component == 'ansible')
    uses: ./.github/workflows/ansible.yml
    with:
      environment: ${{ inputs.environment }}
    secrets: inherit

  app-deploy:
    needs: ansible
    if: |
      always() &&
      !failure() &&
      (inputs.component == 'all' || inputs.component == 'app') &&
      !inputs.dry_run
    uses: ./.github/workflows/app-deploy.yml
    with:
      environment: ${{ inputs.environment }}
    secrets: inherit
```

`secrets: inherit` passes all repository and environment secrets from the caller to the called workflow without explicitly enumerating them.

---

## Secrets Management

### Secret Categories

| Category | Storage Location | Rotation |
|---|---|---|
| OIDC identity (Client ID, Tenant ID, Sub ID) | GitHub environment secrets | On UAMI recreation |
| Key Vault name | GitHub environment secrets | Rarely |
| Application secrets (DB passwords, API keys, etc.) | Azure Key Vault | Per policy |
| Ansible SSH private key | Azure Key Vault | Quarterly |
| Ansible Vault password | Azure Key Vault | Quarterly |
| Terraform state storage access | OIDC (no secret) | N/A |

### GitHub Secrets for OIDC

Only three non-sensitive identifiers are stored as GitHub secrets. These are not secrets in the traditional sense (no credential value is stored), but GitHub's secrets store provides audit trails and prevents them appearing in logs:

```
AZURE_CLIENT_ID         → UAMI Client ID
AZURE_TENANT_ID         → Entra Directory ID
AZURE_SUBSCRIPTION_ID   → Azure Subscription ID
KEYVAULT_NAME           → Key Vault resource name
```

### Retrieving Secrets from Azure Key Vault

The `azure/get-keyvault-secrets` action is archived and should not be used. Use `azure/CLI@v2` instead:

```yaml
- name: Retrieve secrets from Key Vault
  uses: azure/CLI@v2
  with:
    inlineScript: |
      DB_PASSWORD=$(az keyvault secret show \
        --vault-name "${{ secrets.KEYVAULT_NAME }}" \
        --name "kafka-db-password" \
        --query value -o tsv)
      echo "::add-mask::$DB_PASSWORD"
      echo "DB_PASSWORD=$DB_PASSWORD" >> $GITHUB_ENV

      KAFKA_API_KEY=$(az keyvault secret show \
        --vault-name "${{ secrets.KEYVAULT_NAME }}" \
        --name "kafka-api-key" \
        --query value -o tsv)
      echo "::add-mask::$KAFKA_API_KEY"
      echo "KAFKA_API_KEY=$KAFKA_API_KEY" >> $GITHUB_ENV
```

**Critical rules:**
- Always call `echo "::add-mask::<value>"` immediately after retrieving a secret. This prevents the value from appearing in any subsequent log output.
- Never echo secrets to stdout directly.
- Use `$GITHUB_ENV` to pass secrets between steps (not `$GITHUB_OUTPUT`, which can be logged).
- The Key Vault access policy must grant the UAMI `Key Vault Secrets User` RBAC role.

### OIDC Token Lifecycle

The OIDC token is a short-lived JWT (valid for ~10 minutes) issued by GitHub's OIDC provider. The `azure/login` action exchanges it for an Azure access token. No token material is ever written to disk or persisted in GitHub secrets.

---

## Environment Protection Rules

GitHub Environments gate deployments through configurable protection rules. Access **Repository Settings → Environments** to configure.

### Environment Matrix

| Environment | Branches Allowed | Required Reviewers | Wait Timer | Auto-Deploy |
|---|---|---|---|---|
| `dev` | Any branch | None | None | On push to `develop` |
| `staging` | `main`, `release/*` | 1 reviewer | None | On merge to `main` |
| `prod` | `main` only | 2 reviewers (min 1 from ops team) | 15 minutes | Never (manual only) |

### Configuration Details

#### `dev` environment

- **Purpose:** Rapid iteration and feature validation
- **Branch restriction:** None (any branch can deploy to dev)
- **Reviewers:** None
- **Secrets:** Lower-privilege UAMI with dev resource group scope only

#### `staging` environment

- **Purpose:** Pre-production validation, integration testing
- **Branch restriction:** `main` and `release/*` branches only
- **Reviewers:** 1 required (team member)
- **Secrets:** Staging-scoped UAMI — separate from prod UAMI

#### `prod` environment

- **Purpose:** Live production traffic
- **Branch restriction:** `main` only
- **Reviewers:** 2 required (at least 1 from the ops team group)
- **Wait timer:** 15 minutes — allows last-minute cancellation after approval
- **Secrets:** Prod-scoped UAMI with narrowest possible RBAC scope
- **Prevent self-review:** Enabled — the workflow author cannot approve their own deployment

### Using Environments in Workflows

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment:
      name: prod
      url: https://kafka-lab.example.com   # Shown on the deployment status page
    steps:
      # ... deployment steps
```

When the job reaches the `environment:` declaration, GitHub enforces all configured protection rules before the job proceeds. The workflow pauses waiting for the required approvals and wait timer expiry.

### Branch Protection Rules (complementary)

In addition to environment protection, configure branch protection on `main`:

- Require pull request before merging
- Require at least 1 approving review
- Dismiss stale reviews on new commits
- Require status checks to pass (Terraform plan, lint, tests)
- Restrict who can push to `main` (protected list)

---

## Example Workflow YAML

Complete main deployment orchestrator (`.github/workflows/deploy.yml`):

```yaml
name: Deploy Kafka Lab

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, staging, prod]
        default: dev
      component:
        description: 'Component to deploy'
        required: true
        type: choice
        options: [all, terraform, ansible, app]
        default: all
      terraform_action:
        description: 'Terraform action'
        required: false
        type: choice
        options: [plan, apply]
        default: plan
      dry_run:
        description: 'Dry run (no apply/deploy)'
        required: false
        type: boolean
        default: false

  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'ansible/**'
      - 'app/**'
      - 'functions/**'

concurrency:
  group: deploy-${{ inputs.environment || 'dev' }}
  cancel-in-progress: false   # Never cancel in-flight deploys

jobs:
  # ─────────────────────────────────────────────
  # Phase 1: Terraform
  # ─────────────────────────────────────────────
  terraform:
    if: |
      inputs.component == 'all' || inputs.component == 'terraform' ||
      github.event_name == 'pull_request'
    uses: ./.github/workflows/terraform.yml
    with:
      environment: ${{ inputs.environment || 'dev' }}
      working_directory: terraform/
      action: ${{ (inputs.dry_run || github.event_name == 'pull_request') && 'plan' || inputs.terraform_action }}
    secrets: inherit

  # ─────────────────────────────────────────────
  # Phase 2: Ansible
  # ─────────────────────────────────────────────
  ansible:
    needs: terraform
    if: |
      always() && !failure() && !cancelled() &&
      github.event_name != 'pull_request' &&
      (inputs.component == 'all' || inputs.component == 'ansible')
    uses: ./.github/workflows/ansible.yml
    with:
      environment: ${{ inputs.environment }}
    secrets: inherit

  # ─────────────────────────────────────────────
  # Phase 3: Application Deployment
  # ─────────────────────────────────────────────
  app-deploy:
    needs: ansible
    if: |
      always() && !failure() && !cancelled() &&
      github.event_name != 'pull_request' &&
      (inputs.component == 'all' || inputs.component == 'app') &&
      !inputs.dry_run
    uses: ./.github/workflows/app-deploy.yml
    with:
      environment: ${{ inputs.environment }}
    secrets: inherit
```

Companion reusable Terraform workflow (`.github/workflows/terraform.yml`):

```yaml
name: Terraform

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      working_directory:
        required: false
        type: string
        default: terraform/
      action:
        required: true
        type: string
    secrets:
      AZURE_CLIENT_ID:
        required: true
      AZURE_TENANT_ID:
        required: true
      AZURE_SUBSCRIPTION_ID:
        required: true

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_USE_OIDC: "true"
      ARM_USE_AZUREAD: "true"
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform format check
        run: terraform fmt -check -recursive
        working-directory: ${{ inputs.working_directory }}

      - name: Terraform init
        run: terraform init -input=false
        working-directory: ${{ inputs.working_directory }}

      - name: Terraform validate
        run: terraform validate
        working-directory: ${{ inputs.working_directory }}

      - name: Terraform plan
        id: plan
        run: terraform plan -no-color -input=false -out=tfplan 2>&1 | tee plan-output.txt
        working-directory: ${{ inputs.working_directory }}
        continue-on-error: true

      - name: Post plan comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const output = fs.readFileSync('${{ inputs.working_directory }}plan-output.txt', 'utf8');
            const truncated = output.length > 60000
              ? output.substring(0, 60000) + '\n...[output truncated — see workflow logs for full plan]'
              : output;
            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## 🏗️ Terraform Plan — \`${{ inputs.environment }}\`\n\`\`\`hcl\n${truncated}\n\`\`\``
            });

      - name: Fail on plan error
        if: steps.plan.outcome == 'failure'
        run: exit 1

      - name: Terraform apply
        if: inputs.action == 'apply'
        run: terraform apply -auto-approve -input=false tfplan
        working-directory: ${{ inputs.working_directory }}
```

---

## References

| Title | URL |
|---|---|
| Configuring OpenID Connect in Azure — GitHub Docs | <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure> |
| Authenticate to Azure from GitHub Actions by OpenID Connect — Microsoft Learn | <https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect> |
| GitHub Actions for Azure — Microsoft Learn | <https://learn.microsoft.com/en-us/azure/developer/github/github-actions> |
| Use Azure Key Vault secrets in a GitHub Actions workflow | <https://learn.microsoft.com/en-us/azure/developer/github/github-actions-key-vault> |
| Reuse workflows — GitHub Docs | <https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows> |
| Managing environments for deployment — GitHub Docs | <https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment> |
| Automate Terraform with GitHub Actions — HashiCorp Developer | <https://developer.hashicorp.com/terraform/tutorials/automation/github-actions> |
| azure/login action | <https://github.com/Azure/login> |
| azure/functions-action | <https://github.com/Azure/functions-action> |
| Azure/static-web-apps-deploy | <https://github.com/Azure/static-web-apps-deploy> |
| azure.azcollection.azure_rm inventory — Ansible Docs | <https://docs.ansible.com/projects/ansible/latest/collections/azure/azcollection/azure_rm_inventory.html> |
| Configure Ansible to use Managed Identity with Azure Dynamic Inventory | <https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/configure-ansible-to-use-a-managed-identity-with-azure-dynamic-inventory/1062449> |
| Configure dynamic inventories for Azure VMs — Microsoft Learn | <https://learn.microsoft.com/en-us/azure/developer/ansible/dynamic-inventory-configure> |
| Azure-Samples/terraform-github-actions (reference implementation) | <https://github.com/Azure-Samples/terraform-github-actions> |
| Workload identity federation — Microsoft Entra | <https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation> |
