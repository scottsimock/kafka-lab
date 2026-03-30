---
id: TASK-30.8
title: SP3.001 — Ansible ZooKeeper Role
status: Done
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:27'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.4
references:
  - ansible/roles/zookeeper/
documentation:
  - doc-8
  - doc-13
parent_task_id: TASK-30
priority: high
ordinal: 3001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the ZooKeeper Ansible role at ansible/roles/zookeeper/ that configures and deploys a 3-node ZooKeeper ensemble. The role renders zookeeper.properties from a Jinja2 template, creates the myid file, configures ensemble membership, creates a systemd unit, and includes health check handlers. Configuration per doc-8: clientPort 2181, tickTime 2000, initLimit 5, syncLimit 2, autopurge enabled.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Role exists at ansible/roles/zookeeper/ with tasks/, handlers/, defaults/, templates/ directories
- [x] #2 Renders zookeeper.properties from Jinja2 template with configurable tickTime, initLimit, syncLimit
- [x] #3 Creates myid file with unique server ID for each node
- [x] #4 Creates data and txn log directories at /data/zookeeper/data and /data/zookeeper/log
- [x] #5 Configures ensemble membership (server.1, server.2, server.3) with correct IPs
- [x] #6 Creates systemd unit file confluent-zookeeper.service
- [x] #7 Handler restarts and verifies ZK health via ruok four-letter command
- [x] #8 Handler retries health check up to 6 times with 10s delay before failing
- [x] #9 ZooKeeper JVM configured with 1 GB heap and G1GC per doc-8
- [x] #10 site.yml updated to include zookeeper role in ZooKeeper play after confluent-common
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Create role directory structure

```
ansible/roles/zookeeper/
├── defaults/main.yml
├── vars/main.yml
├── tasks/
│   ├── main.yml
│   ├── configure.yml
│   └── service.yml
├── handlers/main.yml
└── templates/
    ├── zookeeper.properties.j2
    ├── zookeeper-env.sh.j2
    └── confluent-zookeeper.service.j2
```

### Step 2: Create defaults/main.yml

Define operator-overrideable defaults using `zookeeper_` prefix:

```yaml
zookeeper_client_port: 2181
zookeeper_tick_time: 2000
zookeeper_init_limit: 5
zookeeper_sync_limit: 2
zookeeper_max_client_cnxns: 0
zookeeper_autopurge_snap_retain_count: 3
zookeeper_autopurge_purge_interval: 24
zookeeper_data_dir: "{{ data_mount_path }}/zookeeper/data"
zookeeper_data_log_dir: "{{ data_mount_path }}/zookeeper/txn-log"
zookeeper_leader_port: 2888
zookeeper_election_port: 3888
zookeeper_admin_enable_server: true
zookeeper_admin_server_port: 8080
zookeeper_tcp_keepalive: true
zookeeper_heap_size: '1g'
zookeeper_config_dir: "{{ confluent_current_link | default('/opt/confluent/current') }}/etc/kafka"
```

### Step 3: Create vars/main.yml

Computed/internal constants (not operator-tunable):

```yaml
zookeeper_config_file: "{{ zookeeper_config_dir }}/zookeeper.properties"
zookeeper_env_file: "{{ zookeeper_config_dir }}/zookeeper-env.sh"
zookeeper_service_name: confluent-zookeeper
zookeeper_bin_dir: "{{ confluent_current_link | default('/opt/confluent/current') }}/bin"
```

### Step 4: Create tasks/main.yml

Follow existing pattern (see `roles/common/tasks/main.yml`, `roles/confluent-common/tasks/main.yml`):

```yaml
- name: Import ZooKeeper configuration tasks
  ansible.builtin.import_tasks: configure.yml

- name: Import ZooKeeper service tasks
  ansible.builtin.import_tasks: service.yml
```

### Step 5: Create tasks/configure.yml

1. **Render zookeeper.properties** from `zookeeper.properties.j2` to `{{ zookeeper_config_file }}`. Set owner `{{ kafka_user }}:{{ kafka_group }}`, mode `0640`. Notify `Restart confluent-zookeeper` handler on change.
2. **Create myid file** at `{{ zookeeper_data_dir }}/myid` using `ansible.builtin.copy` with `content: "{{ zookeeper_myid }}"`. The `zookeeper_myid` variable is set per-host in host_vars (see SP3.003). Owner `{{ kafka_user }}:{{ kafka_group }}`, mode `0644`.
3. **Deploy JVM environment script** from `zookeeper-env.sh.j2` to `{{ zookeeper_env_file }}`. Owner `{{ kafka_user }}:{{ kafka_group }}`, mode `0755`. Notify `Restart confluent-zookeeper` on change.

### Step 6: Create templates/zookeeper.properties.j2

Render the full ZooKeeper config per doc-8:

```properties
dataDir={{ zookeeper_data_dir }}
dataLogDir={{ zookeeper_data_log_dir }}
clientPort={{ zookeeper_client_port }}
tickTime={{ zookeeper_tick_time }}
initLimit={{ zookeeper_init_limit }}
syncLimit={{ zookeeper_sync_limit }}
maxClientCnxns={{ zookeeper_max_client_cnxns }}

{% for host in groups['zookeeper'] | sort %}
server.{{ hostvars[host]['zookeeper_myid'] }}={{ host }}:{{ zookeeper_leader_port }}:{{ zookeeper_election_port }}
{% endfor %}

autopurge.snapRetainCount={{ zookeeper_autopurge_snap_retain_count }}
autopurge.purgeInterval={{ zookeeper_autopurge_purge_interval }}
tcpKeepAlive={{ zookeeper_tcp_keepalive | lower }}
admin.enableServer={{ zookeeper_admin_enable_server | lower }}
admin.serverPort={{ zookeeper_admin_server_port }}
```

The ensemble loop iterates over the `zookeeper` inventory group. Each host's `zookeeper_myid` comes from host_vars. The `host` value resolves to the private IP via `ansible_host` compose in azure_rm.yml.

### Step 7: Create templates/zookeeper-env.sh.j2

```bash
#!/bin/bash
export KAFKA_HEAP_OPTS="-Xmx{{ zookeeper_heap_size }} -Xms{{ zookeeper_heap_size }}"
export KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -Djava.awt.headless=true"
export KAFKA_GC_LOG_OPTS="-Xlog:gc*:file=/var/log/kafka/zookeeper-gc.log:time,tags:filecount=10,filesize=100m"
```

### Step 8: Create templates/confluent-zookeeper.service.j2

```ini
[Unit]
Description=Confluent ZooKeeper
After=network.target

[Service]
Type=simple
User={{ kafka_user }}
Group={{ kafka_group }}
EnvironmentFile={{ zookeeper_env_file }}
ExecStart={{ zookeeper_bin_dir }}/zookeeper-server-start {{ zookeeper_config_file }}
Restart=on-failure
RestartSec=10
LimitNOFILE={{ kafka_nofile_limit | default(100000) }}
TimeoutStopSec=180

[Install]
WantedBy=multi-user.target
```

### Step 9: Create tasks/service.yml

1. **Create GC log directory**: `/var/log/kafka/` owned by `{{ kafka_user }}:{{ kafka_group }}` with `become: true`.
2. **Deploy systemd unit** from `confluent-zookeeper.service.j2` to `/etc/systemd/system/confluent-zookeeper.service`. Owner `root:root`, mode `0644`. Notify `Restart confluent-zookeeper` on change.
3. **Reload systemd** daemon.
4. **Enable and start** the `confluent-zookeeper` service.

### Step 10: Create handlers/main.yml

```yaml
- name: Restart confluent-zookeeper
  ansible.builtin.systemd:
    name: "{{ zookeeper_service_name }}"
    state: restarted
    daemon_reload: true
  become: true
  notify: Verify zookeeper health

- name: Verify zookeeper health
  ansible.builtin.command:
    cmd: bash -c "echo ruok | nc -w 5 localhost {{ zookeeper_client_port }}"
  register: zk_health
  until: zk_health.stdout == 'imok'
  retries: 6
  delay: 10
  changed_when: false
  become: false
```

### Step 11: Update site.yml

Add `zookeeper` to the ZooKeeper play's roles list (after `confluent-common`):

```yaml
- name: Configure ZooKeeper nodes
  hosts: zookeeper
  ...
  roles:
    - common
    - disk-setup
    - java
    - confluent-common
    - zookeeper
```

### Key References
- ZK IPs: 10.1.2.4 (zk-01), 10.1.2.5 (zk-02), 10.1.2.6 (zk-03) via kafkalab.internal DNS
- Heap: 1 GB for D2s_v5 (8 GiB RAM) per doc-8
- Install path: /opt/confluent/current (symlink set by confluent-common role)
- Data paths: /data/zookeeper/data, /data/zookeeper/txn-log (created by disk-setup role)
- Existing role pattern: roles/common/, roles/confluent-common/
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [SM] 2026-03-31T00:00:00Z
- Added dependency on TASK-30.4 (SP3.003 — Group/Host Variables). The ZK role template references `zookeeper_myid` from host_vars which SP3.003 creates. host_vars/ directory does not yet exist in the repo.
- **File contention**: site.yml is also modified by SP3.002 and SP3.004. TL should serialize tasks that update site.yml.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Created ansible/roles/zookeeper/ with full structure. zookeeper.properties.j2 renders ensemble server lines using hostvars loop over zookeeper group (sorted). myid file written per-host from host_vars. JVM env script sets 1g heap with G1GC. Systemd unit created. Handler chain: restart → ruok health check with 6 retries/10s delay. site.yml updated to include zookeeper role in ZooKeeper play after confluent-common.
<!-- SECTION:FINAL_SUMMARY:END -->
