#!/usr/bin/env bash
# deploy-dev.sh — Orchestrate dev environment deployment
# Usage: ./scripts/deploy-dev.sh [--plan-only] [--skip-terraform] [--skip-ansible] [--skip-verify]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/dev"
ANSIBLE_DIR="${REPO_ROOT}/ansible"
TFVARS_FILE="${TF_DIR}/terraform.dev.tfvars"

PLAN_ONLY=false
SKIP_TERRAFORM=false
SKIP_ANSIBLE=false
SKIP_VERIFY=false

for arg in "$@"; do
  case "${arg}" in
    --plan-only)      PLAN_ONLY=true ;;
    --skip-terraform) SKIP_TERRAFORM=true ;;
    --skip-ansible)   SKIP_ANSIBLE=true ;;
    --skip-verify)    SKIP_VERIFY=true ;;
    *)
      echo "Unknown option: ${arg}"
      echo "Usage: $0 [--plan-only] [--skip-terraform] [--skip-ansible] [--skip-verify]"
      exit 1
      ;;
  esac
done

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# Validate prerequisites
command -v terraform >/dev/null 2>&1 || { log "ERROR: terraform not found"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { log "ERROR: ansible-playbook not found"; exit 1; }

if [[ ! -f "${TFVARS_FILE}" ]]; then
  log "ERROR: ${TFVARS_FILE} not found"
  exit 1
fi

# =====================================================
# Phase 1: Terraform
# =====================================================
if [[ "${SKIP_TERRAFORM}" == "false" ]]; then
  log "=== Phase 1: Terraform ==="

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

  log "Running terraform validate..."
  terraform validate

  log "Running terraform plan..."
  terraform plan -var-file="${TFVARS_FILE}" -out=dev.tfplan

  if [[ "${PLAN_ONLY}" == "true" ]]; then
    log "Plan-only mode — stopping before apply."
    exit 0
  fi

  log "Running terraform apply..."
  terraform apply dev.tfplan

  log "Terraform apply complete."
  rm -f dev.tfplan
  cd "${REPO_ROOT}"
else
  log "Skipping Terraform (--skip-terraform)"
fi

# =====================================================
# Phase 2: Generate Ansible Inventory from Terraform
# =====================================================
if [[ "${SKIP_ANSIBLE}" == "false" ]]; then
  log "=== Phase 2: Generate Ansible Inventory ==="

  cd "${TF_DIR}"

  INVENTORY_FILE="${ANSIBLE_DIR}/inventory/dev-generated.ini"

  log "Extracting VM IPs from Terraform output..."
  ZK_IPS=$(terraform output -json zookeeper_private_ips 2>/dev/null || echo '{}')
  KB_IPS=$(terraform output -json kafka_broker_private_ips 2>/dev/null || echo '{}')
  SR_IPS=$(terraform output -json schema_registry_private_ips 2>/dev/null || echo '{}')
  KC_IPS=$(terraform output -json kafka_connect_private_ips 2>/dev/null || echo '{}')

  cat > "${INVENTORY_FILE}" <<INVENTORY
# Auto-generated from Terraform output — do not edit manually
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

[zookeeper]
INVENTORY

  echo "${ZK_IPS}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, ip in sorted(data.items()):
    short = name.replace('klc-vm-', '').replace('-scus', '')
    print(f'{short} ansible_host={ip}')
" >> "${INVENTORY_FILE}"

  echo -e "\n[kafka_broker]" >> "${INVENTORY_FILE}"
  echo "${KB_IPS}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, ip in sorted(data.items()):
    short = name.replace('klc-vm-', '').replace('-scus', '')
    print(f'{short} ansible_host={ip}')
" >> "${INVENTORY_FILE}"

  echo -e "\n[schema_registry]" >> "${INVENTORY_FILE}"
  echo "${SR_IPS}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, ip in sorted(data.items()):
    short = name.replace('klc-vm-', '').replace('-scus', '')
    print(f'{short} ansible_host={ip}')
" >> "${INVENTORY_FILE}"

  echo -e "\n[kafka_connect]" >> "${INVENTORY_FILE}"
  echo "${KC_IPS}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, ip in sorted(data.items()):
    short = name.replace('klc-vm-', '').replace('-scus', '')
    print(f'{short} ansible_host={ip}')
" >> "${INVENTORY_FILE}"

  cat >> "${INVENTORY_FILE}" <<INVENTORY

[env_dev:children]
zookeeper
kafka_broker
schema_registry
kafka_connect

[southcentralus:children]
zookeeper
kafka_broker
schema_registry
kafka_connect

[all:vars]
ansible_user=azureuser
ansible_python_interpreter=/usr/bin/python3
INVENTORY

  log "Generated inventory at ${INVENTORY_FILE}"

  # =====================================================
  # Phase 3: Ansible Provisioning
  # =====================================================
  log "=== Phase 3: Ansible Provisioning ==="

  cd "${ANSIBLE_DIR}"

  INVENTORY_ARG="${INVENTORY_FILE}"

  log "Running site.yml playbook..."
  ansible-playbook site.yml \
    -i "${INVENTORY_ARG}" \
    -e "@group_vars/env_dev.yml" \
    --diff

  log "Running client-credentials playbook..."
  ansible-playbook playbooks/client-credentials.yml \
    -i "${INVENTORY_ARG}" \
    -e "@group_vars/env_dev.yml" \
    --diff

  log "Running create-topics playbook..."
  ansible-playbook playbooks/create-topics.yml \
    -i "${INVENTORY_ARG}" \
    -e "@group_vars/env_dev.yml" \
    --diff

  log "Running register-schemas playbook..."
  ansible-playbook playbooks/register-schemas.yml \
    -i "${INVENTORY_ARG}" \
    -e "@group_vars/env_dev.yml" \
    --diff

  log "Ansible provisioning complete."
  cd "${REPO_ROOT}"
else
  log "Skipping Ansible (--skip-ansible)"
fi

# =====================================================
# Phase 4: Verification
# =====================================================
if [[ "${SKIP_VERIFY}" == "false" && "${SKIP_ANSIBLE}" == "false" ]]; then
  log "=== Phase 4: Verification ==="

  cd "${ANSIBLE_DIR}"

  INVENTORY_ARG="${ANSIBLE_DIR}/inventory/dev-generated.ini"
  if [[ ! -f "${INVENTORY_ARG}" ]]; then
    INVENTORY_ARG="${ANSIBLE_DIR}/inventory/dev-static.ini"
  fi

  log "Running dev verification playbook..."
  ansible-playbook playbooks/verify-dev.yml \
    -i "${INVENTORY_ARG}" \
    -e "@group_vars/env_dev.yml" \
    --diff

  log "=== Dev environment deployment complete ==="
  cd "${REPO_ROOT}"
elif [[ "${SKIP_VERIFY}" == "true" ]]; then
  log "Skipping verification (--skip-verify)"
fi
