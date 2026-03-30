---
id: doc-13
title: SP0.009 — Ansible for Confluent Platform
type: other
created_date: '2026-03-30 16:02'
updated_date: '2026-03-30 16:14'
---
## Executive Summary

This document defines the Ansible automation strategy for deploying and managing Confluent Platform 7.8.x on Azure Virtual Machines running Ubuntu 22.04 LTS. The approach uses the `azure.azcollection.azure_rm` dynamic inventory plugin for credential-free host discovery via User Assigned Managed Identity (UAMI), and a collection of idiomatic Ansible roles — one per Confluent component — to install, configure, and lifecycle-manage each service independently.

The one-role-per-component pattern is chosen deliberately: it enforces a clean separation of concerns, allows each component to evolve its configuration schema without affecting others, and enables the TL to deploy or update a single component (e.g., Schema Registry) without touching broker or ZooKeeper configurations. Each role encapsulates its own defaults, templates, handlers, and systemd integration, making the overall playbook collection composable and testable in isolation.

Rolling update safety is achieved through `serial: 1` execution combined with `pre_tasks` drain operations and `post_tasks` health checks. This guarantees that no more than one broker (or ZooKeeper node) is offline at any moment, preserving quorum and ISR counts throughout maintenance windows. The patterns documented here serve as the authoritative design reference for all Ansible work in Sprint 1 and beyond.

---

## Azure Dynamic Inventory

The `azure.azcollection.azure_rm` inventory plugin discovers Azure VMs at runtime and groups them using VM tags. No credentials are stored in inventory files; the control node (itself an Azure VM) authenticates through its assigned UAMI.

### Authentication

Set the following environment variables on the Ansible control node before running any playbook. These are injected via the CI/CD pipeline or loaded from Azure Key Vault by a bootstrap script — never hard-coded.

```bash
export AZURE_AUTH_SOURCE=msi
export AZURE_CLIENT_ID="<uami-client-id>"
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
```

The UAMI must hold at minimum the `Reader` role on the resource group `klc-rg-kafkalab-scus` to enumerate VMs.

### Inventory Plugin Configuration

Save as `inventory/azure_rm.yml`:

```yaml
plugin: azure.azcollection.azure_rm
auth_source: msi

include_vm_resource_groups:
  - klc-rg-kafkalab-scus

keyed_groups:
  - key: tags.component
    prefix: ''
    separator: ''
  - key: tags.environment
    prefix: env
    separator: '_'
  - key: location
    prefix: azure
    separator: '_'

compose:
  ansible_host: 'private_ipv4_addresses | first'
  ansible_user: '"azureuser"'
```

### VM Tag Schema

Each VM provisioned by Terraform must carry these tags:

| Tag | Values | Resulting Ansible Group |
|---|---|---|
| `component` | `kafka_broker` | `kafka_broker` |
| `component` | `zookeeper` | `zookeeper` |
| `component` | `schema_registry` | `schema_registry` |
| `component` | `kafka_connect` | `kafka_connect` |
| `environment` | `production` | `env_production` |
| `environment` | `dr` | `env_dr` |
| `region` | `southcentralus` | `azure_southcentralus` |

The `component` tag drives role assignment in `site.yml`. The `environment` tag drives `group_vars` overlays for region-specific tuning.

---

## Role Structure

Each Confluent component has a dedicated role under `roles/`. The directory layout is identical across all roles; only the content differs.

### Directory Layout per Role

| Path | Purpose |
|---|---|
| `roles/<component>/tasks/main.yml` | Entry point; imports sub-task files |
| `roles/<component>/tasks/install.yml` | Archive download, extraction, symlink |
| `roles/<component>/tasks/configure.yml` | Render config templates, create directories |
| `roles/<component>/tasks/service.yml` | systemd unit file, daemon-reload, enable |
| `roles/<component>/handlers/main.yml` | Restart and health-check handlers |
| `roles/<component>/defaults/main.yml` | Lowest-precedence tuneable defaults |
| `roles/<component>/vars/main.yml` | High-precedence internal constants |
| `roles/<component>/templates/` | Jinja2 config templates (`.j2` extension) |
| `roles/<component>/files/` | Static files copied verbatim |
| `roles/<component>/meta/main.yml` | Role dependencies and Galaxy metadata |

### Roles Defined

| Role | Component | VM SKU |
|---|---|---|
| `kafka-broker` | Apache Kafka broker | D4s_v5 |
| `zookeeper` | Apache ZooKeeper | D2s_v5 |
| `schema-registry` | Confluent Schema Registry | D2s_v5 |
| `kafka-connect` | Confluent Kafka Connect | D2s_v5 |

### Role `defaults/main.yml` Contents (kafka-broker example)

```yaml
# roles/kafka-broker/defaults/main.yml
confluent_archive_dest: '/opt/confluent'
confluent_version: '7.8.0'
kafka_broker_data_dir: '/data/kafka'
kafka_broker_log_dir: '/var/log/kafka'
kafka_broker_port: 9092
kafka_broker_jmx_port: 9999
kafka_broker_heap_opts: '-Xms4g -Xmx4g'
kafka_broker_user: 'kafka'
kafka_broker_group: 'kafka'
kafka_broker_service_name: 'confluent-kafka'
```

### Role `vars/main.yml` Contents (kafka-broker example)

```yaml
# roles/kafka-broker/vars/main.yml
# Internal constants — not intended to be overridden by operators
confluent_archive_url: >-
  https://packages.confluent.io/archive/7.8/confluent-{{ confluent_version }}.tar.gz
kafka_broker_config_dir: '/etc/kafka'
kafka_broker_systemd_unit: 'confluent-kafka.service'
```

---

## Variable Hierarchy

Ansible evaluates variables in the following precedence order (lowest to highest). The first definition at the lowest layer is the fallback; each successive layer overrides it.

### Precedence Table

| Precedence | Source | Typical Use |
|---|---|---|
| 1 (lowest) | `roles/<role>/defaults/main.yml` | Sensible defaults — operators override these |
| 2 | `inventory/group_vars/all.yml` | Global settings applied to every host |
| 3 | `inventory/group_vars/<group>.yml` | Per-component or per-environment overrides |
| 4 | `inventory/host_vars/<host>.yml` | Per-host tuning (e.g., `broker.rack`) |
| 5 | Play `vars:` block | Ad hoc play-scoped values |
| 6 | `roles/<role>/vars/main.yml` | High-precedence role internals |
| 7 | `set_fact` / `register` | Runtime-derived values |
| 8 (highest) | `--extra-vars` / `-e` | CI/CD overrides, one-off runs |

### Practical Example: Broker Configuration

```
# Layer 1 — role default
kafka_broker_port: 9092

# Layer 2 — group_vars/all.yml
confluent_version: '7.8.0'
kafka_security_protocol: 'PLAINTEXT'

# Layer 3 — group_vars/kafka_broker.yml
kafka_broker_heap_opts: '-Xms6g -Xmx6g'
kafka_broker_log_retention_hours: 168

# Layer 4 — host_vars/kafka-broker-01.yml
kafka_broker_broker_id: 1
kafka_broker_rack: 'southcentralus-zone1'
```

### File Layout

```
inventory/
  azure_rm.yml
  group_vars/
    all.yml
    kafka_broker.yml
    zookeeper.yml
    schema_registry.yml
    kafka_connect.yml
  host_vars/
    kafka-broker-01.yml
    kafka-broker-02.yml
    zookeeper-01.yml
```

---

## Handler Patterns

Handlers run once at the end of a play, triggered by `notify`. They are idempotent by nature — notifying the same handler multiple times results in a single execution.

### `roles/kafka-broker/handlers/main.yml`

```yaml
---
- name: 'Restart kafka broker'
  ansible.builtin.systemd:
    name: '{{ kafka_broker_service_name }}'
    state: restarted
  listen: 'restart kafka broker'

- name: 'Wait for Kafka port'
  ansible.builtin.wait_for:
    host: '{{ ansible_default_ipv4.address }}'
    port: '{{ kafka_broker_port }}'
    delay: 5
    timeout: 120
    state: started
  listen: 'restart kafka broker'

- name: 'Verify broker joined cluster'
  ansible.builtin.command: >
    /opt/confluent/bin/kafka-broker-api-versions
    --bootstrap-server {{ ansible_default_ipv4.address }}:{{ kafka_broker_port }}
  register: kafka_api_versions_result
  retries: 6
  delay: 10
  until: kafka_api_versions_result.rc == 0
  listen: 'restart kafka broker'
```

### `roles/zookeeper/handlers/main.yml`

```yaml
---
- name: 'Restart zookeeper'
  ansible.builtin.systemd:
    name: '{{ zookeeper_service_name }}'
    state: restarted
  listen: 'restart zookeeper'

- name: 'Wait for ZooKeeper port'
  ansible.builtin.wait_for:
    host: '{{ ansible_default_ipv4.address }}'
    port: '{{ zookeeper_client_port }}'
    delay: 5
    timeout: 60
    state: started
  listen: 'restart zookeeper'
```

### `roles/schema-registry/handlers/main.yml`

```yaml
---
- name: 'Restart schema registry'
  ansible.builtin.systemd:
    name: '{{ schema_registry_service_name }}'
    state: restarted
  listen: 'restart schema registry'

- name: 'Schema Registry health check'
  ansible.builtin.uri:
    url: 'http://{{ ansible_default_ipv4.address }}:{{ schema_registry_port }}/subjects'
    status_code: 200
    return_content: false
  register: schema_registry_health
  retries: 12
  delay: 10
  until: schema_registry_health.status == 200
  listen: 'restart schema registry'
```

### Handler Ordering

Handlers within a `listen` label execute in definition order. The pattern above chains three sequential steps — restart → wait for port → verify application-level health — ensuring that `notify: restart kafka broker` only completes when the broker is fully operational.

---

## Rolling Update Strategy

### Approach

Use `serial: 1` at the play level so Ansible processes exactly one host before moving to the next. For ZooKeeper this preserves quorum (majority of nodes remain up). For Kafka brokers this ensures ISR counts never fall below the minimum configured threshold.

### Playbook Structure

```yaml
# playbooks/rolling-update-kafka-broker.yml
---
- name: 'Rolling update of Kafka brokers'
  hosts: kafka_broker
  serial: 1
  max_fail_percentage: 0

  pre_tasks:
    - name: 'Verify ISR health before touching this broker'
      ansible.builtin.command: >
        /opt/confluent/bin/kafka-topics
        --bootstrap-server {{ groups['kafka_broker'][0] }}:{{ kafka_broker_port }}
        --describe
        --under-replicated-partitions
      register: under_replicated
      delegate_to: '{{ groups["kafka_broker"][0] }}'
      failed_when: under_replicated.stdout | length > 0

    - name: 'Trigger preferred replica election to move leaders off this broker'
      ansible.builtin.command: >
        /opt/confluent/bin/kafka-leader-election
        --bootstrap-server {{ groups['kafka_broker'][0] }}:{{ kafka_broker_port }}
        --election-type PREFERRED
        --all-topic-partitions
      delegate_to: '{{ groups["kafka_broker"][0] }}'
      ignore_errors: true

  roles:
    - role: kafka-broker

  post_tasks:
    - name: 'Wait for all partitions to be in-sync after broker restart'
      ansible.builtin.command: >
        /opt/confluent/bin/kafka-topics
        --bootstrap-server {{ ansible_default_ipv4.address }}:{{ kafka_broker_port }}
        --describe
        --under-replicated-partitions
      register: post_isr_check
      retries: 18
      delay: 10
      until: post_isr_check.stdout | length == 0
```

### Canary Pattern

For large clusters, use a progressive `serial` list to validate on one host before rolling to the rest:

```yaml
serial:
  - 1
  - '20%'
  - '100%'
```

### Rollback Pattern

If `max_fail_percentage: 0` causes the play to abort, the previous package version remains installed on the failed host because the archive-based install uses versioned directories. Re-run the playbook with `--extra-vars "confluent_version=7.7.1"` to restore the prior version on only the failed host:

```bash
ansible-playbook playbooks/rolling-update-kafka-broker.yml \
  -l kafka-broker-02 \
  -e 'confluent_version=7.7.1'
```

---

## Idempotency Patterns

All tasks must produce the same result regardless of how many times the playbook is run. The following patterns enforce this guarantee.

### Package / Archive Install

```yaml
- name: 'Create Confluent base directory'
  ansible.builtin.file:
    path: '{{ confluent_archive_dest }}'
    state: directory
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    mode: '0755'

- name: 'Check if Confluent archive is already extracted'
  ansible.builtin.stat:
    path: '{{ confluent_archive_dest }}/confluent-{{ confluent_version }}'
  register: confluent_extracted

- name: 'Download and extract Confluent archive'
  ansible.builtin.unarchive:
    src: '{{ confluent_archive_url }}'
    dest: '{{ confluent_archive_dest }}'
    remote_src: true
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
  when: not confluent_extracted.stat.exists

- name: 'Create current symlink'
  ansible.builtin.file:
    src: '{{ confluent_archive_dest }}/confluent-{{ confluent_version }}'
    dest: '{{ confluent_archive_dest }}/current'
    state: link
    force: true
```

### Config Template with Notify

```yaml
- name: 'Render Kafka broker configuration'
  ansible.builtin.template:
    src: 'server.properties.j2'
    dest: '{{ kafka_broker_config_dir }}/server.properties'
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    mode: '0640'
  notify: 'restart kafka broker'
```

The `template` module computes a diff and only notifies the handler when the rendered output actually changes. No-op runs do not trigger restarts.

### Service State Management

```yaml
- name: 'Copy kafka broker systemd unit'
  ansible.builtin.copy:
    src: 'confluent-kafka.service'
    dest: '/etc/systemd/system/confluent-kafka.service'
    owner: root
    group: root
    mode: '0644'
  notify: 'restart kafka broker'

- name: 'Reload systemd daemon'
  ansible.builtin.systemd:
    daemon_reload: true

- name: 'Ensure kafka broker is enabled and running'
  ansible.builtin.systemd:
    name: '{{ kafka_broker_service_name }}'
    enabled: true
    state: started
```

### Wait-for Idempotency

`ansible.builtin.wait_for` is naturally idempotent — it succeeds immediately if the port is already open. Used in the `post_tasks` block and in handlers to confirm readiness before proceeding.

---

## Playbook Organization

```
ansible/
  ansible.cfg
  site.yml
  playbooks/
    kafka-broker.yml
    zookeeper.yml
    schema-registry.yml
    kafka-connect.yml
    rolling-update-kafka-broker.yml
    rolling-update-zookeeper.yml
  roles/
    kafka-broker/
    zookeeper/
    schema-registry/
    kafka-connect/
  inventory/
    azure_rm.yml
    group_vars/
      all.yml
      kafka_broker.yml
      zookeeper.yml
      schema_registry.yml
      kafka_connect.yml
    host_vars/
```

### `site.yml` — Full Stack Deployment

```yaml
# ansible/site.yml
---
- name: 'Deploy ZooKeeper ensemble'
  hosts: zookeeper
  become: true
  roles:
    - role: zookeeper

- name: 'Deploy Kafka brokers'
  hosts: kafka_broker
  become: true
  roles:
    - role: kafka-broker

- name: 'Deploy Schema Registry'
  hosts: schema_registry
  become: true
  roles:
    - role: schema-registry

- name: 'Deploy Kafka Connect workers'
  hosts: kafka_connect
  become: true
  roles:
    - role: kafka-connect
```

The plays run in order. ZooKeeper must be healthy before Kafka brokers start, which must be healthy before Schema Registry and Connect can register topics. The ordering in `site.yml` encodes this dependency.

### Component Playbooks

Each component playbook in `playbooks/` imports only the relevant role and is used for:

- Initial targeted deploys: `ansible-playbook playbooks/schema-registry.yml`
- Reconfigure-only runs: `ansible-playbook playbooks/kafka-broker.yml --tags configure`
- Post-repair re-installs on a single host: `ansible-playbook playbooks/kafka-broker.yml -l kafka-broker-03`

### `ansible.cfg`

```ini
[defaults]
inventory         = inventory/azure_rm.yml
roles_path        = roles
remote_user       = azureuser
private_key_file  = ~/.ssh/kafka_lab_ed25519
host_key_checking = False
forks             = 5
gathering         = smart
fact_caching      = jsonfile
fact_caching_connection = .ansible_facts_cache
fact_caching_timeout = 86400

[privilege_escalation]
become_method = sudo
become_user = root
```

---

## Example Role: kafka-broker

### Directory Structure

```
roles/kafka-broker/
  defaults/
    main.yml
  vars/
    main.yml
  tasks/
    main.yml
    install.yml
    configure.yml
    service.yml
  handlers/
    main.yml
  templates/
    server.properties.j2
    confluent-kafka.service.j2
  files/
  meta/
    main.yml
```

### `tasks/main.yml`

```yaml
---
- name: 'Install Confluent kafka broker'
  ansible.builtin.import_tasks: install.yml
  tags:
    - install

- name: 'Configure kafka broker'
  ansible.builtin.import_tasks: configure.yml
  tags:
    - configure

- name: 'Manage kafka broker service'
  ansible.builtin.import_tasks: service.yml
  tags:
    - service
```

### `tasks/install.yml`

```yaml
---
- name: 'Create kafka system group'
  ansible.builtin.group:
    name: '{{ kafka_broker_group }}'
    state: present
    system: true

- name: 'Create kafka system user'
  ansible.builtin.user:
    name: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    shell: '/usr/sbin/nologin'
    home: '{{ confluent_archive_dest }}'
    create_home: false
    state: present
    system: true

- name: 'Create Confluent base directory'
  ansible.builtin.file:
    path: '{{ confluent_archive_dest }}'
    state: directory
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    mode: '0755'

- name: 'Check if Confluent archive is already extracted'
  ansible.builtin.stat:
    path: '{{ confluent_archive_dest }}/confluent-{{ confluent_version }}'
  register: confluent_extracted

- name: 'Download and extract Confluent archive'
  ansible.builtin.unarchive:
    src: '{{ confluent_archive_url }}'
    dest: '{{ confluent_archive_dest }}'
    remote_src: true
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
  when: not confluent_extracted.stat.exists

- name: 'Create current symlink'
  ansible.builtin.file:
    src: '{{ confluent_archive_dest }}/confluent-{{ confluent_version }}'
    dest: '{{ confluent_archive_dest }}/current'
    state: link
    force: true

- name: 'Create Kafka data directory'
  ansible.builtin.file:
    path: '{{ kafka_broker_data_dir }}'
    state: directory
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    mode: '0750'

- name: 'Create Kafka log directory'
  ansible.builtin.file:
    path: '{{ kafka_broker_log_dir }}'
    state: directory
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    mode: '0750'
```

### `tasks/configure.yml`

```yaml
---
- name: 'Create Kafka config directory'
  ansible.builtin.file:
    path: '{{ kafka_broker_config_dir }}'
    state: directory
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    mode: '0750'

- name: 'Render Kafka broker configuration'
  ansible.builtin.template:
    src: 'server.properties.j2'
    dest: '{{ kafka_broker_config_dir }}/server.properties'
    owner: '{{ kafka_broker_user }}'
    group: '{{ kafka_broker_group }}'
    mode: '0640'
  notify: 'restart kafka broker'
```

### `tasks/service.yml`

```yaml
---
- name: 'Render confluent-kafka systemd unit'
  ansible.builtin.template:
    src: 'confluent-kafka.service.j2'
    dest: '/etc/systemd/system/confluent-kafka.service'
    owner: root
    group: root
    mode: '0644'
  notify: 'restart kafka broker'

- name: 'Reload systemd daemon'
  ansible.builtin.systemd:
    daemon_reload: true

- name: 'Ensure kafka broker is enabled and started'
  ansible.builtin.systemd:
    name: '{{ kafka_broker_service_name }}'
    enabled: true
    state: started
```

### `templates/server.properties.j2` (excerpt)

```ini
broker.id={{ kafka_broker_broker_id }}
listeners=PLAINTEXT://{{ ansible_default_ipv4.address }}:{{ kafka_broker_port }}
log.dirs={{ kafka_broker_data_dir }}
zookeeper.connect={{ groups['zookeeper'] | map('extract', hostvars, 'ansible_default_ipv4') | map(attribute='address') | zip_longest([], fillvalue=':' + zookeeper_client_port | string) | map('join') | join(',') }}
num.network.threads=3
num.io.threads=8
log.retention.hours={{ kafka_broker_log_retention_hours | default(168) }}
```

### `meta/main.yml`

```yaml
---
galaxy_info:
  author: kafka-lab
  description: Installs and configures a Confluent Platform Kafka broker
  min_ansible_version: '2.14'
  platforms:
    - name: Ubuntu
      versions:
        - jammy
dependencies: []
```

---

## References

- Ansible Dynamic Inventory — azure.azcollection.azure_rm: <https://docs.ansible.com/ansible/latest/collections/azure/azcollection/azure_rm_inventory.html>
- Microsoft Tech Community — Managed Identity with Azure Dynamic Inventory: <https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/configure-ansible-to-use-a-managed-identity-with-azure-dynamic-inventory/1062449>
- Ansible Roles — Directory Structure: <https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html>
- Ansible Variable Precedence: <https://docs.ansible.com/ansible/latest/reference_appendices/general_precedence.html>
- Ansible Strategies and Serial: <https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html>
- Confluent Platform — Ansible Overview: <https://docs.confluent.io/ansible/current/overview.html>
- Confluent Platform — Configure Ansible Playbooks: <https://docs.confluent.io/ansible/current/ansible-configure.html>
- Confluent Platform — Rolling Update with Ansible: <https://docs.confluent.io/ansible/current/ansible-reconfigure.html>
- Confluent cp-ansible GitHub Repository: <https://github.com/confluentinc/cp-ansible>
- Confluent Platform — ZIP/TAR Archive Installation: <https://docs.confluent.io/platform/current/installation/installing_cp/zip-tar.html>
