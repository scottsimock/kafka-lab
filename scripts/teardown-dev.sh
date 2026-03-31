#!/usr/bin/env bash
# teardown-dev.sh — Destroy the dev environment and verify cleanup
# Usage: ./scripts/teardown-dev.sh [--confirm] [--skip-verify] [--plan-only]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/dev"
ANSIBLE_DIR="${REPO_ROOT}/ansible"
TFVARS_FILE="${TF_DIR}/terraform.dev.tfvars"
RESOURCE_GROUP="klc-rg-kafkalab-scus"

CONFIRMED=false
SKIP_VERIFY=false
PLAN_ONLY=false

for arg in "$@"; do
  case "${arg}" in
    --confirm)     CONFIRMED=true ;;
    --skip-verify) SKIP_VERIFY=true ;;
    --plan-only)   PLAN_ONLY=true ;;
    *)
      echo "Unknown option: ${arg}"
      echo "Usage: $0 [--confirm] [--skip-verify] [--plan-only]"
      exit 1
      ;;
  esac
done

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# Validate prerequisites
command -v terraform >/dev/null 2>&1 || { log "ERROR: terraform not found"; exit 1; }
command -v az >/dev/null 2>&1 || { log "ERROR: az CLI not found"; exit 1; }

if [[ ! -f "${TFVARS_FILE}" ]]; then
  log "ERROR: ${TFVARS_FILE} not found"
  exit 1
fi

# =====================================================
# Safety prompt — require explicit confirmation
# =====================================================
if [[ "${CONFIRMED}" == "false" && "${PLAN_ONLY}" == "false" ]]; then
  log "WARNING: This will DESTROY all dev environment resources in ${RESOURCE_GROUP}."
  log "Resources destroyed: VMs, NICs, disks, Function App, private endpoints, DNS records, NSGs, VNet."
  log "Resources preserved: Resource group, Terraform state storage account."
  echo ""
  read -r -p "Type 'destroy' to confirm: " RESPONSE
  if [[ "${RESPONSE}" != "destroy" ]]; then
    log "Aborted. Pass --confirm for non-interactive use."
    exit 1
  fi
fi

# =====================================================
# Phase 1: Terraform Destroy Plan
# =====================================================
log "=== Phase 1: Terraform Destroy ==="

cd "${TF_DIR}"

if [[ ! -d .terraform ]]; then
  log "Running terraform init..."
  if [[ -f backend.tfvars ]]; then
    terraform init -backend-config=backend.tfvars
  else
    log "WARN: backend.tfvars not found, using default backend"
    terraform init
  fi
fi

log "Planning destroy..."
terraform plan -destroy \
  -var-file="${TFVARS_FILE}" \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID:-}" \
  -var="ssh_public_key=${SSH_PUBLIC_KEY:-placeholder}" \
  -out=dev-destroy.tfplan

if [[ "${PLAN_ONLY}" == "true" ]]; then
  log "Plan-only mode — stopping before destroy."
  rm -f dev-destroy.tfplan
  exit 0
fi

log "Applying destroy plan..."
terraform apply -auto-approve dev-destroy.tfplan
rm -f dev-destroy.tfplan

log "Terraform destroy complete."

# =====================================================
# Phase 2: Clean up local artifacts
# =====================================================
log "=== Phase 2: Cleanup ==="

# Remove generated inventory
if [[ -f "${ANSIBLE_DIR}/inventory/dev-generated.ini" ]]; then
  rm -f "${ANSIBLE_DIR}/inventory/dev-generated.ini"
  log "Removed dev-generated.ini"
fi

# Remove cached plan files
rm -f "${TF_DIR}/dev.tfplan"
rm -f "${TF_DIR}/dev-destroy.tfplan"

log "Local artifacts cleaned."

# =====================================================
# Phase 3: Verify no orphaned resources
# =====================================================
if [[ "${SKIP_VERIFY}" == "false" ]]; then
  log "=== Phase 3: Verify Resource Cleanup ==="

  cd "${REPO_ROOT}"

  # Count resources remaining in the resource group
  # Expected survivors: the resource group itself, the Terraform state storage account,
  # and its blob container. Everything else should be gone.
  RESOURCE_COUNT=$(az resource list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "length([?type != 'Microsoft.Storage/storageAccounts'])" \
    --output tsv 2>/dev/null || echo "UNKNOWN")

  if [[ "${RESOURCE_COUNT}" == "0" ]]; then
    log "PASS: No orphaned resources found (only storage account remains)."
  elif [[ "${RESOURCE_COUNT}" == "UNKNOWN" ]]; then
    log "WARN: Could not verify resource cleanup (az CLI auth may be required)."
    log "Run manually: az resource list --resource-group ${RESOURCE_GROUP} -o table"
  else
    log "WARN: ${RESOURCE_COUNT} non-storage resources remain in ${RESOURCE_GROUP}."
    log "Listing remaining resources:"
    az resource list \
      --resource-group "${RESOURCE_GROUP}" \
      --query "[?type != 'Microsoft.Storage/storageAccounts'].{Name:name, Type:type}" \
      --output table 2>/dev/null || true
    log "These may be orphaned. Investigate and remove manually if needed."
  fi
else
  log "Skipping verification (--skip-verify)"
fi

log "=== Dev environment teardown complete ==="
