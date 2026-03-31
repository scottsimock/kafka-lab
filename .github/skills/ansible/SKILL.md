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

Ansible modules are units of work. Use [fully qualified collection names (FQCN)](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html#term-Fully-Qualified-Collection-Name-FQCN) like `ansible.builtin.apt`, `ansible.builtin.service`, `ansible.builtin.template`. Use the `ansible.builtin` collection for [builtin modules and plugins](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html#plugin-index). Prefer built-in modules over `shell`/`command` for idempotency.

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

### Indentation and Spacing

- Use 2-space indentation and always indent lists
- Separate each of the following with a single blank line:
  - Two host blocks
  - Two task blocks
  - Host and include blocks

### Naming

- Give every play, block, and task a concise but descriptive `name`
  - Start names with an action verb that indicates the operation being performed, such as "Install," "Configure," or "Copy"
  - Capitalize the first letter of the task name
  - Omit periods from the end of task names for brevity
  - Omit the role name from role tasks; Ansible will automatically display the role name when running a role
  - When including tasks from a separate file, you may include the filename in each task name to make tasks easier to locate (e.g., `<TASK_FILENAME> : <TASK_NAME>`)

### Variables

- Use `snake_case` for variable names
- Sort variables alphabetically when defining them in `vars:` maps or variable files

### Map Syntax

- Always use multi-line map syntax, regardless of how many pairs exist in the map
  - It improves readability and reduces changeset collisions for version control

### Quoting

- Prefer single quotes over double quotes
  - The only time you should use double quotes is when they are nested within single quotes (e.g., Jinja map reference), or when your string requires escaping characters (e.g., using "\n" to represent a newline)
  - If you must write a long string, use folded block scalar syntax (i.e., `>`) to replace newlines with spaces or literal block scalar syntax (i.e., `|`) to preserve newlines; omit all special quoting

### FQCN

- Use [fully qualified collection names (FQCN)](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html#term-Fully-Qualified-Collection-Name-FQCN) for all modules (e.g., `ansible.builtin.apt` not `apt`)
  - Use the `ansible.builtin` collection for [builtin modules and plugins](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html#plugin-index)

### State and Privileges

- For modules where `state` is optional, explicitly set `state: present` or `state: absent` to improve clarity and consistency
- Use the lowest privileges necessary to perform a task
  - Only set `become: true` at the play level or on an `include:` statement if all included tasks require super user privileges; otherwise, specify `become: true` at the task level
  - Only set `become: true` on a task if it requires super user privileges

### Comments

- Use comments to provide additional context about **what**, **how**, and/or **why** something is being done
  - Don't include redundant comments

### Host Section Order

The `host` section of a play should follow this general order:

1. `hosts` declaration
2. Host options in alphabetical order (e.g., `become`, `remote_user`, `vars`)
3. `pre_tasks`
4. `roles`
5. `tasks`

### Task Order

Each task should follow this general order:

1. `name`
2. Task declaration (e.g., `service:`, `package:`)
3. Task parameters (using multi-line map syntax)
4. Loop operators (e.g., `loop`)
5. Task options in alphabetical order (e.g., `become`, `ignore_errors`, `register`)
6. `tags`

### Include Statements

- For `include` statements, quote filenames and only use blank lines between `include` statements if they are multi-line (e.g., they have tags)

### Task Grouping

- Group related tasks together to improve readability and modularity

## Secret Management

- When using Ansible alone, store secrets using Ansible Vault
  - Use the following process to make it easy to find where vaulted variables are defined:
    1. Create a `group_vars/` subdirectory named after the group
    2. Inside this subdirectory, create two files named `vars` and `vault`
    3. In the `vars` file, define all of the variables needed, including any sensitive ones
    4. Copy all of the sensitive variables over to the `vault` file and prefix these variables with `vault_`
    5. Adjust the variables in the `vars` file to point to the matching `vault_` variables using Jinja2 syntax: `db_password: "{{ vault_db_password }}"`
    6. Encrypt the `vault` file to protect its contents
    7. Use the variable name from the `vars` file in your playbooks
- When using other tools with Ansible (e.g., Terraform), store secrets in a third-party secrets management tool (e.g., Hashicorp Vault, AWS Secrets Manager, etc.)
  - This allows all tools to reference a single source of truth for secrets and prevents configurations from getting out of sync

## Linting

- Use `ansible-lint` and `yamllint` to check syntax and enforce project standards
- Use `ansible-playbook --syntax-check` to check for syntax errors
- Use `ansible-playbook --check --diff` to perform a dry-run of playbook execution

## Best Practices

- **Do**: Use dynamic inventory with Azure tags for automatic host discovery
  - Use tags to dynamically create groups based on environment, function, location, etc.
  - Use `group_vars` to set variables based on these attributes
- **Do**: Store secrets in Ansible Vault with the `vault_` prefix pattern
- **Do**: Use roles for reusable component configuration
- **Do**: Use handlers for service restarts after config changes
- **Do**: Use `ansible.builtin.template` for configuration files with variables
- **Do**: Keep things simple; only use advanced features when necessary
- **Do**: Use version control for your Ansible configurations
- **Avoid**: `shell` and `command` modules; use idempotent modules instead
  - If you have to use `shell` or `command`, use the `creates:` or `removes:` parameter, where feasible, to prevent unnecessary execution
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
