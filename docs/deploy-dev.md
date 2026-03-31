# Deploying the Dev Environment

This guide covers deploying the kafka-lab dev environment to Azure (southcentralus, Zone 1).

## Prerequisites

- Azure subscription with `klc-rg-kafkalab-scus` resource group
- Terraform >= 1.6.0 with AzAPI provider
- Ansible >= 2.14 with `azure.azcollection` >= 2.0.0
- Azure CLI authenticated (`az login`)
- SSH key pair for VM access
- Network connectivity to the VNet (VPN, bastion, or self-hosted runner)

## Architecture

Single-region deployment in **southcentralus Zone 1**:

| Component | Count | VM Size | Subnet |
|---|---|---|---|
| ZooKeeper | 3 | Standard_D2s_v5 | 10.1.2.0/24 |
| Kafka Brokers | 3 | Standard_D4s_v5 | 10.1.1.0/24 |
| Schema Registry | 1 | Standard_D2s_v5 | 10.1.3.0/24 |
| Kafka Connect | 1 | Standard_D2s_v5 | 10.1.4.0/24 |
| Function App | 1 | EP1 (Premium) | 10.1.5.0/24 |

All resources use private networking — no public endpoints except the web app ingress.

## Quick Start

```bash
# Full deployment: terraform → ansible → verification
./scripts/deploy-dev.sh

# Plan only (no apply)
./scripts/deploy-dev.sh --plan-only

# Skip terraform (ansible + verify only)
./scripts/deploy-dev.sh --skip-terraform

# Skip ansible (terraform only)
./scripts/deploy-dev.sh --skip-ansible
```

## Step-by-Step Deployment

### 1. Configure Terraform Backend

```bash
cd terraform/environments/dev
cp backend.tfvars.example backend.tfvars
# Edit backend.tfvars with your subscription ID and storage account
```

### 2. Configure Terraform Variables

Edit `terraform.dev.tfvars`:

```hcl
subscription_id     = "YOUR_SUBSCRIPTION_ID"
environment         = "dev"
primary_location    = "southcentralus"
resource_group_name = "klc-rg-kafkalab-scus"
ssh_public_key      = "ssh-rsa AAAA..."
```

Or pass sensitive values via CLI:

```bash
terraform plan \
  -var-file=terraform.dev.tfvars \
  -var="subscription_id=xxx" \
  -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

### 3. Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init -backend-config=backend.tfvars
terraform plan -var-file=terraform.dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan
```

### 4. Run Ansible Provisioning

The deployment script auto-generates inventory from Terraform outputs. For manual runs:

```bash
cd ansible

# Use static inventory (known IPs)
ansible-playbook site.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml" \
  --diff

# Post-provisioning
ansible-playbook playbooks/client-credentials.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml"

ansible-playbook playbooks/create-topics.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml"

ansible-playbook playbooks/register-schemas.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml"
```

### 5. Verify Deployment

```bash
cd ansible
ansible-playbook playbooks/verify-dev.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml"
```

Verification checks:

- ZooKeeper ensemble: `ruok` → `imok` on all 3 nodes
- Kafka brokers: API connectivity, topic creation (RF=3)
- Message produce/consume: PLAINTEXT end-to-end flow
- Schema Registry: subjects and config endpoints responding
- Kafka Connect: root and connector-plugins endpoints responding

## E2E Environment Validation

Beyond the basic verification playbook, a comprehensive E2E validation suite checks every layer of the stack and produces a structured health report.

### Quick Validation

```bash
# Full E2E validation (requires SSH access to VMs)
./scripts/validate-dev-environment.sh

# Extract IPs from Terraform outputs automatically
./scripts/validate-dev-environment.sh --from-terraform

# Skip data flow and webapp checks (infra only)
./scripts/validate-dev-environment.sh --skip-data-flow --skip-webapp

# Custom SSH options (e.g., via bastion)
./scripts/validate-dev-environment.sh --ssh-opts="-o ProxyJump=bastion"
```

### Ansible Alternative

```bash
cd ansible
ansible-playbook playbooks/validate-e2e.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml"

# With Function App validation
ansible-playbook playbooks/validate-e2e.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml" \
  -e "function_app_host=klc-func-kafkalab-dev-scus.azurewebsites.net"

# Skip data flow test
ansible-playbook playbooks/validate-e2e.yml \
  -i inventory/dev-static.ini \
  -e "@group_vars/env_dev.yml" \
  -e "skip_data_flow=true"
```

### What Gets Checked

The validation runs 8 phases in dependency order:

| Phase | Component | Checks |
|---|---|---|
| 1 | VMs | SSH reachability for all 8 VMs |
| 2 | ZooKeeper | `ruok` response, mode (leader/follower), ensemble quorum |
| 3 | Kafka | Broker API, ISR count, controller election, under-replicated partitions |
| 4 | Schema Registry | `/subjects` endpoint, `/config` endpoint |
| 5 | Kafka Connect | Root endpoint, connector plugins list |
| 6 | Function App | Health endpoint, page load |
| 7 | Web App | Dashboard pages (overview, topics, schemas) |
| 8 | Data Flow | Produce message, consume message, round-trip verification |

### Health Report

Both tools output a JSON report to `logs/dev-environment-health.json`:

```json
{
  "timestamp": "2026-03-31T22:30:00Z",
  "environment": "dev",
  "overall_status": "PASS",
  "duration_seconds": 45,
  "checks": [
    {"component": "vm-zk-10.1.2.4", "check": "ssh-reachable", "status": "PASS", "duration_ms": 230},
    {"component": "kafka-cluster", "check": "brokers-in-isr", "status": "PASS", "details": "3/3 brokers"},
    {"component": "data-flow", "check": "round-trip", "status": "PASS", "details": "message verified"}
  ],
  "summary": {"total": 25, "passed": 25, "failed": 0, "skipped": 0}
}
```

### Interpreting Results

- **PASS** — All critical checks succeeded. Environment is healthy.
- **FAIL** — One or more checks failed. Review `logs/dev-environment-health.json` for details. Failures cascade — if VMs are unreachable, all downstream checks will also fail.
- **SKIP** — Checks skipped by flag or missing configuration (e.g., no Function App hostname).

Fix failures in dependency order: VMs → ZooKeeper → Kafka → Schema Registry → Connect → Function App.

### Environment Variables

Override default IPs when not using `--from-terraform`:

| Variable | Default | Description |
|---|---|---|
| `ZK_HOSTS` | `10.1.2.4,10.1.2.5,10.1.2.6` | ZooKeeper IPs |
| `KB_HOSTS` | `10.1.1.4,10.1.1.5,10.1.1.6` | Kafka broker IPs |
| `SR_HOSTS` | `10.1.3.4` | Schema Registry IPs |
| `KC_HOSTS` | `10.1.4.4` | Kafka Connect IPs |
| `FUNCTION_APP_HOST` | _(empty)_ | Function App hostname |

## GitHub Actions Deployment

Use the `deploy-all.yml` workflow for CI/CD:

```yaml
# Manual trigger
workflow_dispatch:
  inputs:
    environment: dev
    component: all
    terraform_action: apply
    dry_run: false
```

The workflow runs:

1. `terraform-deploy.yml` — plan + apply with OIDC auth
2. `ansible-deploy.yml` — playbook execution via self-hosted runner
3. `webapp-deploy.yml` — Function App package deployment

## Inventory Options

| Inventory | Use Case | Auth |
|---|---|---|
| `inventory/dev-static.ini` | Local dev, known IPs | SSH key |
| `inventory/dev-generated.ini` | Auto-generated by deploy script | SSH key |
| `inventory/azure_rm.yml` | Dynamic Azure RM | MSI (self-hosted runner) |

## Dev Environment Specifics

Dev relaxes some production settings for faster iteration:

- **Security disabled**: `kafka_broker_security_enabled: false` (no SASL_SSL)
- **ACLs disabled**: `kafka_broker_acl_enabled: false`
- **Replication**: `default_replication_factor: 1`, `min_insync_replicas: 1`
- **Tiered storage**: disabled
- **Self-balancing**: disabled
- **Log retention**: 48 hours (vs 168 in production)

## Troubleshooting

### Cannot SSH to VMs

All VMs are on private IPs. You need VNet connectivity via:

- Azure Bastion in the management subnet
- VPN gateway
- Self-hosted runner inside the VNet

### Terraform state lock

```bash
terraform force-unlock LOCK_ID
```

### Ansible connection timeout

Check that your SSH key matches `ssh_public_key` in tfvars and that the VMs are running:

```bash
az vm list -g klc-rg-kafkalab-scus -o table --query "[].{Name:name, State:powerState}"
```

### Schema Registry not responding

ZooKeeper and Kafka must be healthy first. Run verification in order:

```bash
ansible-playbook playbooks/verify-dev.yml -i inventory/dev-static.ini -e "@group_vars/env_dev.yml"
```

## Teardown and Recreate

The dev environment can be fully destroyed and recreated to manage Azure costs.
The infrastructure is 100% reproducible from Terraform state + Ansible playbooks.

### Cost Estimation

| State | Resources | Est. Cost/Day |
|---|---|---|
| **Running** | 8 VMs, Function App, Key Vault, VNet, NSGs, PEs, Disks | **~$45–55** |
| **Destroyed** | Terraform state storage account only | **~$0.10** |

Running cost breakdown:

| Resource | SKU | Count | Est. $/day |
|---|---|---|---|
| ZooKeeper VMs | Standard_D2s_v5 | 3 | $8.28 |
| Kafka Broker VMs | Standard_D4s_v5 | 3 | $16.56 |
| Schema Registry VM | Standard_D2s_v5 | 1 | $2.76 |
| Kafka Connect VM | Standard_D2s_v5 | 1 | $2.76 |
| Function App | EP1 (Elastic Premium) | 1 | $5.00 |
| Managed Disks | Premium SSD P10 | 8 | $3.28 |
| Key Vault | Standard | 1 | $0.30 |
| Networking | VNet, NSGs, Private Endpoints | — | $2.50 |

Savings examples:

- **Weekend teardown** (Fri 6pm → Mon 8am): ~$110–140 saved
- **Nightly teardown** (6pm → 8am weekdays + weekends): ~$270–330/week saved

### When to Teardown

- **End of day** — no active development overnight
- **Weekends** — no sprint work planned
- **Between sprints** — environment not needed during planning
- **Cost pressure** — reduce Azure spend during low-activity periods

### How to Teardown

**Option 1: GitHub Actions (recommended)**

Go to **Actions → Dev Teardown → Run workflow**. The workflow:

1. Plans and applies `terraform destroy` for all dev resources
2. Verifies no orphaned resources remain in `klc-rg-kafkalab-scus`
3. Posts cost estimation summary

Inputs:

- `plan_only` — Preview what will be destroyed without applying
- `skip_estimation` — Skip the cost summary step

**Option 2: Script**

```bash
# Interactive — prompts for confirmation
./scripts/teardown-dev.sh

# Non-interactive (CI/CD)
./scripts/teardown-dev.sh --confirm

# Preview what will be destroyed
./scripts/teardown-dev.sh --plan-only
```

### How to Recreate

**Option 1: GitHub Actions (recommended)**

Go to **Actions → Dev Recreate → Run workflow**. The workflow runs the full pipeline:

1. `terraform apply` — provisions all Azure infrastructure
2. `ansible site.yml` — configures VMs (ZooKeeper, Kafka, Schema Registry, Connect)
3. Post-provisioning playbooks (client-credentials, create-topics, register-schemas)
4. Web application deployment to Function App
5. Verification playbook confirms all services are healthy

Inputs:

- `skip_ansible` — Terraform only (useful for debugging infra changes)
- `skip_verify` — Skip post-deploy verification
- `skip_estimation` — Skip cost summary

**Option 2: Script**

```bash
# Full deployment from scratch
./scripts/deploy-dev.sh

# Terraform only
./scripts/deploy-dev.sh --skip-ansible
```

### What Persists vs. What's Destroyed

| Component | Teardown Behavior |
|---|---|
| Resource Group | **Persists** — container is never deleted |
| Terraform State Storage | **Persists** — backend for state files |
| Terraform State | **Persists** — stored in Azure Storage, tracks empty state |
| VMs (all roles) | **Destroyed** — recreated from scratch |
| Managed Disks | **Destroyed** — Kafka data, ZK data lost |
| Function App + Plan | **Destroyed** — redeployed with webapp |
| Key Vault | **Destroyed** — secrets recreated by Ansible |
| VNet, Subnets, NSGs | **Destroyed** — recreated by Terraform |
| Private Endpoints | **Destroyed** — recreated by Terraform |
| Private DNS Zones | **Destroyed** — recreated by Terraform |
| Kafka Topics | **Destroyed** — recreated by create-topics playbook |
| Schema Registry Schemas | **Destroyed** — recreated by register-schemas playbook |

> **Note:** All application state (topics, messages, schemas, consumer offsets) is lost
> on teardown. This is acceptable for dev — the recreate pipeline restores baseline
> topics and schemas automatically.
