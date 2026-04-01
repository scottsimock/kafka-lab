#!/usr/bin/env bash
# bootstrap-tfstate.sh — Create the Terraform state storage account
#
# Run this once before any Terraform deployment. Idempotent — safe to re-run.
# Creates the storage account and blob container in klc-rg-kafkalab-scus.
#
# Usage: ./scripts/bootstrap-tfstate.sh
set -euo pipefail

RESOURCE_GROUP="${BACKEND_RESOURCE_GROUP:-klc-rg-kafkalab-scus}"
STORAGE_ACCOUNT="${BACKEND_STORAGE_ACCOUNT:-klcstgtfstatescus}"
CONTAINER="${BACKEND_CONTAINER:-tfstate}"
LOCATION="southcentralus"
SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-}"

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] $*"; }

command -v az >/dev/null 2>&1 || { log "ERROR: az CLI not found"; exit 1; }

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
  log "Using subscription from az account: ${SUBSCRIPTION_ID}"
fi

# Create storage account (idempotent — no-ops if it exists)
if az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" &>/dev/null; then
  log "Storage account '${STORAGE_ACCOUNT}' already exists"
else
  log "Creating storage account '${STORAGE_ACCOUNT}' in ${RESOURCE_GROUP}..."
  az storage account create \
    --name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --subscription "${SUBSCRIPTION_ID}" \
    --output none
  log "Storage account created"
fi

# Create blob container (idempotent)
if az storage container show --name "${CONTAINER}" --account-name "${STORAGE_ACCOUNT}" --auth-mode login &>/dev/null; then
  log "Container '${CONTAINER}' already exists"
else
  log "Creating container '${CONTAINER}'..."
  az storage container create \
    --name "${CONTAINER}" \
    --account-name "${STORAGE_ACCOUNT}" \
    --auth-mode login \
    --output none
  log "Container created"
fi

log "=== Terraform state backend ready ==="
log "  Storage Account: ${STORAGE_ACCOUNT}"
log "  Container:       ${CONTAINER}"
log "  Resource Group:  ${RESOURCE_GROUP}"
log "  Subscription:    ${SUBSCRIPTION_ID}"
