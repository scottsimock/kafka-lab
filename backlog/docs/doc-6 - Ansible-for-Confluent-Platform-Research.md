---
id: doc-6
title: Ansible for Confluent Platform Research
type: other
created_date: '2026-03-28 18:24'
---
# Ansible for Confluent Platform Research

## Summary

The `confluent.platform` Ansible collection (cp-ansible) is the official automation tool for deploying Confluent Platform 7.x. It provides dedicated roles for every component — including ZooKeeper, Kafka brokers, Schema Registry, and Kafka Connect — with full support for ZooKeeper-based architectures. For the Kafka Lab's multi-region Azure deployment (southcentralus, mexicocentral, canadaeast), cp-ansible's variable-driven, Jinja2-templated approach combined with per-region inventory directories provides a proven pattern for managing three independent clusters with shared configuration baselines.

## Key Findings

### cp-ansible Collection Capabilities

- Distributed as `confluent.platform` on Ansible Galaxy since Confluent Platform 7.0; install via `ansible-galaxy collection install confluent.platform`
- **ZooKeeper-based deployments are fully supported in 7.x** — use the `zookeeper` and `kafka_broker` roles together (KRaft mode uses `kafka_controller` + `kafka_broker` instead)
- Provides roles for all target components: `zookeeper`, `kafka_broker`, `schema_registry`, `kafka_connect`, plus `kafka_rest`, `control_center`, `ksql`, and `kafka_connect_replicator`
- Supports both package-based (APT/YUM) and archive-based installation methods
- Built-in support for TLS (self-signed and custom certificates), SASL (PLAIN, SCRAM), RBAC, and mTLS
- Configuration is entirely variable-driven — all properties files are generated from Jinja2 templates at `roles/<component>/templates/`

### Inventory Structure for Multi-Region

- cp-ansible uses standard Ansible inventory groups: `zookeeper`, `kafka_broker`, `schema_registry`, `kafka_connect`, etc.
- For multi-region, the recommended pattern is **per-region inventory directories**, each with their own `hosts.yml` and `group_vars/`
- A shared `global_group_vars/all.yml` holds cross-region settings (CP version, security baseline, common properties)
- Each region's `group_vars/all.yml` sets region-specific overrides (listeners, `broker.rack`, cluster ID)
- Playbooks are run per-region with `-i inventory/<region>/` to target a single cluster

### Idempotent Service Management

- All roles use Ansible's `systemd` module for service lifecycle (start, stop, enable, restart)
- Handlers trigger restarts only when configuration files actually change — repeated runs are safe
- Service dependency ordering is enforced: ZooKeeper starts before Kafka brokers, brokers before Schema Registry, etc.
- Configuration files are generated from Jinja2 templates (`zookeeper.properties.j2`, `server.properties.j2`, etc.), ensuring declarative, drift-free management
- Custom properties are injected via `kafka_broker_custom_properties`, `schema_registry_custom_properties`, etc.

### Variable Hierarchy and Precedence

Standard Ansible precedence applies within cp-ansible (lowest to highest):

| Level | Example | Scope |
|---|---|---|
| Role defaults | `roles/kafka_broker/defaults/main.yml` | Collection defaults |
| `group_vars/all.yml` | Global platform settings | All hosts |
| `group_vars/<component>.yml` | `group_vars/kafka_broker.yml` | Component group |
| `host_vars/<host>.yml` | `host_vars/broker01.yml` | Single host |
| Extra vars (`-e`) | CLI override | Highest precedence |

### Ansible Vault for Secrets

- All credentials (SASL passwords, keystore/truststore passwords, TLS private keys) must be encrypted with Ansible Vault
- Recommended pattern: separate `vault.yml` files alongside `vars.yml` in group_vars, with vault-prefixed variable names (`vault_kafka_keystore_password`) referenced from vars (`kafka_keystore_password: "{{ vault_kafka_keystore_password }}"`)
- Use `no_log: true` on tasks that handle sensitive data
- TLS certificates can be distributed via the `copy_files` mechanism in inventory or pre-staged to hosts

### Terraform-to-Ansible Handoff

Three viable patterns for passing Azure VM private IPs from Terraform to Ansible:

1. **Terraform `local_file` resource** (recommended for Kafka Lab): Terraform generates a YAML inventory file from VM outputs using a template, written to a known path. GitHub Actions picks up the file and passes it to `ansible-playbook -i`.
2. **`cloud.terraform.terraform_provider` dynamic inventory plugin**: Ansible reads Terraform state directly. Requires `ansible_host` Terraform resources. Strongest for environments with frequent infra churn.
3. **Azure `azure_rm` dynamic inventory plugin**: Queries Azure ARM directly. Uses VM tags (e.g., `role=kafka_broker`, `region=southcentralus`) and `keyed_groups` for automatic group assignment. Independent of Terraform state.

### Azure Dynamic Inventory (azure.azcollection)

- The `azure.azcollection.azure_rm` inventory plugin queries Azure Resource Manager for VMs
- Filter scope with `include_vm_resource_groups` to limit to the Kafka Lab resource group
- Use `keyed_groups` on VM tags for automatic group membership (e.g., tag `cp_role: kafka_broker` maps to the `kafka_broker` group)
- Authentication via managed identity, service principal, or Azure CLI (`auth_source: auto`)
- Can be combined with Terraform tagging strategy for seamless discovery

## Architecture / Design Decisions

### Decision 1: Per-Region Inventory Directories

**Decision:** Use separate inventory directories per region (`inventory/southcentralus/`, `inventory/mexicocentral/`, `inventory/canadaeast/`) rather than a single flat inventory.

**Rationale:** Each region is an independent Confluent cluster with its own ZooKeeper ensemble and broker set. Per-region directories provide clean separation, independent deployability (deploy one region without touching others), and clear variable scoping. This aligns with cp-ansible's documented multi-environment pattern.

### Decision 2: Terraform local_file for Inventory Generation

**Decision:** Use Terraform's `local_file` resource to generate per-region YAML inventory files from VM outputs, rather than Azure dynamic inventory or the cloud.terraform plugin.

**Rationale:** The Kafka Lab infrastructure is relatively static (fixed VM counts per region). Generating inventory at `terraform apply` time eliminates runtime Azure API dependencies during Ansible runs, keeps the inventory auditable in CI artifacts, and avoids the complexity of the `cloud.terraform` plugin. The generated inventory is passed as a CI artifact to the Ansible stage in GitHub Actions.

### Decision 3: ZooKeeper-Based Architecture

**Decision:** Deploy with `zookeeper` + `kafka_broker` roles, not KRaft mode.

**Rationale:** The project requirement specifies ZooKeeper-based Confluent Platform 7.x. cp-ansible fully supports this configuration. KRaft migration can be considered as a future task.

### Decision 4: Ansible Vault for All Secrets

**Decision:** Use Ansible Vault for encrypting all credentials, with the vault password injected as a GitHub Actions secret.

**Rationale:** Ansible Vault is natively supported by cp-ansible's security roles and integrates cleanly with GitHub Actions (`--vault-password-file` pointing to a file written from `${{ secrets.ANSIBLE_VAULT_PASSWORD }}`). No external secrets manager dependency is required for the initial deployment.

### Decision 5: VM Tags as Group Membership Source

**Decision:** Terraform applies standardized tags to all VMs (`cp_role`, `cp_region`, `cp_cluster`) that align with cp-ansible inventory group names.

**Rationale:** Whether using generated inventory or dynamic inventory, consistent tagging provides a single source of truth for role assignment. Tags also support Azure-native monitoring and cost allocation.

## Configuration Reference

### Directory Structure

```text
ansible/
├── ansible.cfg
├── requirements.yml                  # Collection dependencies
├── playbooks/
│   ├── site.yml                      # Full cluster deployment
│   ├── zookeeper.yml                 # ZooKeeper only
│   ├── kafka_broker.yml              # Kafka brokers only
│   ├── schema_registry.yml           # Schema Registry only
│   └── kafka_connect.yml             # Kafka Connect only
├── inventory/
│   ├── global_group_vars/
│   │   └── all.yml                   # Cross-region defaults
│   ├── southcentralus/
│   │   ├── hosts.yml                 # Generated by Terraform
│   │   └── group_vars/
│   │       ├── all.yml               # Region-specific overrides
│   │       ├── all/
│   │       │   ├── vars.yml
│   │       │   └── vault.yml         # Encrypted secrets
│   │       ├── zookeeper.yml
│   │       └── kafka_broker.yml
│   ├── mexicocentral/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       ├── all.yml
│   │       ├── all/
│   │       │   ├── vars.yml
│   │       │   └── vault.yml
│   │       ├── zookeeper.yml
│   │       └── kafka_broker.yml
│   └── canadaeast/
│       ├── hosts.yml
│       └── group_vars/
│           ├── all.yml
│           ├── all/
│           │   ├── vars.yml
│           │   └── vault.yml
│           ├── zookeeper.yml
│           └── kafka_broker.yml
└── files/
    └── certs/                        # TLS certificates (vault-encrypted)
```

### requirements.yml

```yaml
collections:
  - name: confluent.platform
    version: '>=7.7.0'
  - name: azure.azcollection
    version: '>=3.0.0'
  - name: cloud.terraform
    version: '>=2.0.0'
```

### Example hosts.yml (southcentralus — Terraform-generated)

```yaml
all:
  children:
    zookeeper:
      hosts:
        kl-vm-zk-scus-01:
          ansible_host: 10.1.0.4
          zookeeper_id: 1
        kl-vm-zk-scus-02:
          ansible_host: 10.1.0.5
          zookeeper_id: 2
        kl-vm-zk-scus-03:
          ansible_host: 10.1.0.6
          zookeeper_id: 3
    kafka_broker:
      hosts:
        kl-vm-kb-scus-01:
          ansible_host: 10.1.1.4
          broker_id: 1
        kl-vm-kb-scus-02:
          ansible_host: 10.1.1.5
          broker_id: 2
        kl-vm-kb-scus-03:
          ansible_host: 10.1.1.6
          broker_id: 3
    schema_registry:
      hosts:
        kl-vm-sr-scus-01:
          ansible_host: 10.1.2.4
    kafka_connect:
      hosts:
        kl-vm-kc-scus-01:
          ansible_host: 10.1.3.4
```

### global_group_vars/all.yml (Shared Across Regions)

```yaml
# Confluent Platform version
confluent_package_version: '7.7'
confluent_repo_version: 7.7

# Installation method
installation_method: 'package'

# OS user
confluent_common_user: 'cp-kafka'
confluent_common_group: 'confluent'

# SSH configuration
ansible_user: 'azureuser'
ansible_become: true
ansible_ssh_private_key_file: '~/.ssh/kafka_lab_key'

# TLS — enable across all components
ssl_enabled: true
ssl_mutual_auth_enabled: false

# SASL authentication
sasl_protocol: 'scram'

# Common Kafka properties
kafka_broker_custom_properties:
  auto.create.topics.enable: 'false'
  default.replication.factor: 3
  min.insync.replicas: 2
  log.retention.hours: 168
  message.max.bytes: 1048576
```

### inventory/southcentralus/group_vars/all.yml (Region Overrides)

```yaml
# Region identification
kafka_lab_region: 'southcentralus'
kafka_lab_cluster_role: 'primary'

# Listeners — advertise private IPs within VNet
kafka_broker_custom_properties:
  broker.rack: 'southcentralus'
  confluent.cluster.link.enable: 'true'
```

### inventory/southcentralus/group_vars/kafka_broker.yml

```yaml
kafka_broker_custom_properties:
  broker.rack: 'southcentralus-az1'
  log.dirs: '/data/kafka-logs'
  num.io.threads: 16
  num.network.threads: 8
  num.partitions: 6
```

### inventory/southcentralus/group_vars/all/vault.yml (Encrypted)

```yaml
# Encrypt with: ansible-vault encrypt vault.yml
vault_kafka_keystore_password: '<encrypted>'
vault_kafka_truststore_password: '<encrypted>'
vault_sasl_scram_password: '<encrypted>'
vault_schema_registry_password: '<encrypted>'
```

### Playbook: site.yml (Full Cluster Deployment)

```yaml
- name: Deploy ZooKeeper ensemble
  hosts: zookeeper
  gather_facts: true
  roles:
    - confluent.platform.zookeeper

- name: Deploy Kafka brokers
  hosts: kafka_broker
  gather_facts: true
  roles:
    - confluent.platform.kafka_broker

- name: Deploy Schema Registry
  hosts: schema_registry
  gather_facts: true
  roles:
    - confluent.platform.schema_registry

- name: Deploy Kafka Connect
  hosts: kafka_connect
  gather_facts: true
  roles:
    - confluent.platform.kafka_connect
```

### Terraform Inventory Generation (HCL Snippet)

```hcl
resource "local_file" "ansible_inventory" {
  for_each = toset(["southcentralus", "mexicocentral", "canadaeast"])

  filename = "${path.module}/../ansible/inventory/${each.key}/hosts.yml"
  content = templatefile("${path.module}/templates/ansible-inventory.yml.tftpl", {
    zookeeper_hosts = [
      for vm in azurerm_linux_virtual_machine.zookeeper[each.key] : {
        name       = vm.name
        private_ip = vm.private_ip_address
        id         = index(azurerm_linux_virtual_machine.zookeeper[each.key], vm) + 1
      }
    ]
    broker_hosts = [
      for vm in azurerm_linux_virtual_machine.kafka_broker[each.key] : {
        name       = vm.name
        private_ip = vm.private_ip_address
        id         = index(azurerm_linux_virtual_machine.kafka_broker[each.key], vm) + 1
      }
    ]
  })
}
```

### Azure Dynamic Inventory Alternative (azure_rm.yml)

```yaml
plugin: azure.azcollection.azure_rm
auth_source: auto
include_vm_resource_groups:
  - 'klc-rg-kafkalab-scus'
keyed_groups:
  - key: tags.cp_role
    prefix: ''
    separator: ''
  - key: tags.cp_region
    prefix: 'region'
    separator: '_'
hostvar_expressions:
  ansible_host: private_ipv4_addresses[0]
```

### GitHub Actions Integration Pattern

```yaml
# In .github/workflows/deploy-confluent.yml
- name: Install Ansible collections
  run: ansible-galaxy collection install -r ansible/requirements.yml

- name: Write vault password
  run: echo "${{ secrets.ANSIBLE_VAULT_PASSWORD }}" > .vault_pass
  shell: bash

- name: Deploy Confluent Platform (southcentralus)
  run: |
    ansible-playbook \
      -i ansible/inventory/southcentralus/hosts.yml \
      ansible/playbooks/site.yml \
      --vault-password-file .vault_pass
  env:
    ANSIBLE_CONFIG: ansible/ansible.cfg
```

## Risks and Open Questions

### Risks

1. **Cross-region network latency**: Cluster Linking or Replicator between regions depends on VNet peering latency. Ansible can configure it, but network topology must be validated at the Terraform layer.
2. **Secrets rotation**: Ansible Vault covers initial deployment, but ongoing credential rotation (TLS cert renewal, SASL password changes) requires a separate operational workflow — possibly a dedicated playbook with rolling restart logic.
3. **cp-ansible version coupling**: The `confluent.platform` collection version must match the target Confluent Platform version. Collection upgrades should be tested in a non-production region first.
4. **Inventory drift**: If Terraform-generated inventory files are not regenerated after infrastructure changes, Ansible may target stale hosts. The CI pipeline must enforce inventory regeneration on every `terraform apply`.

### Open Questions

1. **Managed identity for Ansible SSH**: Can Azure UAMI-based SSH authentication replace SSH key pairs for the Ansible control node connecting to VMs? This would align with the project's managed identity mandate.
2. **DR region (canadaeast) passive mode**: How should cp-ansible handle a passive/standby cluster? Options include deploying identical configs with Cluster Linking consumers disabled, or having a separate "activate DR" playbook.
3. **Rolling upgrades**: Does cp-ansible support zero-downtime rolling upgrades of Confluent Platform? The collection documentation suggests it does, but this needs validation for the specific ZooKeeper-based 7.x topology.
4. **Custom Ansible modules**: Are there custom cp-ansible modules for topic creation, ACL management, or connector deployment — or should these use the Confluent CLI / REST API via `ansible.builtin.uri`?
5. **Terraform state backend**: The `cloud.terraform` inventory plugin requires access to Terraform state. If using remote state (Azure Storage), the Ansible control node needs storage account credentials — evaluate if this adds unacceptable complexity vs. generated inventory files.

## References

- [Confluent Ansible Overview (Official)](https://docs.confluent.io/ansible/current/overview.html)
- [Confluent Ansible Configuration Guide](https://docs.confluent.io/ansible/current/ansible-configure-overview.html)
- [Confluent Ansible Encryption (TLS)](https://docs.confluent.io/ansible/current/ansible-encrypt.html)
- [Confluent Ansible Authentication](https://docs.confluent.io/ansible/current/ansible-authenticate.html)
- [Confluent Ansible Authorization (RBAC)](https://docs.confluent.io/ansible/current/ansible-authorize.html)
- [Confluent Ansible Advanced Deployments](https://docs.confluent.io/ansible/current/ansible-adv-deployments.html)
- [Confluent Ansible Inventory Preparation](https://docs.confluent.io/ansible/current/ansible-prepare.html)
- [cp-ansible GitHub Repository](https://github.com/confluentinc/cp-ansible)
- [confluent.platform on Ansible Galaxy](https://galaxy.ansible.com/ui/repo/published/confluent/platform/docs/)
- [cp-ansible DeepWiki — Overview](https://deepwiki.com/confluentinc/cp-ansible/1-overview)
- [cp-ansible DeepWiki — Component Deployment](https://deepwiki.com/confluentinc/cp-ansible/5-component-deployment)
- [cp-ansible DeepWiki — Variables Reference](https://deepwiki.com/confluentinc/cp-ansible/3-variables-reference)
- [cp-ansible DeepWiki — Multi-Environment Deployments](https://deepwiki.com/confluentinc/cp-ansible/6.3-multi-environment-deployments)
- [cp-ansible DeepWiki — TLS/SSL Configuration](https://deepwiki.com/confluentinc/cp-ansible/4.1-tlsssl-configuration)
- [azure.azcollection.azure_rm Inventory Plugin (Ansible Docs)](https://docs.ansible.com/projects/ansible/latest/collections/azure/azcollection/azure_rm_inventory.html)
- [Azure Dynamic Inventory Tutorial (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/developer/ansible/dynamic-inventory-configure)
- [Ansible Variable Precedence (Official)](https://docs.ansible.com/projects/ansible/latest/reference_appendices/general_precedence.html)
- [Ansible Vault Guide (Official)](https://docs.ansible.com/projects/ansible/latest/vault_guide/vault.html)
- [cloud.terraform Ansible Collection](https://mdawar.dev/blog/ansible-terraform-inventory)
- [Terraform-Ansible Handoff Pattern (NetActuate)](https://netactuate.com/docs/guides/terraform-ansible-handoff)
- [cp-ansible Multi-Region Community Example](https://github.com/astubbs/cp-cluster-multi-region-ansible)
