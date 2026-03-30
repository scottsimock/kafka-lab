---
id: TASK-30.1
title: SP3.002 — Ansible Kafka Broker Role
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:10'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.8
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-8
  - doc-13
parent_task_id: TASK-30
priority: high
ordinal: 3002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Kafka broker Ansible role at ansible/roles/kafka-broker/ that configures and deploys Kafka brokers. The role renders server.properties from a Jinja2 template with broker.id, listeners, advertised.listeners, log.dirs, replication settings, and ZooKeeper connection. Configure JVM settings per doc-8: 6 GB heap for D4s_v5, G1GC. Create systemd unit and health check handler. Dev config: PLAINTEXT listeners (TLS added in SP3.005).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/kafka-broker/ with tasks/, handlers/, defaults/, templates/ directories
- [ ] #2 Renders server.properties from Jinja2 template with configurable broker.id, listeners, log.dirs
- [ ] #3 Configures broker.rack from availability zone
- [ ] #4 Sets replication factor defaults: default.replication.factor=3, min.insync.replicas=2
- [ ] #5 Configures JVM heap settings (KAFKA_HEAP_OPTS=-Xmx6g -Xms6g for D4s_v5)
- [ ] #6 Creates Kafka log directory at /data/kafka/logs
- [ ] #7 Creates systemd unit file confluent-kafka.service
- [ ] #8 Handler restarts and verifies broker registration
- [ ] #9 Handler retries broker health check up to 6 times with 10s delay
- [ ] #10 Kafka JVM configured with 6 GB heap and G1GC per doc-8
- [ ] #11 site.yml updated to include kafka-broker role in Kafka Broker play after confluent-common
- [ ] #12 server.properties template is structured with sections for extensibility by later tasks (TLS, SASL, tiered storage, self-balancing)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Create role directory structure

```
ansible/roles/kafka-broker/
├── defaults/main.yml
├── vars/main.yml
├── tasks/
│   ├── main.yml
│   ├── configure.yml
│   └── service.yml
├── handlers/main.yml
└── templates/
    ├── server.properties.j2
    ├── kafka-env.sh.j2
    └── confluent-kafka.service.j2
```

### Step 2: Create defaults/main.yml

Define operator-overrideable defaults using `kafka_broker_` prefix:

```yaml
kafka_broker_port: 9092
kafka_broker_listeners: "PLAINTEXT://0.0.0.0:{{ kafka_broker_port }}"
kafka_broker_inter_broker_listener_name: PLAINTEXT
kafka_broker_listener_security_protocol_map: "PLAINTEXT:PLAINTEXT"
kafka_broker_log_dirs: "{{ data_mount_path }}/kafka/logs"
kafka_broker_log_segment_bytes: 1073741824
kafka_broker_log_retention_hours: 168
kafka_broker_log_retention_bytes: -1
kafka_broker_log_cleaner_threads: 2
kafka_broker_default_replication_factor: 3
kafka_broker_min_insync_replicas: 2
kafka_broker_num_network_threads: 4
kafka_broker_num_io_threads: 8
kafka_broker_socket_send_buffer_bytes: 102400
kafka_broker_socket_receive_buffer_bytes: 102400
kafka_broker_socket_request_max_bytes: 104857600
kafka_broker_num_partitions: 6
kafka_broker_controlled_shutdown_enable: true
kafka_broker_heap_size: '6g'
kafka_broker_config_dir: "{{ confluent_current_link | default('/opt/confluent/current') }}/etc/kafka"
kafka_broker_zookeeper_connect: "{{ groups['zookeeper'] | map('extract', hostvars, 'ansible_host') | join(':2181,') }}:2181/kafka"
kafka_broker_zookeeper_connection_timeout_ms: 18000
```

### Step 3: Create vars/main.yml

Computed/internal constants:

```yaml
kafka_broker_config_file: "{{ kafka_broker_config_dir }}/server.properties"
kafka_broker_env_file: "{{ kafka_broker_config_dir }}/kafka-env.sh"
kafka_broker_service_name: confluent-kafka
kafka_broker_bin_dir: "{{ confluent_current_link | default('/opt/confluent/current') }}/bin"
```

### Step 4: Create tasks/main.yml

```yaml
- name: Import Kafka broker configuration tasks
  ansible.builtin.import_tasks: configure.yml

- name: Import Kafka broker service tasks
  ansible.builtin.import_tasks: service.yml
```

### Step 5: Create tasks/configure.yml

1. **Render server.properties** from `server.properties.j2` to `{{ kafka_broker_config_file }}`. Owner `{{ kafka_user }}:{{ kafka_group }}`, mode `0640`. Notify `Restart confluent-kafka` on change.
2. **Deploy JVM environment script** from `kafka-env.sh.j2` to `{{ kafka_broker_env_file }}`. Owner `{{ kafka_user }}:{{ kafka_group }}`, mode `0755`. Notify `Restart confluent-kafka` on change.

### Step 6: Create templates/server.properties.j2

Per doc-8, render the complete Kafka broker configuration:

```properties
broker.id={{ kafka_broker_id }}
broker.rack={{ kafka_broker_rack | default('1') }}

listeners={{ kafka_broker_listeners }}
advertised.listeners=PLAINTEXT://{{ ansible_host }}:{{ kafka_broker_port }}
inter.broker.listener.name={{ kafka_broker_inter_broker_listener_name }}
listener.security.protocol.map={{ kafka_broker_listener_security_protocol_map }}

log.dirs={{ kafka_broker_log_dirs }}
log.segment.bytes={{ kafka_broker_log_segment_bytes }}
log.retention.hours={{ kafka_broker_log_retention_hours }}
log.retention.bytes={{ kafka_broker_log_retention_bytes }}
log.cleaner.threads={{ kafka_broker_log_cleaner_threads }}

default.replication.factor={{ kafka_broker_default_replication_factor }}
min.insync.replicas={{ kafka_broker_min_insync_replicas }}
num.partitions={{ kafka_broker_num_partitions }}

num.network.threads={{ kafka_broker_num_network_threads }}
num.io.threads={{ kafka_broker_num_io_threads }}
socket.send.buffer.bytes={{ kafka_broker_socket_send_buffer_bytes }}
socket.receive.buffer.bytes={{ kafka_broker_socket_receive_buffer_bytes }}
socket.request.max.bytes={{ kafka_broker_socket_request_max_bytes }}

controlled.shutdown.enable={{ kafka_broker_controlled_shutdown_enable | lower }}

zookeeper.connect={{ kafka_broker_zookeeper_connect }}
zookeeper.connection.timeout.ms={{ kafka_broker_zookeeper_connection_timeout_ms }}
```

The `kafka_broker_id` and `kafka_broker_rack` variables come from host_vars (SP3.003). `ansible_host` resolves to the VM's private IP via azure_rm.yml compose.

Note: The template uses a sectioned, extensible structure. SP3.005 (SASL), SP3.007 (Tiered Storage), and SP3.008 (Self-Balancing) will add conditional blocks to this template.

### Step 7: Create templates/kafka-env.sh.j2

Per doc-8, JVM settings for D4s_v5 (16 GiB RAM):

```bash
#!/bin/bash
export KAFKA_HEAP_OPTS="-Xmx{{ kafka_broker_heap_size }} -Xms{{ kafka_broker_heap_size }}"
export KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:MaxInlineLevel=15 -Djava.awt.headless=true"
export KAFKA_GC_LOG_OPTS="-Xlog:gc*:file=/var/log/kafka/kafka-gc.log:time,tags:filecount=10,filesize=100m"
```

### Step 8: Create templates/confluent-kafka.service.j2

```ini
[Unit]
Description=Confluent Kafka Broker
After=network.target confluent-zookeeper.service
Wants=confluent-zookeeper.service

[Service]
Type=simple
User={{ kafka_user }}
Group={{ kafka_group }}
EnvironmentFile={{ kafka_broker_env_file }}
ExecStart={{ kafka_broker_bin_dir }}/kafka-server-start {{ kafka_broker_config_file }}
Restart=on-failure
RestartSec=10
LimitNOFILE={{ kafka_nofile_limit | default(100000) }}
TimeoutStopSec=180

[Install]
WantedBy=multi-user.target
```

### Step 9: Create tasks/service.yml

1. **Create GC log directory**: `/var/log/kafka/` owned by `{{ kafka_user }}:{{ kafka_group }}`.
2. **Deploy systemd unit** from template to `/etc/systemd/system/confluent-kafka.service`. Notify `Restart confluent-kafka` on change.
3. **Reload systemd** daemon.
4. **Enable and start** the `confluent-kafka` service.

### Step 10: Create handlers/main.yml

```yaml
- name: Restart confluent-kafka
  ansible.builtin.systemd:
    name: "{{ kafka_broker_service_name }}"
    state: restarted
    daemon_reload: true
  become: true
  notify: Verify kafka broker health

- name: Verify kafka broker health
  ansible.builtin.command:
    cmd: >-
      {{ kafka_broker_bin_dir }}/kafka-broker-api-versions
      --bootstrap-server localhost:{{ kafka_broker_port }}
  register: broker_health
  until: broker_health.rc == 0
  retries: 6
  delay: 10
  changed_when: false
  become: true
  become_user: "{{ kafka_user }}"
```

### Step 11: Update site.yml

Add `kafka-broker` to the Kafka Broker play's roles list:

```yaml
- name: Configure Kafka broker nodes
  hosts: kafka_broker
  ...
  roles:
    - common
    - disk-setup
    - java
    - confluent-common
    - kafka-broker
```

### Key References
- Kafka IPs: 10.1.1.4 (kb-01), 10.1.1.5 (kb-02), 10.1.1.6 (kb-03) via kafkalab.internal DNS
- ZK connect string: zk-01.kafkalab.internal:2181,zk-02.kafkalab.internal:2181,zk-03.kafkalab.internal:2181/kafka
- Heap: 6 GB for D4s_v5 (16 GiB RAM) per doc-8
- Initial config: PLAINTEXT listeners (TLS/SASL added by SP3.005)
- Template must be extensible for SP3.005/SP3.007/SP3.008 additions
- Existing role pattern: roles/common/, roles/confluent-common/
<!-- SECTION:PLAN:END -->
