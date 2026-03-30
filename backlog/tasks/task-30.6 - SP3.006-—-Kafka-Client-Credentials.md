---
id: TASK-30.6
title: SP3.006 — Kafka Client Credentials
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:23'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.5
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: medium
ordinal: 3006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create SCRAM-SHA-512 credentials for all Kafka client services: web-app (Next.js), schema-registry, connect-worker, and admin user. Generate client.properties files for each service containing SASL_SSL configuration, JAAS credentials, and truststore references. Store sensitive credentials in Ansible vault. This task configures the client side of the SASL/SCRAM setup from SP3.005.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 SCRAM credentials created for web-app, schema-registry, and connect-worker users
- [ ] #2 client.properties files generated for each service with SASL_SSL config
- [ ] #3 Uses admin.properties already created by SP3.005 for kafka-configs commands (does not recreate it)
- [ ] #4 Credentials stored in Ansible vault or referenced from Key Vault
- [ ] #5 kafka-configs --describe verifies credentials exist for all users
- [ ] #6 Truststore distributed to all client service nodes
- [ ] #7 Client properties files use mode 0640 owned by kafka:kafka
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Create client credentials role

Create `ansible/roles/kafka-client-creds/` with the standard structure:

```
ansible/roles/kafka-client-creds/
├── defaults/main.yml
├── tasks/
│   ├── main.yml
│   ├── scram-users.yml
│   └── client-properties.yml
├── templates/
│   ├── client.properties.j2
│   └── admin.properties.j2
└── handlers/main.yml
```

Alternatively, these tasks can be added as a sub-task file within the `kafka-broker` role (e.g., `ansible/roles/kafka-broker/tasks/client-credentials.yml`) since they run via `kafka-configs` on broker nodes. Choose based on coder preference — a separate role is cleaner for reuse.

### Step 2: Create defaults/main.yml

```yaml
kafka_client_creds_bootstrap_server: "{{ groups['kafka_broker'][0] }}:{{ kafka_broker_client_port | default(9092) }}"
kafka_client_creds_admin_config: "{{ kafka_broker_config_dir | default('/opt/confluent/current/etc/kafka') }}/admin.properties"
kafka_client_creds_scram_iterations: 8192
kafka_client_creds_ssl_dir: /etc/kafka/ssl
kafka_client_creds_truststore_file: kafka.truststore.jks

# Service account definitions
kafka_client_users:
  - name: web-app
    password: "{{ vault_kafka_webapp_password | default('changeit') }}"
  - name: schema-registry
    password: "{{ vault_kafka_schema_registry_password | default('changeit') }}"
  - name: connect-worker
    password: "{{ vault_kafka_connect_worker_password | default('changeit') }}"
```

### Step 3: Create tasks/scram-users.yml

Run once on a single broker node to create SCRAM-SHA-512 credentials for each service:

```yaml
- name: Create SCRAM-SHA-512 credentials for {{ item.name }}
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-configs
      --bootstrap-server {{ kafka_client_creds_bootstrap_server }}
      --command-config {{ kafka_client_creds_admin_config }}
      --alter
      --add-config 'SCRAM-SHA-512=[iterations={{ kafka_client_creds_scram_iterations }},password={{ item.password }}]'
      --entity-type users
      --entity-name {{ item.name }}
  loop: "{{ kafka_client_users }}"
  run_once: true
  become: true
  become_user: "{{ kafka_user }}"
```

Uses `--bootstrap-server` (not `--zookeeper`) since brokers are already running with SASL_SSL at this point (SP3.005 completed).

### Step 4: Create templates/client.properties.j2

Template parameterized by `client_user_name` and `client_user_password`:

```properties
bootstrap.servers={{ groups['kafka_broker'] | map('extract', hostvars, 'ansible_host') | map('regex_replace', '$', ':' ~ (kafka_broker_client_port | default(9092))) | join(',') }}
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="{{ client_user_name }}" password="{{ client_user_password }}";
ssl.truststore.location={{ kafka_client_creds_ssl_dir }}/{{ kafka_client_creds_truststore_file }}
ssl.truststore.password={{ vault_tls_truststore_password | default('changeit') }}
```

### Step 5: Create tasks/client-properties.yml

For each client service, render the client.properties file:

1. **Deploy web-app client.properties** to `/etc/kafka/client/web-app.properties` on web-app target nodes (or a shared config location).
2. **Deploy schema-registry client.properties** to Schema Registry nodes.
3. **Deploy connect-worker client.properties** to Kafka Connect nodes.
4. **Deploy admin.properties** to all broker nodes for CLI administrative access.

Distribute the truststore to all client service nodes that need it (Schema Registry, Kafka Connect VMs).

### Step 6: Create admin.properties template

```properties
bootstrap.servers={{ groups['kafka_broker'] | map('extract', hostvars, 'ansible_host') | map('regex_replace', '$', ':' ~ (kafka_broker_client_port | default(9092))) | join(',') }}
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="{{ kafka_broker_admin_password }}";
ssl.truststore.location={{ kafka_client_creds_ssl_dir }}/{{ kafka_client_creds_truststore_file }}
ssl.truststore.password={{ vault_tls_truststore_password | default('changeit') }}
```

### Step 7: Add verification task

After creating credentials, verify they exist:

```yaml
- name: Verify SCRAM credential for {{ item.name }}
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-configs
      --bootstrap-server {{ kafka_client_creds_bootstrap_server }}
      --command-config {{ kafka_client_creds_admin_config }}
      --describe
      --entity-type users
      --entity-name {{ item.name }}
  loop: "{{ kafka_client_users }}"
  register: cred_verify
  failed_when: "'SCRAM-SHA-512' not in cred_verify.stdout"
  run_once: true
```

### Step 8: Update site.yml or create a dedicated playbook

Add a new play in site.yml (after broker play) or create `ansible/playbooks/client-credentials.yml` that targets broker nodes and runs the credential creation tasks.

### Key References
- Service accounts: web-app, schema-registry, connect-worker, admin
- Uses --bootstrap-server (brokers running with SASL_SSL from SP3.005)
- admin.properties from SP3.005 used for authentication
- Passwords from Ansible vault (vault_kafka_*_password)
- SCRAM-SHA-512 with iterations=8192 per doc-11
- Truststore: /etc/kafka/ssl/kafka.truststore.jks (from SP3.004)
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [SM] 2026-03-31T00:00:00Z
- Fixed AC #3: admin.properties is already created by SP3.005 (AC #9). This task should use it, not recreate it. Updated AC to reference SP3.005's output.
- Implementation plan Step 6 (admin.properties template) should be removed or converted to a validation step — the file already exists from SP3.005.
<!-- SECTION:NOTES:END -->
