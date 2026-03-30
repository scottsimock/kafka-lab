---
id: TASK-29.4
title: SP2.004 — Ansible Project Structure and Dynamic Inventory
status: Done
assignee:
  - tester-2
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 21:13'
labels:
  - story
  - ansible
  - infrastructure
milestone: m-2
dependencies: []
references:
  - ansible/
  - ansible/inventory/azure_rm.yml
  - ansible/ansible.cfg
documentation:
  - doc-13
parent_task_id: TASK-29
priority: high
ordinal: 2004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Ansible project structure at the repo root under `ansible/`. This establishes the foundation for all Ansible roles and playbooks in SP2.

**Directory Structure to Create:**
```
ansible/
├── ansible.cfg
├── site.yml                  (placeholder — fleshed out in TASK-29.9)
├── requirements.yml          (Ansible Galaxy collection dependencies)
├── inventory/
│   └── azure_rm.yml          (Azure dynamic inventory plugin config)
├── group_vars/
│   ├── all.yml               (global variables for all hosts)
│   ├── zookeeper.yml         (ZooKeeper-specific variables)
│   ├── kafka_broker.yml      (Kafka broker-specific variables)
│   ├── schema_registry.yml   (Schema Registry-specific variables)
│   └── kafka_connect.yml     (Kafka Connect-specific variables)
└── roles/                    (empty — roles created in TASK-29.5 through TASK-29.8)
```

**ansible.cfg Contents:**
```ini
[defaults]
inventory = inventory/azure_rm.yml
roles_path = roles
remote_user = azureuser
host_key_checking = False
interpreter_python = /usr/bin/python3
retry_files_enabled = False
stdout_callback = yaml

[privilege_escalation]
become = False
become_method = sudo

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

**inventory/azure_rm.yml Contents:**
```yaml
plugin: azure.azcollection.azure_rm
auth_source: msi
include_vm_resource_groups:
  - klc-rg-kafkalab-scus
keyed_groups:
  - prefix: ''
    separator: ''
    key: tags.component | default('ungrouped')
  - prefix: ''
    separator: ''
    key: tags.environment | default('ungrouped')
  - prefix: ''
    separator: ''
    key: tags.region | default('ungrouped')
compose:
  ansible_host: private_ipv4_addresses[0]
  ansible_user: "'azureuser'"
```

**group_vars/all.yml** — Global variables:
```yaml
kafka_user: kafka
kafka_group: kafka
confluent_version: '7.9'
java_version: '17'
data_mount_path: /data
```

**requirements.yml:**
```yaml
collections:
  - name: azure.azcollection
    version: '>=2.0.0'
```

**Integration Notes:**
- Dynamic inventory uses Azure VM tags (`component`, `environment`, `region`) set by Terraform in TASK-29.1/29.2/29.3/29.10 to form host groups.
- The `compose` block maps private IPs to `ansible_host` for SSH connectivity.
- UAMI authentication (`auth_source: msi`) requires the VM running Ansible to have a managed identity with Reader access to the resource group.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ansible/ directory exists at repo root with the specified subdirectory structure
- [x] #2 ansible.cfg configures inventory path, roles_path, remote_user=azureuser, interpreter_python=/usr/bin/python3, and pipelining
- [x] #3 inventory/azure_rm.yml uses azure.azcollection.azure_rm plugin with auth_source: msi
- [x] #4 inventory/azure_rm.yml includes klc-rg-kafkalab-scus in include_vm_resource_groups
- [x] #5 keyed_groups configured to create groups from component, environment, and region tags without prefix/separator
- [x] #6 compose block sets ansible_host to first private IPv4 address and ansible_user to azureuser
- [x] #7 group_vars/all.yml defines kafka_user, kafka_group, confluent_version (7.9), java_version (17), data_mount_path
- [x] #8 group_vars/ includes per-component variable files: zookeeper.yml, kafka_broker.yml, schema_registry.yml, kafka_connect.yml
- [x] #9 requirements.yml lists azure.azcollection collection dependency
- [x] #10 site.yml exists as a placeholder with a comment indicating roles will be added
- [x] #11 ansible-lint passes on all created files (or no errors if ansible-lint is available)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Files to Create
- `ansible/ansible.cfg`
- `ansible/site.yml` (placeholder)
- `ansible/requirements.yml`
- `ansible/inventory/azure_rm.yml`
- `ansible/group_vars/all.yml`
- `ansible/group_vars/zookeeper.yml`
- `ansible/group_vars/kafka_broker.yml`
- `ansible/group_vars/schema_registry.yml`
- `ansible/group_vars/kafka_connect.yml`
- `ansible/roles/.gitkeep` (keep empty roles directory in git)

### Design Decisions
1. Use `azure.azcollection.azure_rm` dynamic inventory plugin — industry standard for Azure.
2. Use UAMI auth (`auth_source: msi`) rather than service principal credentials.
3. `keyed_groups` with empty prefix/separator creates clean group names matching tag values (e.g., host group `zookeeper` from `component=zookeeper` tag).
4. Per-component group_vars files allow role variable overrides per host group.
5. `interpreter_python = /usr/bin/python3` ensures Python 3 on Ubuntu 22.04.
6. SSH pipelining enabled for performance.

### Integration Points
- Dynamic inventory reads tags set by Terraform VM module (TASK-29.1)
- Group names must match tag values used in TASK-29.2/29.3/29.10 (zookeeper, kafka_broker, schema_registry, kafka_connect)
- site.yml placeholder will be completed by TASK-29.9
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T16:42:00-04:00
- Assigned to coder-2 for Wave 1 execution
- Task: Create Ansible project structure

## [Coder-2] 2026-03-30T16:43:00-04:00
- Created ansible/ project structure with ansible.cfg, inventory, group_vars, requirements.yml
- Azure dynamic inventory configured with MSI auth and keyed_groups for component/environment/region tags
- Per-component group_vars files created (zookeeper, kafka_broker, schema_registry, kafka_connect)
- site.yml placeholder created
- Committed: feat(SP2.004)

## [Tester-2] 2026-03-30T16:50:00-04:00
- Score: 11/11 (100%)
- All acceptance criteria verified
- AC #1: ✅ ansible/ with inventory/, group_vars/, roles/ all present
- AC #2: ✅ ansible.cfg correct — inventory, roles_path, remote_user, interpreter_python, pipelining all match spec
- AC #3: ✅ plugin: azure.azcollection.azure_rm, auth_source: msi
- AC #4: ✅ klc-rg-kafkalab-scus in include_vm_resource_groups
- AC #5: ✅ 3 keyed_groups with prefix:'', separator:'', keys: tags.component, tags.environment, tags.region (all with default('ungrouped'))
- AC #6: ✅ compose: ansible_host: private_ipv4_addresses[0], ansible_user: "'azureuser'"
- AC #7: ✅ all.yml: kafka_user=kafka, kafka_group=kafka, confluent_version='7.9', java_version='17', data_mount_path=/data
- AC #8: ✅ zookeeper.yml, kafka_broker.yml, schema_registry.yml, kafka_connect.yml all present
- AC #9: ✅ requirements.yml lists azure.azcollection >=2.0.0
- AC #10: ✅ site.yml placeholder with comment about roles being added in SP2 tasks
- AC #11: ✅ ansible-lint not available in environment (no pip); accepted per AC wording
<!-- SECTION:NOTES:END -->
