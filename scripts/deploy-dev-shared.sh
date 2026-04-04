#!/usr/bin/env bash
# deploy-dev-shared.sh — Deploy long-lived shared resources (UAMI, Key Vault)
#
# These resources persist across dev-teardown / dev-recreate cycles.
# Run this once before the first dev environment deployment.
#
# Usage: ./scripts/deploy-dev-shared.sh [--plan-only]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/dev-shared"
TFVARS_FILE="${TF_DIR}/terraform.dev-shared.tfvars"

# Backend config — override via env vars if needed
BACKEND_RESOURCE_GROUP="${BACKEND_RESOURCE_GROUP:-klc-rg-kafkalab-scus}"
BACKEND_STORAGE_ACCOUNT="${BACKEND_STORAGE_ACCOUNT:-klcstgtfstatescus}"
BACKEND_CONTAINER="${BACKEND_CONTAINER:-tfstate}"

PLAN_ONLY=false

for arg in "$@"; do
  case "${arg}" in
    --plan-only) PLAN_ONLY=true ;;
    *)
      echo "Unknown option: ${arg}"
      echo "Usage: $0 [--plan-only]"
      exit 1
      ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] $*"; }

# Validate prerequisites
command -v terraform >/dev/null 2>&1 || { log "ERROR: terraform not found"; exit 1; }
command -v az >/dev/null 2>&1 || { log "ERROR: az CLI not found"; exit 1; }

if [[ ! -f "${TFVARS_FILE}" ]]; then
  log "ERROR: ${TFVARS_FILE} not found"
  exit 1
fi

# =====================================================
# Phase 1: Terraform Init
# =====================================================
log "=== Phase 1: Terraform Init ==="

cd "${TF_DIR}"

if [[ -f backend.tfvars ]]; then
  terraform init -backend-config=backend.tfvars
else
  log "Using inline backend config (storage_account=${BACKEND_STORAGE_ACCOUNT})"
  terraform init \
    -backend-config="resource_group_name=${BACKEND_RESOURCE_GROUP}" \
    -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT}" \
    -backend-config="container_name=${BACKEND_CONTAINER}" \
    -backend-config="key=kafka-lab/dev-shared.tfstate" \
    -backend-config="use_azuread_auth=true" \
    -backend-config="use_oidc=true"
fi

# =====================================================
# Phase 2: Terraform Plan
# =====================================================
log "=== Phase 2: Terraform Plan ==="

terraform plan -input=false \
  -var-file="${TFVARS_FILE}" \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID:-}" \
  -out=dev-shared.tfplan

if [[ "${PLAN_ONLY}" == "true" ]]; then
  log "Plan-only mode — stopping before apply."
  rm -f dev-shared.tfplan
  exit 0
fi

# =====================================================
# Phase 3: Terraform Apply
# =====================================================
log "=== Phase 3: Terraform Apply ==="

terraform apply -auto-approve dev-shared.tfplan
rm -f dev-shared.tfplan

log "=== Shared layer deployment complete ==="
log "Resources deployed: UAMI (klc-id-kafkalab-scus), Key Vault (klc-kv-kafkalab-scus)"
log "These resources persist across dev-teardown and dev-recreate cycles."
