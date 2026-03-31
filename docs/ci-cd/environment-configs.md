# Environment-Specific Configurations

This document explains how dev and production environment configurations are managed across Terraform, Ansible, and the Next.js webapp.

## Terraform Variable Files

Environment-specific values live in `terraform/environments/dev/terraform.<env>.tfvars`. Sensitive values (`subscription_id`, `ssh_public_key`) are left empty and must be supplied via CI/CD secrets or the `-var` flag.

| File | Environment | Resource Group |
|---|---|---|
| `terraform.dev.tfvars` | dev | `klc-rg-kafkalab-scus` |
| `terraform.prod.tfvars` | prod | `klc-rg-kafkalab-prod-scus` |

### Usage

```bash
# Dev
terraform plan -var-file=terraform.dev.tfvars \
  -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var="ssh_public_key=$SSH_PUBLIC_KEY"

# Production
terraform plan -var-file=terraform.prod.tfvars \
  -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var="ssh_public_key=$SSH_PUBLIC_KEY"
```

In CI/CD workflows the `-var` flags are replaced by environment variables or GitHub Actions secrets injected at runtime.

## Ansible Group Variables

Default values live in role-specific files under `ansible/group_vars/` (e.g., `kafka_broker.yml`, `zookeeper.yml`). Environment overrides are layered on top using environment-specific files:

| File | Purpose |
|---|---|
| `group_vars/env_dev.yml` | Lower heaps, single replica, relaxed timeouts, features off |
| `group_vars/env_production.yml` | Full replication, larger heaps, strict timeouts, all features on |

### How Overrides Work

Ansible merges variables with last-loaded-wins precedence. Add the environment file to your inventory or include it explicitly:

```bash
# Dev
ansible-playbook -i inventory/dev site.yml \
  -e @group_vars/env_dev.yml

# Production
ansible-playbook -i inventory/prod site.yml \
  -e @group_vars/env_production.yml
```

Alternatively, structure your inventory so that the `env_dev` or `env_production` group includes the target hosts, and Ansible loads the matching `group_vars/env_*.yml` automatically.

### Key Differences

| Variable | Dev | Production |
|---|---|---|
| `kafka_broker_heap_size` | 2g | 6g |
| `kafka_broker_default_replication_factor` | 1 | 3 |
| `kafka_broker_min_insync_replicas` | 1 | 2 |
| `kafka_broker_num_partitions` | 3 | 6 |
| `kafka_broker_log_retention_hours` | 48 | 168 |
| `zookeeper_heap_size` | 512m | 1g |
| `kafka_broker_security_enabled` | false | true |
| `kafka_broker_tiered_storage_enabled` | false | true |

## Next.js Environment Variables

The webapp uses Next.js environment files at `webapp/`. Variables prefixed with `NEXT_PUBLIC_` are exposed to the browser; all others are server-only.

### Files

| File | When Loaded | Tracked in Git |
|---|---|---|
| `.env.local` | Always (local overrides) | No |
| `.env.development` | `next dev` | Yes |
| `.env.production` | `next build` / `next start` | Yes |

### Expected Variables

```bash
# .env.development
NEXT_PUBLIC_ENV=development
NEXT_PUBLIC_API_URL=http://localhost:7071/api
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
KAFKA_USERNAME=placeholder
KAFKA_PASSWORD=placeholder

# .env.production
NEXT_PUBLIC_ENV=production
NEXT_PUBLIC_API_URL=https://kafka-lab-api.azurewebsites.net/api
KAFKA_BOOTSTRAP_SERVERS=  # Set via App Service configuration
KAFKA_USERNAME=           # Set via App Service configuration
KAFKA_PASSWORD=           # Set via App Service configuration
```

Server-only secrets (`KAFKA_USERNAME`, `KAFKA_PASSWORD`, `KAFKA_BOOTSTRAP_SERVERS`) are injected through Azure App Service application settings in production and never committed to source control.

### Local Development

Copy the example and fill in local values:

```bash
cp webapp/.env.local.example webapp/.env.local
# Edit .env.local with your local Kafka connection details
```
