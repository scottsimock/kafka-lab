---
id: doc-7
title: GitHub Actions Pipeline Research
type: other
created_date: '2026-03-28 18:25'
---
# GitHub Actions Pipeline Research

## Summary

This document captures research findings for designing a GitHub Actions CI/CD pipeline that orchestrates Terraform (AzAPI) infrastructure provisioning followed by Ansible configuration management for the Kafka Lab multi-region Azure deployment. The pipeline authenticates to Azure using OIDC with a User Assigned Managed Identity (no long-lived secrets), passes Terraform outputs (VM IPs, resource IDs) to Ansible via artifacts, and uses environment protection rules to gate promotions across stages. A hybrid runner strategy is recommended: GitHub-hosted runners for Terraform plan/apply with self-hosted runners inside the VNet for Ansible configuration of private VMs.

## Key Findings

### OIDC and Azure UAMI Authentication

- GitHub Actions supports native OIDC token issuance via the `id-token: write` permission. Azure trusts these tokens through **federated identity credentials** configured on a User Assigned Managed Identity.
- The federated credential binds a specific GitHub repository, branch, or environment to the Azure UAMI using three claims: **issuer** (`https://token.actions.githubusercontent.com`), **subject** (e.g., `repo:org/repo:environment:production`), and **audience** (`api://AzureADTokenExchange`).
- The `azure/login@v2` action handles the OIDC token exchange transparently. Terraform consumes the identity via `ARM_USE_OIDC=true` plus `ARM_CLIENT_ID`, `ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID` environment variables.
- The AzureRM backend for Terraform state also supports OIDC natively with `use_oidc = true` in the backend configuration block.
- **No client secrets or certificates are stored in GitHub.** Only the UAMI client ID, tenant ID, and subscription ID (non-sensitive identifiers) are stored as GitHub Secrets or environment variables.
- Fine-grained subject claims should scope each federated credential to a specific environment (e.g., `repo:kafka-lab/infra:environment:production`) to prevent unauthorized workflows from assuming the identity.

### Terraform-to-Ansible Handoff

- Terraform outputs (VM private IPs, resource IDs, SSH key references) are exported as JSON via `terraform output -json` and uploaded as a GitHub Actions artifact using `actions/upload-artifact@v4`.
- The downstream Ansible job downloads the artifact via `actions/download-artifact@v4` and uses a Python script or Jinja2 template to transform the JSON into an Ansible inventory file (INI or YAML format).
- An alternative approach uses the `azure.azcollection.azure_rm` Ansible dynamic inventory plugin to query Azure directly for VM metadata. This is more resilient to drift but requires the Ansible runner to have Azure credentials and network access.
- For the Kafka Lab, the recommended approach is **Terraform-generated inventory** (from outputs) supplemented by the Azure RM dynamic inventory plugin for validation. This ensures the Ansible inventory exactly matches what Terraform just provisioned.

### Environment Protection Rules and Deployment Gates

- GitHub Actions environments (e.g., `dev`, `staging`, `production`) support **required reviewers**, **wait timers**, and **branch restrictions** as native protection rules.
- The `environment:` key on a job triggers these gates. A Terraform apply job targeting production can require manual approval from designated reviewers before proceeding.
- Custom deployment protection rules (GitHub Enterprise Cloud) enable integration with external systems (monitoring, compliance) to gate deployments programmatically.
- For multi-region deployments, each region can be modeled as a separate environment (e.g., `southcentralus`, `mexicocentral`, `canadaeast`) with independent protection rules and approval chains.

### Self-Hosted vs GitHub-Hosted Runners

- **GitHub-hosted runners** are ephemeral, managed, and require zero maintenance. They are ideal for Terraform plan/apply since Terraform communicates with Azure APIs over HTTPS (no VNet access required).
- **Self-hosted runners** deployed inside the Azure VNet are required for Ansible. Ansible must SSH into private VMs that have no public IPs. A GitHub-hosted runner cannot reach these VMs without a VPN or bastion tunnel.
- GitHub-hosted runners with Azure private networking (Enterprise feature) can be provisioned into a VNet, but this requires GitHub Enterprise Cloud and adds complexity.
- **Recommendation for Kafka Lab**: Use GitHub-hosted `ubuntu-latest` runners for Terraform jobs. Use a self-hosted runner (a small Azure VM or container in the VNet) for Ansible jobs. This balances operational simplicity with network access requirements.

### Secrets and Variable Management

- **GitHub Secrets** store non-sensitive Azure identifiers (client ID, tenant ID, subscription ID) and any workflow-specific configuration. These are scoped to repository or environment level.
- **Azure Key Vault** stores sensitive operational secrets (SSH private keys, Confluent license keys, TLS certificates). These are retrieved at runtime via `az keyvault secret show` after OIDC login.
- The hybrid approach ensures OIDC bootstrapping secrets live in GitHub (they are non-sensitive identifiers), while all sensitive material lives in Key Vault with RBAC, audit logging, and rotation support.

### Workflow Trigger Strategy

- **Push to `main`**: Triggers the full Terraform plan → approve → apply → Ansible pipeline for production deployments.
- **Pull request**: Triggers Terraform plan only (no apply) with plan output posted as a PR comment for review. Uses `hashicorp/setup-terraform` with `terraform_wrapper: true` and `actions/github-script` to post the plan diff.
- **`workflow_dispatch`**: Manual trigger with input parameters for targeted deployments (specific region, skip Ansible, destroy mode). Essential for day-2 operations and incident response.
- **Schedule (`cron`)**: Optional nightly drift detection via `terraform plan` with `-detailed-exitcode` to alert on infrastructure drift without applying changes.

### Multi-Region Deployment Strategy

- Use a **matrix strategy** to deploy Terraform across regions in parallel: `matrix: { region: [southcentralus, mexicocentral, canadaeast] }`.
- Each matrix leg uses region-specific backend configuration and variable files.
- Ansible runs sequentially after all Terraform matrix jobs complete (using `needs: terraform`), or per-region using a matching matrix.
- A **reusable workflow** (`workflow_call`) encapsulates the Terraform init/plan/apply sequence, called from the parent workflow with region-specific inputs.

## Architecture / Design Decisions

### Decision 1: Hybrid Runner Strategy

**Decision**: GitHub-hosted runners for Terraform, self-hosted runners for Ansible.

**Rationale**: Terraform interacts with Azure Resource Manager APIs over HTTPS and does not need VNet access. Ansible must SSH into private VMs with no public endpoints. A self-hosted runner inside the VNet provides native SSH access without requiring a bastion host, VPN gateway, or SSH tunneling through a public endpoint, which would increase attack surface and complexity.

### Decision 2: OIDC with UAMI (No Service Principal Secrets)

**Decision**: Use OIDC federated identity with a User Assigned Managed Identity rather than a Service Principal with client secret.

**Rationale**: Eliminates long-lived credentials entirely. The UAMI is scoped with least-privilege RBAC to `klc-rg-kafkalab-scus` and the Terraform state storage account. Federated credentials are scoped per-environment so a PR workflow cannot assume the production identity. This aligns with the project's zero-secret authentication mandate.

### Decision 3: Artifact-Based Terraform-to-Ansible Handoff

**Decision**: Pass Terraform outputs as a JSON artifact between jobs, transformed into Ansible inventory by a Python script.

**Rationale**: Artifacts are immutable within a workflow run, providing an auditable record of exactly which infrastructure the Ansible stage targeted. This is more reliable than querying Azure dynamically (which could return stale or drifted data) and avoids coupling Ansible to the Terraform state backend. The Python inventory script is versioned alongside the playbooks.

### Decision 4: Environment-Per-Region Gating

**Decision**: Model each Azure region as a GitHub Actions environment with independent protection rules.

**Rationale**: This enables progressive rollout (deploy to `southcentralus` first, validate, then promote to `mexicocentral` and `canadaeast`). The DR region (`canadaeast`) can have stricter gates (e.g., two approvers) since it is passive and deployments there are less frequent. Environment-scoped secrets ensure each region uses the correct UAMI and Key Vault.

### Decision 5: SSH Key Management

**Decision**: Generate ephemeral SSH keys per workflow run; inject the public key via Terraform `admin_ssh_key`; pass the private key to the Ansible job as a masked secret; destroy after use.

**Rationale**: Avoids storing persistent SSH keys. Each deployment gets a fresh key pair, limiting blast radius if a key is compromised. The private key never touches disk outside the workflow run. For the initial bootstrap (before Terraform provisions the key), the UAMI can use Azure Run Command as a fallback.

## Configuration Reference

### Federated Identity Credential (Terraform)

```hcl
resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "uami-github-actions"
  resource_group_name = "klc-rg-kafkalab-scus"
  location            = "southcentralus"
}

resource "azurerm_federated_identity_credential" "github_main" {
  name                = "github-main-branch"
  resource_group_name = "klc-rg-kafkalab-scus"
  parent_id           = azurerm_user_assigned_identity.github_actions.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:kafka-lab/infra:environment:production"
}
```

### Reusable Terraform Workflow (`.github/workflows/terraform-deploy.yml`)

```yaml
name: Terraform Deploy (Reusable)

on:
  workflow_call:
    inputs:
      region:
        required: true
        type: string
      environment:
        required: true
        type: string
      action:
        required: false
        type: string
        default: apply

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init
        working-directory: terraform/${{ inputs.region }}
        run: terraform init -backend-config="key=${{ inputs.region }}.tfstate"
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_USE_OIDC: true

      - name: Terraform Plan
        working-directory: terraform/${{ inputs.region }}
        run: terraform plan -out=tfplan -var-file="${{ inputs.region }}.tfvars"
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_USE_OIDC: true

      - name: Terraform Apply
        if: inputs.action == 'apply'
        working-directory: terraform/${{ inputs.region }}
        run: terraform apply -auto-approve tfplan
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_USE_OIDC: true

      - name: Export Terraform Outputs
        if: inputs.action == 'apply'
        working-directory: terraform/${{ inputs.region }}
        run: terraform output -json > ../../tf-outputs-${{ inputs.region }}.json

      - name: Upload Terraform Outputs
        if: inputs.action == 'apply'
        uses: actions/upload-artifact@v4
        with:
          name: tf-outputs-${{ inputs.region }}
          path: tf-outputs-${{ inputs.region }}.json
          retention-days: 7
```

### Parent Orchestration Workflow (`.github/workflows/deploy-infrastructure.yml`)

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  workflow_dispatch:
    inputs:
      regions:
        description: 'Comma-separated regions (or "all")'
        default: 'all'
      skip_ansible:
        description: 'Skip Ansible configuration'
        type: boolean
        default: false

permissions:
  id-token: write
  contents: read

jobs:
  terraform-primary:
    uses: ./.github/workflows/terraform-deploy.yml
    with:
      region: southcentralus
      environment: southcentralus
    secrets: inherit

  terraform-secondary:
    uses: ./.github/workflows/terraform-deploy.yml
    with:
      region: mexicocentral
      environment: mexicocentral
    secrets: inherit

  terraform-dr:
    needs: [terraform-primary, terraform-secondary]
    uses: ./.github/workflows/terraform-deploy.yml
    with:
      region: canadaeast
      environment: canadaeast
    secrets: inherit

  ansible-configure:
    if: ${{ !inputs.skip_ansible }}
    needs: [terraform-primary, terraform-secondary, terraform-dr]
    runs-on: [self-hosted, azure-vnet]
    environment: ansible-configure

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Download All Terraform Outputs
        uses: actions/download-artifact@v4
        with:
          pattern: tf-outputs-*
          merge-multiple: true

      - name: Generate Ansible Inventory
        run: python3 scripts/generate_inventory.py \
          --outputs tf-outputs-southcentralus.json \
                    tf-outputs-mexicocentral.json \
                    tf-outputs-canadaeast.json \
          --output ansible/inventory/kafka-lab.yml

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Retrieve SSH Key from Key Vault
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "ansible-ssh-private-key" \
            --query value -o tsv > ~/.ssh/ansible_key
          chmod 600 ~/.ssh/ansible_key

      - name: Run Ansible Playbook
        run: |
          ansible-playbook \
            -i ansible/inventory/kafka-lab.yml \
            ansible/playbooks/site.yml \
            --private-key ~/.ssh/ansible_key

      - name: Cleanup SSH Key
        if: always()
        run: rm -f ~/.ssh/ansible_key
```

### PR Plan-Only Workflow (`.github/workflows/terraform-plan-pr.yml`)

```yaml
name: Terraform Plan (PR)

on:
  pull_request:
    branches: [main]
    paths: ['terraform/**']

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        region: [southcentralus, mexicocentral, canadaeast]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init and Plan
        working-directory: terraform/${{ matrix.region }}
        run: |
          terraform init -backend-config="key=${{ matrix.region }}.tfstate"
          terraform plan -var-file="${{ matrix.region }}.tfvars" -no-color
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_USE_OIDC: true
```

### Key Vault Secret Retrieval Pattern

```yaml
- name: Azure Login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- name: Retrieve Secrets from Key Vault
  run: |
    CONFLUENT_LICENSE=$(az keyvault secret show \
      --vault-name "${{ secrets.KEYVAULT_NAME }}" \
      --name "confluent-license-key" \
      --query value -o tsv)
    echo "::add-mask::$CONFLUENT_LICENSE"
    echo "CONFLUENT_LICENSE=$CONFLUENT_LICENSE" >> "$GITHUB_ENV"
```

## Risks and Open Questions

### Risks

1. **Self-hosted runner maintenance**: The self-hosted runner in the VNet requires patching, monitoring, and lifecycle management. If it goes offline, Ansible deployments are blocked. Mitigation: Use an Azure Container App or VM Scale Set with auto-replacement.
2. **Artifact size limits**: GitHub Actions artifacts have a 10 GB limit per upload. Terraform outputs for this project should be small (KBs), but the limit applies if we later include Ansible artifacts or logs.
3. **OIDC token lifetime**: GitHub OIDC tokens are short-lived (approximately 5 minutes). Long Terraform applies or Ansible runs may need token refresh. The `azure/login@v2` action handles refresh for Azure CLI calls, but direct ARM API calls in Terraform must complete within the token window or use the AzureRM provider's built-in refresh logic.
4. **Concurrency**: Parallel Terraform applies to different regions use separate state files and should not conflict. However, shared resources (e.g., DNS zones, global policies) could cause race conditions. Mitigation: Use `concurrency` groups or explicit `needs:` ordering for shared resources.
5. **Secret rotation**: Federated credentials do not expire, but the UAMI role assignments and Key Vault access policies must be reviewed periodically. There is no built-in rotation for federated credentials since they are identity-based, not secret-based.

### Open Questions

1. **Bastion vs direct SSH**: Should the self-hosted runner SSH directly to VMs, or should it use Azure Bastion as a jump host? Direct SSH is simpler but requires the runner to be on the same subnet or a peered subnet. Bastion adds latency but improves audit logging.
2. **Terraform state backend**: Should each region have its own storage account for state, or share a single storage account with region-prefixed keys? Separate accounts improve blast radius isolation; shared accounts simplify management.
3. **Ansible pull vs push**: The current design uses push-mode Ansible (runner SSHs into VMs). An alternative is pull-mode (`ansible-pull`) where VMs fetch configuration from the repository on a schedule. Pull-mode eliminates the self-hosted runner requirement but loses orchestration control.
4. **DR region deployment cadence**: Should the `canadaeast` DR region be deployed on every push to main, or only on manual trigger? Deploying on every push keeps DR current but consumes resources for a passive region.
5. **Runner placement**: Should the self-hosted runner be a dedicated VM, an Azure Container Instance, or a pod in an AKS cluster? Each has different cost, scalability, and maintenance profiles.

## References

- [Microsoft Learn: GitHub Actions for Azure](https://learn.microsoft.com/en-us/azure/developer/github/github-actions)
- [Microsoft Learn: Managed Identities Overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [GitHub Docs: Configuring OIDC in Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Microsoft Learn: Authenticate to Azure from GitHub via OIDC](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)
- [Microsoft Learn: GitHub Actions OIDC + Terraform CI/CD Sample](https://learn.microsoft.com/en-us/samples/azure-samples/github-terraform-oidc-ci-cd/github-terraform-oidc-ci-cd/)
- [HashiCorp Developer: Automate Terraform with GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Terraform Registry: AzureRM OIDC Auth Guide](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc)
- [GitHub Docs: Managing Environments for Deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- [GitHub Blog: Deployment Protection Rules](https://github.blog/news-insights/product-news/announcing-github-actions-deployment-protection-rules-now-in-public-beta/)
- [GitHub Blog: When to Choose GitHub-Hosted vs Self-Hosted Runners](https://github.blog/enterprise-software/ci-cd/when-to-choose-github-hosted-runners-or-self-hosted-runners-with-github-actions/)
- [GitHub Docs: Private Networking with GitHub-Hosted Runners](https://docs.github.com/en/actions/concepts/runners/private-networking)
- [Microsoft Learn: Azure Key Vault Secrets in GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/github-actions-key-vault)
- [Microsoft Learn: Ansible Dynamic Inventory for Azure](https://learn.microsoft.com/en-us/azure/developer/ansible/dynamic-inventory-configure)
- [Ansible Docs: azure.azcollection.azure_rm Inventory Plugin](https://docs.ansible.com/projects/ansible/latest/collections/azure/azcollection/azure_rm_inventory.html)
- [Spacelift: Using Terraform and Ansible Together](https://spacelift.io/blog/using-terraform-and-ansible-together)
- [Your Azure Coach: GitHub Actions with User-Assigned Managed Identity](https://yourazurecoach.com/2022/12/29/use-github-actions-with-user-assigned-managed-identity/)
