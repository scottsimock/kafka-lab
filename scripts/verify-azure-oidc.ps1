<#
.SYNOPSIS
    Verifies the Azure OIDC setup for kafka-lab GitHub Actions.

.DESCRIPTION
    Checks that UAMIs, RBAC roles, federated credentials, and GitHub
    environment secrets are properly configured. Reports pass/fail for
    each check.

.PARAMETER GitHubRepo
    GitHub repository in owner/repo format. Default: scottsimock/kafka-lab

.PARAMETER SharedResourceGroup
    Resource group for UAMI resources. Default: rg-kafkalab-shared-scus

.PARAMETER KeyVaultName
    Key Vault name. Default: klc-kv-kafkalab-scus

.PARAMETER Environments
    Environments to verify. Default: dev, staging, prod

.EXAMPLE
    ./scripts/verify-azure-oidc.ps1
    ./scripts/verify-azure-oidc.ps1 -Environments dev
#>

[CmdletBinding()]
param(
    [string]$GitHubRepo = 'scottsimock/kafka-lab',
    [string]$SharedResourceGroup = 'rg-kafkalab-shared-scus',
    [string]$KeyVaultName = 'klc-kv-kafkalab-scus',
    [string[]]$Environments = @('dev', 'staging', 'prod')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$pass = 0
$fail = 0

function Test-Check {
    param([string]$Name, [scriptblock]$Test)
    try {
        $result = & $Test
        if ($result) {
            Write-Host "  ✅ $Name" -ForegroundColor Green
            $script:pass++
        }
        else {
            Write-Host "  ❌ $Name" -ForegroundColor Red
            $script:fail++
        }
    }
    catch {
        Write-Host "  ❌ $Name — $($_.Exception.Message)" -ForegroundColor Red
        $script:fail++
    }
}

Write-Host "`n🔍 Verifying Azure OIDC Setup" -ForegroundColor Magenta
Write-Host "   Repo: $GitHubRepo"
Write-Host ""

# ── UAMIs ────────────────────────────────────────────────────────────────

$uamiNames = @(
    'uami-gha-terraform-deploy'
    'uami-gha-ansible-config'
    'uami-gha-app-deploy'
)

Write-Host "▸ User-Assigned Managed Identities" -ForegroundColor Cyan

foreach ($name in $uamiNames) {
    Test-Check "UAMI exists: $name" {
        $identity = az identity show --name $name --resource-group $SharedResourceGroup -o json 2>$null | ConvertFrom-Json
        $null -ne $identity
    }
}

# ── RBAC ─────────────────────────────────────────────────────────────────

Write-Host "`n▸ RBAC Role Assignments" -ForegroundColor Cyan

$subscriptionId = (az account show --query id -o tsv)

$rbacChecks = @(
    @{ Uami = 'uami-gha-terraform-deploy'; Role = 'Contributor' }
    @{ Uami = 'uami-gha-terraform-deploy'; Role = 'Storage Blob Data Contributor' }
    @{ Uami = 'uami-gha-ansible-config';   Role = 'Reader' }
    @{ Uami = 'uami-gha-app-deploy';       Role = 'Website Contributor' }
)

foreach ($check in $rbacChecks) {
    Test-Check "$($check.Uami) → $($check.Role)" {
        $principalId = az identity show --name $check.Uami --resource-group $SharedResourceGroup --query principalId -o tsv 2>$null
        if (-not $principalId) { return $false }
        $assignments = az role assignment list --assignee $principalId --role $check.Role -o json 2>$null | ConvertFrom-Json
        $assignments.Count -gt 0
    }
}

# ── Federated Credentials ────────────────────────────────────────────────

Write-Host "`n▸ Federated Credentials" -ForegroundColor Cyan

foreach ($name in $uamiNames) {
    foreach ($env in $Environments) {
        $credName = "github-env-$env"
        Test-Check "$name → $credName" {
            $cred = az identity federated-credential show `
                --name $credName `
                --identity-name $name `
                --resource-group $SharedResourceGroup `
                -o json 2>$null | ConvertFrom-Json
            $null -ne $cred
        }
    }
}

# Branch credential for terraform (drift detection)
Test-Check "uami-gha-terraform-deploy → github-ref-main" {
    $cred = az identity federated-credential show `
        --name 'github-ref-main' `
        --identity-name 'uami-gha-terraform-deploy' `
        --resource-group $SharedResourceGroup `
        -o json 2>$null | ConvertFrom-Json
    $null -ne $cred
}

# ── GitHub Environments ──────────────────────────────────────────────────

Write-Host "`n▸ GitHub Environments" -ForegroundColor Cyan

foreach ($env in $Environments) {
    Test-Check "Environment exists: $env" {
        $result = gh api "repos/$GitHubRepo/environments/$env" --jq '.name' 2>$null
        $result -eq $env
    }
}

# ── GitHub Secrets ───────────────────────────────────────────────────────

Write-Host "`n▸ GitHub Environment Secrets (existence only)" -ForegroundColor Cyan

$requiredSecrets = @('AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'AZURE_SUBSCRIPTION_ID')

foreach ($env in $Environments) {
    foreach ($secret in $requiredSecrets) {
        Test-Check "$env/$secret" {
            $secrets = gh secret list --env $env --repo $GitHubRepo --json name 2>$null | ConvertFrom-Json
            $secrets.name -contains $secret
        }
    }
}

# ── Key Vault ────────────────────────────────────────────────────────────

Write-Host "`n▸ Key Vault Access" -ForegroundColor Cyan

Test-Check "Key Vault exists: $KeyVaultName" {
    $kv = az keyvault show --name $KeyVaultName -o json 2>$null | ConvertFrom-Json
    $null -ne $kv
}

# ── Summary ──────────────────────────────────────────────────────────────

$total = $pass + $fail
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "  Results: $pass/$total passed" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })
if ($fail -gt 0) {
    Write-Host "  ⚠️  $fail check(s) failed — review above" -ForegroundColor Red
}
else {
    Write-Host "  All checks passed — ready for deployment" -ForegroundColor Green
}
Write-Host "═══════════════════════════════════════════════════════"
Write-Host ""

exit $fail
