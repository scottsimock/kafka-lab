#!/usr/bin/env bash
#
# Creates UAMIs, assigns RBAC roles, configures federated credentials,
# and sets GitHub environment secrets for kafka-lab OIDC authentication.
#
# Prerequisites: az (authenticated), gh (authenticated), jq
#
# Usage:
#   ./scripts/setup-azure-oidc.sh [OPTIONS]
#
# Examples:
#   ./scripts/setup-azure-oidc.sh                        # Full setup
#   ./scripts/setup-azure-oidc.sh --environments dev     # Dev only
#   ./scripts/setup-azure-oidc.sh --skip-uami            # Skip UAMI creation
#   ./scripts/setup-azure-oidc.sh --dry-run              # Show what would be done

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────

GITHUB_REPO="scottsimock/kafka-lab"
LOCATION="southcentralus"
RESOURCE_GROUP="klc-rg-kafkalab-scus"
KEYVAULT_NAME="klc-kv-kafkalab-scus"
FUNCTION_APP_NAME="klc-func-kafkalab-dev-scus"
ENVIRONMENTS="dev,staging,prod"
SKIP_UAMI=false
SKIP_RBAC=false
SKIP_FEDERATED=false
SKIP_SECRETS=false
DRY_RUN=false

# ── Helpers ──────────────────────────────────────────────────────────────

write_step()  { printf '\n\033[36m▸ %s\033[0m\n' "$1"; }
write_ok()    { printf '  \033[32m✅ %s\033[0m\n' "$1"; }
write_skip()  { printf '  \033[33m⏭️  %s\033[0m\n' "$1"; }
write_err()   { printf '  \033[31m❌ %s\033[0m\n' "$1"; }

die() { write_err "$1"; exit 1; }

assert_tool() {
    command -v "$1" &>/dev/null || die "$1 is required but not found in PATH. Install it first."
}

usage() {
    cat <<'EOF'
Usage: setup-azure-oidc.sh [OPTIONS]

Options:
  --github-repo REPO           GitHub repo (default: scottsimock/kafka-lab)
  --location LOCATION          Azure region (default: southcentralus)
  --resource-group NAME        Resource group (default: klc-rg-kafkalab-scus)
  --keyvault NAME              Key Vault name (default: klc-kv-kafkalab-scus)
  --function-app NAME          Function App name (default: klc-func-kafkalab-dev-scus)
  --environments ENVS          Comma-separated environments (default: dev,staging,prod)
  --skip-uami                  Skip UAMI creation
  --skip-rbac                  Skip RBAC role assignments
  --skip-federated             Skip federated credential creation
  --skip-secrets               Skip GitHub secret configuration
  --dry-run                    Show what would be done without making changes
  -h, --help                   Show this help message
EOF
    exit 0
}

# ── Parse Arguments ──────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --github-repo)      GITHUB_REPO="$2"; shift 2 ;;
        --location)         LOCATION="$2"; shift 2 ;;
        --resource-group)   RESOURCE_GROUP="$2"; shift 2 ;;
        --keyvault)         KEYVAULT_NAME="$2"; shift 2 ;;
        --function-app)     FUNCTION_APP_NAME="$2"; shift 2 ;;
        --environments)     ENVIRONMENTS="$2"; shift 2 ;;
        --skip-uami)        SKIP_UAMI=true; shift ;;
        --skip-rbac)        SKIP_RBAC=true; shift ;;
        --skip-federated)   SKIP_FEDERATED=true; shift ;;
        --skip-secrets)     SKIP_SECRETS=true; shift ;;
        --dry-run)          DRY_RUN=true; shift ;;
        -h|--help)          usage ;;
        *) die "Unknown option: $1. Use --help for usage." ;;
    esac
done

# Split comma-separated environments into an array
IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"

# ── UAMI Definitions ────────────────────────────────────────────────────

UAMI_NAMES=(
    "uami-gha-terraform-deploy"
    "uami-gha-ansible-config"
    "uami-gha-app-deploy"
)

# Associative arrays for UAMI details (populated after creation/lookup)
declare -A UAMI_CLIENT_ID
declare -A UAMI_PRINCIPAL_ID

# ── Pre-flight ───────────────────────────────────────────────────────────

printf '\n\033[35m🔧 kafka-lab Azure OIDC Setup\033[0m\n'
echo "   Repo: ${GITHUB_REPO}"
echo "   Environments: ${ENV_ARRAY[*]}"
echo ""

assert_tool az
assert_tool gh
assert_tool jq

# Verify Azure login
AZ_ACCOUNT=$(az account show --query '{subscriptionId:id, tenantId:tenantId, name:name}' -o json 2>/dev/null) \
    || die "Not logged into Azure. Run: az login"

SUBSCRIPTION_ID=$(echo "$AZ_ACCOUNT" | jq -r '.subscriptionId')
TENANT_ID=$(echo "$AZ_ACCOUNT" | jq -r '.tenantId')
AZ_NAME=$(echo "$AZ_ACCOUNT" | jq -r '.name')
echo "   Azure subscription: ${AZ_NAME} (${SUBSCRIPTION_ID})"

# Verify GitHub auth
gh auth status &>/dev/null || die "Not logged into GitHub. Run: gh auth login"

# ── Step 1: Create UAMIs ────────────────────────────────────────────────

create_or_get_uami() {
    local name="$1"
    local identity_json

    write_step "UAMI: ${name}"

    if $SKIP_UAMI; then
        write_skip "Skipping creation (reading existing)"
        identity_json=$(az identity show --name "$name" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null) \
            || die "UAMI ${name} not found. Remove --skip-uami to create it."
    elif $DRY_RUN; then
        write_skip "DRY RUN: Would create UAMI ${name}"
        # Try to read existing for display; not fatal if missing in dry-run
        identity_json=$(az identity show --name "$name" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null) || true
        if [[ -z "$identity_json" ]]; then
            echo "    clientId:    (would be created)"
            echo "    principalId: (would be created)"
            return
        fi
    else
        identity_json=$(az identity show --name "$name" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null) || true
        if [[ -n "$identity_json" ]]; then
            write_ok "Already exists"
        else
            identity_json=$(az identity create \
                --name "$name" \
                --resource-group "$RESOURCE_GROUP" \
                --location "$LOCATION" \
                -o json)
            write_ok "Created"
        fi
    fi

    UAMI_CLIENT_ID[$name]=$(echo "$identity_json" | jq -r '.clientId')
    UAMI_PRINCIPAL_ID[$name]=$(echo "$identity_json" | jq -r '.principalId')
    echo "    clientId:    ${UAMI_CLIENT_ID[$name]}"
    echo "    principalId: ${UAMI_PRINCIPAL_ID[$name]}"
}

for uami_name in "${UAMI_NAMES[@]}"; do
    create_or_get_uami "$uami_name"
done

# ── Step 2: Assign RBAC roles ───────────────────────────────────────────

assign_role() {
    local uami_name="$1" role="$2" scope="$3"
    local principal_id="${UAMI_PRINCIPAL_ID[$uami_name]}"

    write_step "RBAC: ${uami_name} → ${role}"

    if $DRY_RUN; then
        write_skip "DRY RUN: Would assign ${role} at ${scope}"
        return
    fi

    local existing
    existing=$(az role assignment list \
        --assignee "$principal_id" \
        --role "$role" \
        --scope "$scope" \
        -o json 2>/dev/null)

    if [[ $(echo "$existing" | jq 'length') -gt 0 ]]; then
        write_ok "Already assigned"
    else
        az role assignment create \
            --assignee-object-id "$principal_id" \
            --assignee-principal-type ServicePrincipal \
            --role "$role" \
            --scope "$scope" \
            -o none
        write_ok "Assigned"
    fi
}

if ! $SKIP_RBAC; then
    RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

    # terraform-deploy roles (scoped to resource group)
    assign_role "uami-gha-terraform-deploy" "Contributor" "$RG_SCOPE"
    assign_role "uami-gha-terraform-deploy" "Storage Blob Data Contributor" "$RG_SCOPE"

    # ansible-config roles
    assign_role "uami-gha-ansible-config" "Reader" "$RG_SCOPE"

    # Key Vault access policy for ansible-config
    write_step "Key Vault policy: uami-gha-ansible-config → ${KEYVAULT_NAME}"
    if $DRY_RUN; then
        write_skip "DRY RUN: Would set Key Vault access policy"
    else
        if az keyvault set-policy \
            --name "$KEYVAULT_NAME" \
            --object-id "${UAMI_PRINCIPAL_ID[uami-gha-ansible-config]}" \
            --secret-permissions get list \
            -o none 2>/dev/null; then
            write_ok "Key Vault policy set"
        else
            write_skip "Key Vault '${KEYVAULT_NAME}' not found (will configure after Terraform creates it)"
        fi
    fi

    # app-deploy roles
    assign_role "uami-gha-app-deploy" "Website Contributor" \
        "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
else
    write_skip "Skipping RBAC assignments"
fi

# ── Step 3: Create federated credentials ─────────────────────────────────

create_federated_credential() {
    local uami_name="$1" cred_name="$2" subject="$3"

    write_step "Federated credential: ${uami_name} → ${cred_name}"

    if $DRY_RUN; then
        write_skip "DRY RUN: Would create federated credential (subject: ${subject})"
        return
    fi

    local existing
    existing=$(az identity federated-credential show \
        --name "$cred_name" \
        --identity-name "$uami_name" \
        --resource-group "$RESOURCE_GROUP" \
        -o json 2>/dev/null) || true

    if [[ -n "$existing" ]]; then
        write_ok "Already exists"
    else
        az identity federated-credential create \
            --name "$cred_name" \
            --identity-name "$uami_name" \
            --resource-group "$RESOURCE_GROUP" \
            --issuer 'https://token.actions.githubusercontent.com' \
            --subject "$subject" \
            --audiences 'api://AzureADTokenExchange' \
            -o none
        write_ok "Created (subject: ${subject})"
    fi
}

if ! $SKIP_FEDERATED; then
    for uami_name in "${UAMI_NAMES[@]}"; do
        # Environment-scoped credentials
        for env in "${ENV_ARRAY[@]}"; do
            create_federated_credential "$uami_name" "github-env-${env}" \
                "repo:${GITHUB_REPO}:environment:${env}"
        done
    done

    # Branch-scoped credential for terraform-deploy only
    create_federated_credential "uami-gha-terraform-deploy" "github-ref-main" \
        "repo:${GITHUB_REPO}:ref:refs/heads/main"
else
    write_skip "Skipping federated credentials"
fi

# ── Step 4: Set GitHub environment secrets ───────────────────────────────

if ! $SKIP_SECRETS; then
    # Use the terraform UAMI's clientId as the primary identity for workflows.
    # The dev-recreate workflow uses a single set of secrets and the terraform
    # UAMI has the broadest access (Contributor + Storage Blob Data Contributor).
    PRIMARY_CLIENT_ID="${UAMI_CLIENT_ID[uami-gha-terraform-deploy]}"

    for env in "${ENV_ARRAY[@]}"; do
        write_step "GitHub secrets: ${env} environment"
        if $DRY_RUN; then
            write_skip "DRY RUN: Would set secrets for ${env}"
            continue
        fi

        gh secret set AZURE_CLIENT_ID --env "$env" --body "$PRIMARY_CLIENT_ID" --repo "$GITHUB_REPO"
        write_ok "AZURE_CLIENT_ID"

        gh secret set AZURE_TENANT_ID --env "$env" --body "$TENANT_ID" --repo "$GITHUB_REPO"
        write_ok "AZURE_TENANT_ID"

        gh secret set AZURE_SUBSCRIPTION_ID --env "$env" --body "$SUBSCRIPTION_ID" --repo "$GITHUB_REPO"
        write_ok "AZURE_SUBSCRIPTION_ID"

        gh secret set KEYVAULT_NAME --env "$env" --body "$KEYVAULT_NAME" --repo "$GITHUB_REPO"
        write_ok "KEYVAULT_NAME"
    done
else
    write_skip "Skipping GitHub secrets"
fi

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
printf '\033[32m═══════════════════════════════════════════════════════\033[0m\n'
printf '\033[32m  ✅ OIDC Setup Complete\033[0m\n'
printf '\033[32m═══════════════════════════════════════════════════════\033[0m\n'
echo ""
echo "  UAMIs created in: ${RESOURCE_GROUP}"
echo ""

for uami_name in "${UAMI_NAMES[@]}"; do
    echo "  ${uami_name}"
    printf '    \033[90mClient ID: %s\033[0m\n' "${UAMI_CLIENT_ID[$uami_name]:-unknown}"
done

echo ""
echo "  GitHub secrets set for: ${ENV_ARRAY[*]}"
echo ""
printf '\033[33m  Next steps:\033[0m\n'
echo '    1. Add SSH_PUBLIC_KEY secret:  gh secret set SSH_PUBLIC_KEY --env dev --body "$(cat ~/.ssh/id_rsa.pub)"'
echo "    2. Run Dev Recreate:           Actions → Dev Recreate → Run workflow"
echo "    3. Verify OIDC login:          Actions → Verify OIDC Login (if created)"
echo ""
