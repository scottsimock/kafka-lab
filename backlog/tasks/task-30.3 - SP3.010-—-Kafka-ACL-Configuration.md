---
id: TASK-30.3
title: SP3.010 — Kafka ACL Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:12'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.5
  - TASK-30.6
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: medium
ordinal: 3010
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Kafka ACLs for all service principals created in SP3.006. Define least-privilege access for each service: web-app gets read/write on app topics, schema-registry gets _schemas topic access, connect-worker gets connect internal topics, admin gets cluster-wide access. Create an Ansible task file that applies ACLs using kafka-acls CLI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Kafka ACLs configured for each service principal (web-app, schema-registry, connect-worker)
- [ ] #2 web-app user has read/write on application topics, read on consumer groups
- [ ] #3 schema-registry user has full access to _schemas topic
- [ ] #4 connect-worker user has access to connect-* internal topics and configured data topics
- [ ] #5 admin user has cluster-wide access
- [ ] #6 ACLs verified with kafka-acls --list
- [ ] #7 ACL task file is idempotent — kafka-acls --add is safe to re-run
- [ ] #8 Each service principal follows least-privilege principle
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Create ACL task file

Create `ansible/roles/kafka-broker/tasks/acls.yml` (or a standalone `ansible/tasks/configure-acls.yml`).

This task file runs on a single broker node (`run_once: true`) and uses `kafka-acls` CLI with `--command-config admin.properties` for SASL_SSL authentication.

### Step 2: Define ACL variables in defaults

Add to `ansible/roles/kafka-broker/defaults/main.yml` or create a dedicated section:

```yaml
# ACL configuration
kafka_broker_acl_enabled: false
kafka_broker_acl_admin_config: "{{ kafka_broker_config_dir }}/admin.properties"
kafka_broker_acl_bootstrap_server: "localhost:{{ kafka_broker_client_port | default(9092) }}"
```

### Step 3: Implement web-app ACLs

Per doc-11, the web-app service needs read/write on application topics and consumer group access:

```yaml
- name: Grant web-app write access to application topics
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:web-app
      --operation Write --operation Describe
      --topic kafkalab.
      --resource-pattern-type prefixed
  run_once: true
  become: true
  become_user: "{{ kafka_user }}"

- name: Grant web-app read access to application topics
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:web-app
      --operation Read --operation Describe
      --topic kafkalab.
      --resource-pattern-type prefixed
  run_once: true

- name: Grant web-app consumer group access
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:web-app
      --operation Read
      --group webapp-
      --resource-pattern-type prefixed
  run_once: true
```

### Step 4: Implement schema-registry ACLs

Schema Registry needs full access to the `_schemas` topic:

```yaml
- name: Grant schema-registry access to _schemas topic
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:schema-registry
      --operation Read --operation Write --operation Create --operation Describe --operation DescribeConfigs
      --topic _schemas
  run_once: true

- name: Grant schema-registry consumer group access
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:schema-registry
      --operation Read
      --group schema-registry
  run_once: true
```

### Step 5: Implement connect-worker ACLs

Kafka Connect needs access to its internal topics and configured data topics:

```yaml
- name: Grant connect-worker access to connect internal topics
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:connect-worker
      --operation Read --operation Write --operation Create --operation Describe
      --topic connect-
      --resource-pattern-type prefixed
  run_once: true

- name: Grant connect-worker consumer group access
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:connect-worker
      --operation Read
      --group connect-
      --resource-pattern-type prefixed
  run_once: true

- name: Grant connect-worker describe on cluster
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:connect-worker
      --operation Describe
      --cluster
  run_once: true
```

### Step 6: Implement admin ACLs

Admin user gets cluster-wide access (already a super.user in broker config, but explicit ACLs for completeness):

```yaml
- name: Grant admin cluster-wide access
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:admin
      --operation All
      --cluster
  run_once: true

- name: Grant admin all topic access
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:admin
      --operation All
      --topic '*'
  run_once: true

- name: Grant admin all group access
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --add --allow-principal User:admin
      --operation All
      --group '*'
  run_once: true
```

### Step 7: Add verification task

```yaml
- name: List all ACLs for verification
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-acls
      --bootstrap-server {{ kafka_broker_acl_bootstrap_server }}
      --command-config {{ kafka_broker_acl_admin_config }}
      --list
  register: acl_list
  run_once: true
  changed_when: false

- name: Assert web-app ACLs exist
  ansible.builtin.assert:
    that: "'User:web-app' in acl_list.stdout"
    fail_msg: "web-app ACLs not found"

- name: Assert schema-registry ACLs exist
  ansible.builtin.assert:
    that: "'User:schema-registry' in acl_list.stdout"
    fail_msg: "schema-registry ACLs not found"

- name: Assert connect-worker ACLs exist
  ansible.builtin.assert:
    that: "'User:connect-worker' in acl_list.stdout"
    fail_msg: "connect-worker ACLs not found"
```

### Step 8: Wire into main.yml or site.yml

Add conditional import in `ansible/roles/kafka-broker/tasks/main.yml`:

```yaml
- name: Import ACL configuration tasks
  ansible.builtin.import_tasks: acls.yml
  when: kafka_broker_acl_enabled | default(false)
```

Or create a standalone playbook `ansible/playbooks/configure-acls.yml`.

### Key References
- Uses --command-config admin.properties for SASL_SSL auth (from SP3.005)
- kafka-acls --add is idempotent (safe to re-run)
- web-app: prefixed access on kafkalab.* topics + webapp-* groups
- schema-registry: _schemas topic + schema-registry group
- connect-worker: connect-* topics + connect-* groups + cluster describe
- admin: already super.user, explicit ACLs for completeness
- doc-11: ACL Configuration Patterns section
<!-- SECTION:PLAN:END -->
