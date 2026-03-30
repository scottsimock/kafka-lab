---
id: TASK-30.2
title: SP3.009 — Cluster Verification Playbook
status: In Progress
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:32'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.8
  - TASK-30.1
  - TASK-30.7
  - TASK-30.5
references:
  - ansible/playbooks/verify-cluster.yml
documentation:
  - doc-8
parent_task_id: TASK-30
priority: high
ordinal: 3009
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible playbook or task file that performs end-to-end verification of the Kafka cluster. Create a test topic, produce messages, consume messages, and verify broker/ZK health. This validates the entire SP2/SP3 deployment pipeline: VMs, ZooKeeper, brokers, security, and connectivity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Ansible playbook creates a test topic with RF=3 and 6 partitions
- [ ] #2 kafka-topics --describe shows topic with correct configuration
- [ ] #3 Producer can write messages to the test topic using SASL_SSL
- [ ] #4 Consumer can read messages from the test topic using SASL_SSL
- [ ] #5 Broker cluster status shows all 3 brokers registered
- [ ] #6 ZooKeeper ensemble status shows leader elected and quorum healthy
- [ ] #7 Playbook is idempotent — can be run multiple times without error
- [ ] #8 Playbook uses admin.properties for SASL_SSL authentication
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Create verification playbook

Create `ansible/playbooks/verify-cluster.yml`:

```yaml
---
# verify-cluster.yml — End-to-end cluster verification playbook
# Validates ZooKeeper ensemble, Kafka brokers, security, and message flow

- name: Verify ZooKeeper ensemble health
  hosts: zookeeper
  gather_facts: false
  any_errors_fatal: true
  tasks:
    - name: Import ZooKeeper verification tasks
      ansible.builtin.import_tasks: ../tasks/verify-zookeeper.yml

- name: Verify Kafka cluster health
  hosts: kafka_broker[0]
  gather_facts: false
  any_errors_fatal: true
  tasks:
    - name: Import Kafka cluster verification tasks
      ansible.builtin.import_tasks: ../tasks/verify-kafka.yml
```

### Step 2: Create ZooKeeper verification tasks

Create `ansible/tasks/verify-zookeeper.yml`:

1. **Check ZooKeeper health** — `echo ruok | nc -w 5 localhost 2181` and assert response is "imok".
2. **Check ZooKeeper mode** — `echo stat | nc -w 5 localhost 2181` and verify output contains "leader" or "follower" (ensemble has one leader).
3. **Verify quorum** — Assert at least 2 of 3 nodes are healthy (quorum = 2 for 3-node ensemble).

```yaml
- name: Check ZooKeeper health via ruok
  ansible.builtin.command:
    cmd: bash -c "echo ruok | nc -w 5 localhost {{ zookeeper_client_port | default(2181) }}"
  register: zk_ruok
  changed_when: false
  failed_when: zk_ruok.stdout != 'imok'
  become: false

- name: Check ZooKeeper mode via stat
  ansible.builtin.command:
    cmd: bash -c "echo stat | nc -w 5 localhost {{ zookeeper_client_port | default(2181) }}"
  register: zk_stat
  changed_when: false
  failed_when: "'Mode:' not in zk_stat.stdout"
  become: false

- name: Display ZooKeeper mode
  ansible.builtin.debug:
    msg: "{{ inventory_hostname }} mode: {{ zk_stat.stdout_lines | select('match', 'Mode:.*') | first | default('unknown') }}"
```

### Step 3: Create Kafka cluster verification tasks

Create `ansible/tasks/verify-kafka.yml` (runs on first broker only via `hosts: kafka_broker[0]`):

Define variables at task level:
```yaml
vars:
  verify_bin_dir: "{{ confluent_current_link | default('/opt/confluent/current') }}/bin"
  verify_admin_config: "{{ kafka_broker_config_dir | default('/opt/confluent/current/etc/kafka') }}/admin.properties"
  verify_topic_name: kafkalab-verify-test
  verify_topic_partitions: 6
  verify_topic_replication_factor: 3
  verify_bootstrap_server: "localhost:{{ kafka_broker_client_port | default(9092) }}"
```

Tasks:

1. **Verify broker cluster metadata**:
   ```yaml
   - name: List broker registrations
     ansible.builtin.command:
       cmd: >-
         {{ verify_bin_dir }}/kafka-metadata --snapshot /data/kafka/logs/__cluster_metadata-0/00000000000000000000.log --broker-registration
     # OR for ZK mode, use kafka-broker-api-versions:
       cmd: >-
         {{ verify_bin_dir }}/kafka-broker-api-versions
         --bootstrap-server {{ verify_bootstrap_server }}
         --command-config {{ verify_admin_config }}
     register: broker_list
     failed_when: broker_list.rc != 0
   ```

2. **Assert all 3 brokers registered**:
   - Parse output and verify 3 broker IDs present.

3. **Create test topic** (idempotent — use `--if-not-exists`):
   ```yaml
   - name: Create verification test topic
     ansible.builtin.command:
       cmd: >-
         {{ verify_bin_dir }}/kafka-topics
         --bootstrap-server {{ verify_bootstrap_server }}
         --command-config {{ verify_admin_config }}
         --create --if-not-exists
         --topic {{ verify_topic_name }}
         --partitions {{ verify_topic_partitions }}
         --replication-factor {{ verify_topic_replication_factor }}
   ```

4. **Describe test topic** and verify RF=3, partitions=6:
   ```yaml
   - name: Describe verification test topic
     ansible.builtin.command:
       cmd: >-
         {{ verify_bin_dir }}/kafka-topics
         --bootstrap-server {{ verify_bootstrap_server }}
         --command-config {{ verify_admin_config }}
         --describe --topic {{ verify_topic_name }}
     register: topic_describe
     failed_when: "'ReplicationFactor: 3' not in topic_describe.stdout"
   ```

5. **Produce test messages** using console producer:
   ```yaml
   - name: Produce test messages
     ansible.builtin.shell:
       cmd: >-
         echo -e "test-message-1\ntest-message-2\ntest-message-3" |
         {{ verify_bin_dir }}/kafka-console-producer
         --bootstrap-server {{ verify_bootstrap_server }}
         --producer.config {{ verify_admin_config }}
         --topic {{ verify_topic_name }}
   ```

6. **Consume test messages** using console consumer with timeout:
   ```yaml
   - name: Consume test messages
     ansible.builtin.command:
       cmd: >-
         {{ verify_bin_dir }}/kafka-console-consumer
         --bootstrap-server {{ verify_bootstrap_server }}
         --consumer.config {{ verify_admin_config }}
         --topic {{ verify_topic_name }}
         --from-beginning --max-messages 3 --timeout-ms 30000
     register: consumed
     failed_when: consumed.stdout_lines | length < 3
   ```

7. **Display verification summary**:
   ```yaml
   - name: Display cluster verification summary
     ansible.builtin.debug:
       msg: |
         Cluster verification PASSED:
         - ZooKeeper ensemble: healthy
         - Brokers registered: 3
         - Topic created: {{ verify_topic_name }} (RF=3, partitions=6)
         - Messages produced and consumed via SASL_SSL
   ```

### Step 4: Ensure idempotency

- Use `--if-not-exists` for topic creation.
- Use `--from-beginning` with `--max-messages` for bounded consume.
- The playbook can run repeatedly without side effects (beyond creating the test topic once).

### Key References
- admin.properties created by SP3.005 at /opt/confluent/current/etc/kafka/admin.properties
- SASL_SSL authentication required for all commands
- Test topic: kafkalab-verify-test, RF=3, 6 partitions
- Broker API versions command for health check
- Console producer/consumer for end-to-end message flow test
- ZooKeeper health via ruok/stat four-letter commands
<!-- SECTION:PLAN:END -->
