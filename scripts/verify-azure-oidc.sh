#!/usr/bin/env bash
#
# Verifies the Azure OIDC setup for kafka-lab GitHub Actions.
# Checks UAMIs, RBAC roles, federated credentials, GitHub environments,
# secrets, and Key Vault access. Reports pass/fail per check.
#
# Prerequisites: az (authenticated), gh (authenticated), jq
#
# Usage:
#   ./scripts/verify-azure-oidc.sh [OPTIONS]
#
# Examples:
#   ./scripts/verify-azure-oidc.sh                        # Full verification
#   ./scripts/verify-azure-oidc.sh --environments dev     # Dev only

set -uo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────

GITHUB_REPO="scottsimock/kafka-lab"
SHARED_RESOURCE_GROUP="rg-kafkalab-shared-scus"
KEYVAULT_NAME="klc-kv-kafkalab-scus"
ENVIRONMENTS="dev,staging,prod"

# ── Helpers ──────────────────────────────────────────────────────────────

PASS=0
FAIL=0

check_pass() { printf '  \033[32m✅ %s\033[0m\n' "$1"; ((PASS++)); }
check_fail() { printf '  \033[31m❌ %s\033[0m\n' "$1"; ((FAIL++)); }

assert_tool() {
    command -v "$1" &>/dev/null || { printf '\033[31m❌ %s is required but not found in PATH.\033[0m\n' "$1"; exit 1; }
}

usage() {
    cat <<'EOF'
Usage: verify-azure-oidc.sh [OPTIONS]

Options:
  --github-repo REPO           GitHub repo (default: scottsimock/kafka-lab)
  --shared-rg NAME             Shared resource group (default: rg-kafkalab-shared-scus)
  --keyvault NAME              Key Vault name (default: klc-kv-kafkalab-scus)
  --environments ENVS          Comma-separated environments (default: dev,staging,prod)
  -h, --help                   Show this help message
EOF
    exit 0
}

# ── Parse Arguments ──────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --github-repo)    GITHUB_REPO="$2"; shift 2 ;;
        --shared-rg)      SHARED_RESOURCE_GROUP="$2"; shift 2 ;;
        --keyvault)       KEYVAULT_NAME="$2"; shift 2 ;;
        --environments)   ENVIRONMENTS="$2"; shift 2 ;;
        -h|--help)        usage ;;
        *) printf '\033[31m❌ Unknown option: %s. Use --help for usage.\033[0m\n' "$1"; exit 1 ;;
    esac
done

IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"

# ── Pre-flight ───────────────────────────────────────────────────────────

printf '\n\033[35m🔍 Verifying Azure OIDC Setup\033[0m\n'
echo "   Repo: ${GITHUB_REPO}"
echo ""

assert_tool az
assert_tool gh
assert_tool jq

SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null) \
    || { printf '\033[31m❌ Not logged into Azure. Run: az login\033[0m\n'; exit 1; }

# ── UAMI Names ──────────────────────────────────────────────────────────

UAMI_NAMES=(
    "uami-gha-terraform-deploy"
    "uami-gha-ansible-config"
    "uami-gha-app-deploy"
)

# ── UAMIs ────────────────────────────────────────────────────────────────

printf '\033[36m▸ User-Assigned Managed Identities\033[0m\n'

for name in "${UAMI_NAMES[@]}"; do
    if az identity show --name "$name" --resource-group "$SHARED_RESOURCE_GROUP" -o json &>/dev/null; then
        check_pass "UAMI exists: ${name}"
    else
        check_fail "UAMI exists: ${name}"
    fi
done

# ── RBAC ─────────────────────────────────────────────────────────────────

printf '\n\033[36m▸ RBAC Role Assignments\033[0m\n'

check_rbac() {
    local uami_name="$1" role="$2"
    local principal_id
    principal_id=$(az identity show --name "$uami_name" --resource-group "$SHARED_RESOURCE_GROUP" --query principalId -o tsv 2>/dev/null)
    if [[ -z "$principal_id" ]]; then
        check_fail "${uami_name} → ${role}"
        return
    fi

    local count
    count=$(az role assignment list --assignee "$principal_id" --role "$role" -o json 2>/dev/null | jq 'length')
    if [[ "$count" -gt 0 ]]; then
        check_pass "${uami_name} → ${role}"
    else
        check_fail "${uami_name} → ${role}"
    fi
}

check_rbac "uami-gha-terraform-deploy" "Contributor"
check_rbac "uami-gha-terraform-deploy" "Storage Blob Data Contributor"
check_rbac "uami-gha-ansible-config"   "Reader"
check_rbac "uami-gha-app-deploy"       "Website Contributor"

# ── Federated Credentials ────────────────────────────────────────────────

printf '\n\033[36m▸ Federated Credentials\033[0m\n'

check_federated() {
    local uami_name="$1" cred_name="$2"
    if az identity federated-credential show \
        --name "$cred_name" \
        --identity-name "$uami_name" \
        --resource-group "$SHARED_RESOURCE_GROUP" \
        -o json &>/dev/null; then
        check_pass "${uami_name} → ${cred_name}"
    else
        check_fail "${uami_name} → ${cred_name}"
    fi
}

for name in "${UAMI_NAMES[@]}"; do
    for env in "${ENV_ARRAY[@]}"; do
        check_federated "$name" "github-env-${env}"
    done
done

# Branch credential for terraform (drift detection)
check_federated "uami-gha-terraform-deploy" "github-ref-main"

# ── GitHub Environments ──────────────────────────────────────────────────

printf '\n\033[36m▸ GitHub Environments\033[0m\n'

for env in "${ENV_ARRAY[@]}"; do
    result=$(gh api "repos/${GITHUB_REPO}/environments/${env}" --jq '.name' 2>/dev/null) || true
    if [[ "$result" == "$env" ]]; then
        check_pass "Environment exists: ${env}"
    else
        check_fail "Environment exists: ${env}"
    fi
done

# ── GitHub Secrets ───────────────────────────────────────────────────────

printf '\n\033[36m▸ GitHub Environment Secrets (existence only)\033[0m\n'

REQUIRED_SECRETS=("AZURE_CLIENT_ID" "AZURE_TENANT_ID" "AZURE_SUBSCRIPTION_ID")

for env in "${ENV_ARRAY[@]}"; do
    secrets_json=$(gh secret list --env "$env" --repo "$GITHUB_REPO" --json name 2>/dev/null) || secrets_json="[]"
    for secret in "${REQUIRED_SECRETS[@]}"; do
        if echo "$secrets_json" | jq -e --arg s "$secret" '[.[].name] | index($s)' &>/dev/null; then
            check_pass "${env}/${secret}"
        else
            check_fail "${env}/${secret}"
        fi
    done
done

# ── Key Vault ────────────────────────────────────────────────────────────

printf '\n\033[36m▸ Key Vault Access\033[0m\n'

if az keyvault show --name "$KEYVAULT_NAME" -o json &>/dev/null; then
    check_pass "Key Vault exists: ${KEYVAULT_NAME}"
else
    check_fail "Key Vault exists: ${KEYVAULT_NAME}"
fi

# ── Summary ──────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo ""
if [[ $FAIL -eq 0 ]]; then
    printf '\033[32m═══════════════════════════════════════════════════════\033[0m\n'
    printf '\033[32m  Results: %d/%d passed\033[0m\n' "$PASS" "$TOTAL"
    printf '\033[32m  All checks passed — ready for deployment\033[0m\n'
    printf '\033[32m═══════════════════════════════════════════════════════\033[0m\n'
else
    printf '\033[33m═══════════════════════════════════════════════════════\033[0m\n'
    printf '\033[33m  Results: %d/%d passed\033[0m\n' "$PASS" "$TOTAL"
    printf '\033[31m  ⚠️  %d check(s) failed — review above\033[0m\n' "$FAIL"
    printf '\033[33m═══════════════════════════════════════════════════════\033[0m\n'
fi
echo ""

exit "$FAIL"
