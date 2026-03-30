---
id: TASK-30.5
title: SP3.005 — Kafka SASL/SCRAM Security Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:23'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.1
  - TASK-30.7
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: high
ordinal: 3005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend the kafka-broker role to configure SASL/SCRAM-SHA-512 authentication with SASL_SSL transport. Update server.properties template with dual listeners (CLIENT:SASL_SSL on 9092, INTERNAL:SASL_SSL on 9093), SCRAM-SHA-512 mechanism, SSL keystore/truststore configuration, and JAAS credentials. Create bootstrap SCRAM credentials for broker-internal and admin users. Per doc-11, this is the recommended auth model for kafka-lab.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Broker server.properties updated with SASL_SSL listeners on ports 9092 (client) and 9093 (inter-broker)
- [ ] #2 listener.security.protocol.map configured for INTERNAL:SASL_SSL and CLIENT:SASL_SSL
- [ ] #3 SCRAM-SHA-512 configured as the SASL mechanism
- [ ] #4 SSL keystore and truststore paths configured
- [ ] #5 Inter-broker authentication uses SCRAM-SHA-512
- [ ] #6 Bootstrap SCRAM credentials created for broker-internal and admin users
- [ ] #7 JAAS configuration rendered from template with credentials from Key Vault
- [ ] #8 Broker restarts successfully with SASL_SSL enabled
- [ ] #9 admin.properties file generated for CLI operations with SASL_SSL config
- [ ] #10 AclAuthorizer enabled with super.users for broker-internal and admin
- [ ] #11 SCRAM credentials bootstrapped in ZooKeeper before broker SASL startup
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Update kafka-broker role defaults/main.yml

Add SASL/SSL-related defaults to `ansible/roles/kafka-broker/defaults/main.yml`:

```yaml
# Security configuration
kafka_broker_security_enabled: false
kafka_broker_security_protocol: SASL_SSL
kafka_broker_sasl_mechanism: SCRAM-SHA-512
kafka_broker_ssl_dir: /etc/kafka/ssl
kafka_broker_ssl_keystore_file: "{{ inventory_hostname }}.keystore.jks"
kafka_broker_ssl_truststore_file: kafka.truststore.jks
kafka_broker_ssl_keystore_password: "{{ vault_kafka_broker_keystore_password | default('changeit') }}"
kafka_broker_ssl_truststore_password: "{{ vault_kafka_broker_truststore_password | default('changeit') }}"
kafka_broker_ssl_key_password: "{{ vault_kafka_broker_key_password | default('changeit') }}"

# SASL credentials
kafka_broker_internal_user: broker-internal
kafka_broker_internal_password: "{{ vault_kafka_broker_internal_password | default('changeit') }}"
kafka_broker_admin_user: admin
kafka_broker_admin_password: "{{ vault_kafka_broker_admin_password | default('changeit') }}"

# Listener names for secured mode
kafka_broker_client_listener_name: CLIENT
kafka_broker_internal_listener_name: INTERNAL
kafka_broker_client_port: 9092
kafka_broker_internal_port: 9093
```

### Step 2: Update server.properties.j2 template

Add conditional SASL_SSL configuration blocks to `ansible/roles/kafka-broker/templates/server.properties.j2`. The template uses `{% if kafka_broker_security_enabled %}` guards so the base PLAINTEXT configuration still works:

```properties
{% if kafka_broker_security_enabled %}
# Listeners: CLIENT (external clients) on 9092, INTERNAL (inter-broker) on 9093
listeners={{ kafka_broker_client_listener_name }}://0.0.0.0:{{ kafka_broker_client_port }},{{ kafka_broker_internal_listener_name }}://0.0.0.0:{{ kafka_broker_internal_port }}
advertised.listeners={{ kafka_broker_client_listener_name }}://{{ ansible_host }}:{{ kafka_broker_client_port }},{{ kafka_broker_internal_listener_name }}://{{ ansible_host }}:{{ kafka_broker_internal_port }}
listener.security.protocol.map={{ kafka_broker_internal_listener_name }}:{{ kafka_broker_security_protocol }},{{ kafka_broker_client_listener_name }}:{{ kafka_broker_security_protocol }}
inter.broker.listener.name={{ kafka_broker_internal_listener_name }}

# SASL configuration
security.inter.broker.protocol={{ kafka_broker_security_protocol }}
sasl.mechanism.inter.broker.protocol={{ kafka_broker_sasl_mechanism }}
sasl.enabled.mechanisms={{ kafka_broker_sasl_mechanism }}

# JAAS configuration for inter-broker authentication
listener.name.{{ kafka_broker_internal_listener_name | lower }}.{{ kafka_broker_sasl_mechanism | lower | replace('-', '.') }}.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="{{ kafka_broker_internal_user }}" password="{{ kafka_broker_internal_password }}";
listener.name.{{ kafka_broker_client_listener_name | lower }}.{{ kafka_broker_sasl_mechanism | lower | replace('-', '.') }}.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="{{ kafka_broker_internal_user }}" password="{{ kafka_broker_internal_password }}";

# SSL/TLS settings
ssl.keystore.location={{ kafka_broker_ssl_dir }}/{{ kafka_broker_ssl_keystore_file }}
ssl.keystore.password={{ kafka_broker_ssl_keystore_password }}
ssl.key.password={{ kafka_broker_ssl_key_password }}
ssl.truststore.location={{ kafka_broker_ssl_dir }}/{{ kafka_broker_ssl_truststore_file }}
ssl.truststore.password={{ kafka_broker_ssl_truststore_password }}
ssl.endpoint.identification.algorithm=https
ssl.client.auth=required

# Enable ACL authorizer
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
super.users=User:{{ kafka_broker_internal_user }};User:{{ kafka_broker_admin_user }}
{% else %}
# PLAINTEXT mode (dev/initial setup)
listeners={{ kafka_broker_listeners }}
advertised.listeners=PLAINTEXT://{{ ansible_host }}:{{ kafka_broker_port }}
inter.broker.listener.name={{ kafka_broker_inter_broker_listener_name }}
listener.security.protocol.map={{ kafka_broker_listener_security_protocol_map }}
{% endif %}
```

### Step 3: Create SCRAM credential bootstrap task

Add `ansible/roles/kafka-broker/tasks/scram-bootstrap.yml`:

Since this is ZooKeeper mode, bootstrap SCRAM credentials via ZooKeeper before broker startup with SASL enabled. This task runs `kafka-configs` with `--zookeeper` flag:

```yaml
- name: Bootstrap broker-internal SCRAM credential in ZooKeeper
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-configs
      --zookeeper {{ kafka_broker_zookeeper_connect }}
      --alter
      --add-config 'SCRAM-SHA-512=[iterations=8192,password={{ kafka_broker_internal_password }}]'
      --entity-type users
      --entity-name {{ kafka_broker_internal_user }}
  run_once: true
  become: true
  become_user: "{{ kafka_user }}"
  when: kafka_broker_security_enabled

- name: Bootstrap admin SCRAM credential in ZooKeeper
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-configs
      --zookeeper {{ kafka_broker_zookeeper_connect }}
      --alter
      --add-config 'SCRAM-SHA-512=[iterations=8192,password={{ kafka_broker_admin_password }}]'
      --entity-type users
      --entity-name {{ kafka_broker_admin_user }}
  run_once: true
  become: true
  become_user: "{{ kafka_user }}"
  when: kafka_broker_security_enabled
```

This must run after ZooKeeper is up but before brokers start with SASL_SSL. The `run_once: true` ensures it executes once across all brokers.

### Step 4: Update tasks/main.yml

Add SCRAM bootstrap import before the service tasks:

```yaml
- name: Import Kafka broker configuration tasks
  ansible.builtin.import_tasks: configure.yml

- name: Import SCRAM credential bootstrap tasks
  ansible.builtin.import_tasks: scram-bootstrap.yml

- name: Import Kafka broker service tasks
  ansible.builtin.import_tasks: service.yml
```

### Step 5: Update group_vars/kafka_broker.yml

Enable security in the Kafka broker group vars:

```yaml
kafka_broker_security_enabled: true
```

### Step 6: Update handler to use SASL_SSL for health check

Update `handlers/main.yml` so the health check works with SASL_SSL:

```yaml
- name: Verify kafka broker health
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-broker-api-versions
      --bootstrap-server localhost:{{ kafka_broker_client_port }}
      {% if kafka_broker_security_enabled %}
      --command-config {{ kafka_broker_config_dir }}/admin.properties
      {% endif %}
  register: broker_health
  until: broker_health.rc == 0
  retries: 6
  delay: 10
  changed_when: false
```

### Step 7: Create admin.properties template

Add `ansible/roles/kafka-broker/templates/admin.properties.j2`:

```properties
bootstrap.servers=localhost:{{ kafka_broker_client_port }}
security.protocol={{ kafka_broker_security_protocol }}
sasl.mechanism={{ kafka_broker_sasl_mechanism }}
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="{{ kafka_broker_admin_user }}" password="{{ kafka_broker_admin_password }}";
ssl.truststore.location={{ kafka_broker_ssl_dir }}/{{ kafka_broker_ssl_truststore_file }}
ssl.truststore.password={{ kafka_broker_ssl_truststore_password }}
```

Deploy this file in configure.yml when `kafka_broker_security_enabled` is true.

### Key References
- SCRAM credentials bootstrapped via ZooKeeper in ZK mode (not --bootstrap-server)
- ZK connect: zk-01:2181,zk-02:2181,zk-03:2181/kafka
- Dual listeners: CLIENT:SASL_SSL on 9092, INTERNAL:SASL_SSL on 9093
- SSL cert paths from tls-certs role: /etc/kafka/ssl/
- Passwords must reference vault variables (vault_kafka_broker_*_password)
- super.users must include broker-internal and admin users
- AclAuthorizer enables ACL enforcement (SP3.010)
- Per doc-11: SCRAM-SHA-512 with iterations=8192
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [SM] 2026-03-31T00:00:00Z
- **File contention**: server.properties.j2, defaults/main.yml, and group_vars/kafka_broker.yml are also modified by SP3.007 and SP3.008. This task should run FIRST among the three since it restructures the listener section with conditionals. Recommended TL execution order: SP3.005 → SP3.007 → SP3.008.
- admin.properties created here is reused by SP3.006 and SP3.009 — do not duplicate.
<!-- SECTION:NOTES:END -->
