---
name: ansible
description: Configure and manage Azure infrastructure with Ansible playbooks and roles. Use when agents need to automate VM configuration, install software packages, manage services, deploy Confluent Kafka components, or perform rolling updates across multi-region Azure deployments.
---

# Ansible

Ansible is an agentless automation engine for configuration management, application deployment, and orchestration. It connects to target machines over SSH, executes tasks defined in YAML playbooks, and ensures systems reach a desired state idempotently. For this project, Ansible configures Azure VMs provisioned by Terraform with Kafka components and supporting software.

## Key Concepts

### Inventory

Ansible inventory defines the hosts and groups to manage. For Azure, use dynamic inventory with the `azure.azcollection` plugin to discover VMs by tags, resource groups, or other metadata. Static inventory files work for fixed environments.

### Playbooks

Playbooks are YAML files that declare ordered lists of tasks to execute against hosts. Each play targets a host group and runs tasks sequentially. Playbooks support variables, conditionals, loops, handlers, and error handling.

### Roles

Roles organize playbooks into reusable, self-contained units. A role contains tasks, handlers, variables, templates, and files in a standard directory structure. Use roles to encapsulate configuration for specific components (e.g., `kafka-broker`, `zookeeper`, `schema-registry`).

### Handlers

Handlers are tasks triggered by notifications from other tasks. They run once at the end of a play regardless of how many tasks notify them. Use handlers for service restarts after configuration changes.

### Modules

Ansible modules are units of work. Use fully qualified collection names (FQCN) like `ansible.builtin.apt`, `ansible.builtin.service`, `ansible.builtin.template`. Prefer built-in modules over `shell`/`command` for idempotency.

## Project Structure

```text
ansible/
├── inventories/
│   ├── production/
│   │   ├── hosts.yml           # Static inventory
│   │   └── group_vars/
│   │       ├── kafka_brokers/
│   │       │   ├── vars        # Non-sensitive variables
│   │       │   └── vault       # Encrypted secrets
│   │       └── all.yml         # Shared variables
│   └── azure_rm.yml            # Dynamic Azure inventory
├── roles/
│   ├── common/                 # Base OS configuration
│   ├── kafka-broker/           # Kafka broker setup
│   ├── zookeeper/              # ZooKeeper setup
│   ├── schema-registry/        # Schema Registry setup
│   └── kafka-connect/          # Kafka Connect setup
├── playbooks/
│   ├── site.yml                # Main orchestration playbook
│   ├── kafka-brokers.yml       # Broker-specific plays
│   └── rolling-restart.yml     # Zero-downtime restart
└── ansible.cfg                 # Ansible configuration
```

## Quick Start

See [getting-started/site.yml](sample_codes/getting-started/site.yml) for a complete playbook deploying base configuration to Kafka broker VMs.

## Common Patterns

### Role-Based Kafka Broker Setup

See [common-patterns/kafka-broker-role.yml](sample_codes/common-patterns/kafka-broker-role.yml) for a role that installs and configures Confluent Kafka.

### Rolling Restart

See [common-patterns/rolling-restart.yml](sample_codes/common-patterns/rolling-restart.yml) for zero-downtime restarts across a Kafka cluster.

### Dynamic Azure Inventory

See [common-patterns/azure-inventory.yml](sample_codes/common-patterns/azure-inventory.yml) for discovering Azure VMs by tags.

## Style Rules

- Use 2-space indentation and always indent lists
- Prefer single quotes; use double quotes only for Jinja2 expressions or escape sequences
- Give every play, block, and task a descriptive `name` starting with an action verb
- Use `snake_case` for variable names; sort variables alphabetically
- Use FQCN for all modules (e.g., `ansible.builtin.apt` not `apt`)
- Set `become: true` at task level unless all tasks need it
- Use `state: present` or `state: absent` explicitly

## Best Practices

- **Do**: Use dynamic inventory with Azure tags for automatic host discovery
- **Do**: Store secrets in Ansible Vault with the `vault_` prefix pattern
- **Do**: Use roles for reusable component configuration
- **Do**: Use handlers for service restarts after config changes
- **Do**: Use `ansible.builtin.template` for configuration files with variables
- **Avoid**: `shell` and `command` modules; use idempotent modules instead
- **Avoid**: Hardcoding IPs or hostnames; use inventory variables

## Troubleshooting

| Issue | Solution |
|---|---|
| SSH connection timeout | Check NSG rules, verify SSH key, test with `ansible -m ping` |
| Module not found | Install required collection: `ansible-galaxy collection install azure.azcollection` |
| Variable undefined | Check `group_vars/` structure, verify vault is decrypted |
| Idempotency failure | Replace `shell`/`command` with built-in modules; use `creates:`/`removes:` parameters |

## Learn More

| Topic | How to Find |
|---|---|
| Ansible Azure modules | `microsoft_docs_search(query="ansible azure azcollection modules")` |
| Azure dynamic inventory | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/developer/ansible/dynamic-inventory-configure")` |
| Ansible best practices | See [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html) |
| Managing VMs with Ansible | `microsoft_docs_search(query="ansible manage linux virtual machines azure")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
