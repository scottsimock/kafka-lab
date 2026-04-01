<#
.SYNOPSIS
    Creates UAMIs, assigns RBAC roles, configures federated credentials,
    and sets GitHub environment secrets for kafka-lab OIDC authentication.

.DESCRIPTION
    End-to-end setup for GitHub Actions → Azure OIDC:
      1. Creates a shared resource group for identities
      2. Creates three UAMIs (terraform, ansible, app-deploy)
      3. Assigns RBAC roles per the kafka-lab docs
      4. Configures federated credentials for each environment
      5. Sets GitHub environment secrets via gh CLI

    Prerequisites:
      - Azure CLI (az) authenticated with Owner/UAA on the subscription
      - GitHub CLI (gh) authenticated with repo admin access
      - PowerShell 7+

.PARAMETER GitHubRepo
    GitHub repository in owner/repo format. Default: scottsimock/kafka-lab

.PARAMETER Location
    Azure region. Default: southcentralus

.PARAMETER SharedResourceGroup
    Resource group for UAMI resources. Default: rg-kafkalab-shared-scus

.PARAMETER TargetResourceGroup
    Resource group where kafka-lab infra is deployed. Default: klc-rg-kafkalab-scus

.PARAMETER KeyVaultName
    Key Vault name for Ansible secrets. Default: klc-kv-kafkalab-scus

.PARAMETER FunctionAppName
    Function App name for webapp deployment. Default: klc-func-kafkalab-dev-scus

.PARAMETER Environments
    Environments to configure. Default: dev, staging, prod

.PARAMETER SkipUami
    Skip UAMI creation (use if identities already exist).

.PARAMETER SkipRbac
    Skip RBAC role assignments.

.PARAMETER SkipFederated
    Skip federated credential creation.

.PARAMETER SkipSecrets
    Skip GitHub secret configuration.

.PARAMETER WhatIf
    Show what would be done without making changes.

.EXAMPLE
    # Full setup
    ./scripts/setup-azure-oidc.ps1

    # Dev only, skip UAMI creation
    ./scripts/setup-azure-oidc.ps1 -Environments dev -SkipUami

    # Dry run
    ./scripts/setup-azure-oidc.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GitHubRepo = 'scottsimock/kafka-lab',
    [string]$Location = 'southcentralus',
    [string]$SharedResourceGroup = 'rg-kafkalab-shared-scus',
    [string]$TargetResourceGroup = 'klc-rg-kafkalab-scus',
    [string]$KeyVaultName = 'klc-kv-kafkalab-scus',
    [string]$FunctionAppName = 'klc-func-kafkalab-dev-scus',
    [string[]]$Environments = @('dev', 'staging', 'prod'),
    [switch]$SkipUami,
    [switch]$SkipRbac,
    [switch]$SkipFederated,
    [switch]$SkipSecrets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ──────────────────────────────────────────────────────────────

function Write-Step { param([string]$Message) Write-Host "`n▸ $Message" -ForegroundColor Cyan }
function Write-OK   { param([string]$Message) Write-Host "  ✅ $Message" -ForegroundColor Green }
function Write-Skip { param([string]$Message) Write-Host "  ⏭️  $Message" -ForegroundColor Yellow }

function Assert-Tool {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but not found in PATH. Install it first."
    }
}

# ── Pre-flight ───────────────────────────────────────────────────────────

Write-Host "`n🔧 kafka-lab Azure OIDC Setup" -ForegroundColor Magenta
Write-Host "   Repo: $GitHubRepo"
Write-Host "   Environments: $($Environments -join ', ')"
Write-Host ""

Assert-Tool 'az'
Assert-Tool 'gh'

# Verify Azure login
$azAccount = az account show --query '{subscriptionId:id, tenantId:tenantId, name:name}' -o json 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    throw "Not logged into Azure. Run: az login"
}
Write-Host "   Azure subscription: $($azAccount.name) ($($azAccount.subscriptionId))"
$SubscriptionId = $azAccount.subscriptionId
$TenantId = $azAccount.tenantId

# Verify GitHub auth
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Not logged into GitHub. Run: gh auth login"
}

# ── UAMI Definitions ────────────────────────────────────────────────────

$Uamis = @(
    @{
        Name  = 'uami-gha-terraform-deploy'
        Roles = @(
            @{ Role = 'Contributor'; Scope = "/subscriptions/$SubscriptionId" }
            @{ Role = 'Storage Blob Data Contributor'; Scope = "/subscriptions/$SubscriptionId/resourceGroups/$SharedResourceGroup" }
        )
        FederatedEnvs    = $Environments
        FederatedBranches = @('main')
    }
    @{
        Name  = 'uami-gha-ansible-config'
        Roles = @(
            @{ Role = 'Reader'; Scope = "/subscriptions/$SubscriptionId" }
        )
        KeyVaultAccess   = $true
        FederatedEnvs    = $Environments
        FederatedBranches = @()
    }
    @{
        Name  = 'uami-gha-app-deploy'
        Roles = @(
            @{ Role = 'Website Contributor'; Scope = "/subscriptions/$SubscriptionId/resourceGroups/$TargetResourceGroup" }
        )
        FederatedEnvs    = $Environments
        FederatedBranches = @()
    }
)

# ── Step 1: Create shared resource group ─────────────────────────────────

Write-Step "Creating shared resource group: $SharedResourceGroup"
if ($PSCmdlet.ShouldProcess($SharedResourceGroup, 'Create resource group')) {
    az group create --name $SharedResourceGroup --location $Location -o none 2>$null
    Write-OK "Resource group ready"
}

# ── Step 2: Create UAMIs ────────────────────────────────────────────────

$UamiDetails = @{}

foreach ($uami in $Uamis) {
    Write-Step "UAMI: $($uami.Name)"

    if ($SkipUami) {
        Write-Skip "Skipping creation (reading existing)"
        $identity = az identity show --name $uami.Name --resource-group $SharedResourceGroup -o json 2>$null | ConvertFrom-Json
        if (-not $identity) {
            throw "UAMI $($uami.Name) not found. Remove -SkipUami to create it."
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($uami.Name, 'Create UAMI')) {
            $existing = az identity show --name $uami.Name --resource-group $SharedResourceGroup -o json 2>$null | ConvertFrom-Json
            if ($existing) {
                Write-OK "Already exists"
                $identity = $existing
            }
            else {
                $identity = az identity create `
                    --name $uami.Name `
                    --resource-group $SharedResourceGroup `
                    --location $Location `
                    -o json | ConvertFrom-Json
                Write-OK "Created"
            }
        }
    }

    $UamiDetails[$uami.Name] = @{
        ClientId    = $identity.clientId
        PrincipalId = $identity.principalId
        TenantId    = $identity.tenantId
    }
    Write-Host "    clientId:    $($identity.clientId)"
    Write-Host "    principalId: $($identity.principalId)"
}

# ── Step 3: Assign RBAC roles ───────────────────────────────────────────

if (-not $SkipRbac) {
    foreach ($uami in $Uamis) {
        $principalId = $UamiDetails[$uami.Name].PrincipalId

        foreach ($roleAssignment in $uami.Roles) {
            Write-Step "RBAC: $($uami.Name) → $($roleAssignment.Role)"
            if ($PSCmdlet.ShouldProcess("$($roleAssignment.Role) on $($roleAssignment.Scope)", 'Assign role')) {
                $existing = az role assignment list `
                    --assignee $principalId `
                    --role $roleAssignment.Role `
                    --scope $roleAssignment.Scope `
                    -o json 2>$null | ConvertFrom-Json

                if ($existing -and $existing.Count -gt 0) {
                    Write-OK "Already assigned"
                }
                else {
                    az role assignment create `
                        --assignee-object-id $principalId `
                        --assignee-principal-type ServicePrincipal `
                        --role $roleAssignment.Role `
                        --scope $roleAssignment.Scope `
                        -o none
                    Write-OK "Assigned"
                }
            }
        }

        # Key Vault access policy
        if ($uami.KeyVaultAccess) {
            Write-Step "Key Vault policy: $($uami.Name) → $KeyVaultName"
            if ($PSCmdlet.ShouldProcess($KeyVaultName, 'Set Key Vault access policy')) {
                az keyvault set-policy `
                    --name $KeyVaultName `
                    --object-id $principalId `
                    --secret-permissions get list `
                    -o none
                Write-OK "Key Vault policy set"
            }
        }
    }
}
else {
    Write-Skip "Skipping RBAC assignments"
}

# ── Step 4: Create federated credentials ─────────────────────────────────

if (-not $SkipFederated) {
    foreach ($uami in $Uamis) {
        # Environment-scoped credentials
        foreach ($env in $uami.FederatedEnvs) {
            $credName = "github-env-$env"
            $subject = "repo:${GitHubRepo}:environment:$env"

            Write-Step "Federated credential: $($uami.Name) → $credName"
            if ($PSCmdlet.ShouldProcess($credName, 'Create federated credential')) {
                $existing = az identity federated-credential show `
                    --name $credName `
                    --identity-name $uami.Name `
                    --resource-group $SharedResourceGroup `
                    -o json 2>$null | ConvertFrom-Json

                if ($existing) {
                    Write-OK "Already exists"
                }
                else {
                    az identity federated-credential create `
                        --name $credName `
                        --identity-name $uami.Name `
                        --resource-group $SharedResourceGroup `
                        --issuer 'https://token.actions.githubusercontent.com' `
                        --subject $subject `
                        --audiences 'api://AzureADTokenExchange' `
                        -o none
                    Write-OK "Created (subject: $subject)"
                }
            }
        }

        # Branch-scoped credentials
        foreach ($branch in $uami.FederatedBranches) {
            $credName = "github-ref-$branch"
            $subject = "repo:${GitHubRepo}:ref:refs/heads/$branch"

            Write-Step "Federated credential: $($uami.Name) → $credName"
            if ($PSCmdlet.ShouldProcess($credName, 'Create federated credential')) {
                $existing = az identity federated-credential show `
                    --name $credName `
                    --identity-name $uami.Name `
                    --resource-group $SharedResourceGroup `
                    -o json 2>$null | ConvertFrom-Json

                if ($existing) {
                    Write-OK "Already exists"
                }
                else {
                    az identity federated-credential create `
                        --name $credName `
                        --identity-name $uami.Name `
                        --resource-group $SharedResourceGroup `
                        --issuer 'https://token.actions.githubusercontent.com' `
                        --subject $subject `
                        --audiences 'api://AzureADTokenExchange' `
                        -o none
                    Write-OK "Created (subject: $subject)"
                }
            }
        }
    }
}
else {
    Write-Skip "Skipping federated credentials"
}

# ── Step 5: Set GitHub environment secrets ───────────────────────────────

if (-not $SkipSecrets) {
    # Use the terraform UAMI's clientId as the primary identity for workflows.
    # The dev-recreate workflow uses a single set of secrets and the terraform
    # UAMI has the broadest access (Contributor + Storage Blob Data Contributor).
    $primaryClientId = $UamiDetails['uami-gha-terraform-deploy'].ClientId

    foreach ($env in $Environments) {
        Write-Step "GitHub secrets: $env environment"
        if ($PSCmdlet.ShouldProcess("$env environment secrets", 'Set GitHub secrets')) {
            gh secret set AZURE_CLIENT_ID --env $env --body $primaryClientId --repo $GitHubRepo
            Write-OK "AZURE_CLIENT_ID"

            gh secret set AZURE_TENANT_ID --env $env --body $TenantId --repo $GitHubRepo
            Write-OK "AZURE_TENANT_ID"

            gh secret set AZURE_SUBSCRIPTION_ID --env $env --body $SubscriptionId --repo $GitHubRepo
            Write-OK "AZURE_SUBSCRIPTION_ID"

            gh secret set KEYVAULT_NAME --env $env --body $KeyVaultName --repo $GitHubRepo
            Write-OK "KEYVAULT_NAME"
        }
    }
}
else {
    Write-Skip "Skipping GitHub secrets"
}

# ── Summary ──────────────────────────────────────────────────────────────

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ OIDC Setup Complete" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  UAMIs created in: $SharedResourceGroup"
Write-Host ""

foreach ($uami in $Uamis) {
    $detail = $UamiDetails[$uami.Name]
    Write-Host "  $($uami.Name)"
    Write-Host "    Client ID: $($detail.ClientId)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  GitHub secrets set for: $($Environments -join ', ')"
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    1. Add SSH_PUBLIC_KEY secret:  gh secret set SSH_PUBLIC_KEY --env dev --body `"`$(cat ~/.ssh/id_rsa.pub)`""
Write-Host "    2. Run Dev Recreate:           Actions → Dev Recreate → Run workflow"
Write-Host "    3. Verify OIDC login:          Actions → Verify OIDC Login (if created)"
Write-Host ""
