---
id: TASK-30.7
title: SP3.004 — TLS Certificate Generation Role
status: Done
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:30'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.8
  - TASK-30.1
references:
  - ansible/roles/tls-certs/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: high
ordinal: 3004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible role at ansible/roles/tls-certs/ that generates TLS certificates for Kafka cluster security. Generate a private CA, then per-node server certificates signed by the CA. Create JKS keystores and truststores. The role runs on the Ansible controller and distributes certificates to target nodes. Certificates include SAN entries for private IPs. Per doc-11, all Kafka components need TLS for SASL_SSL protocol.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Role exists at ansible/roles/tls-certs/ with tasks/, templates/, files/ directories
- [x] #2 Generates a private CA key and self-signed CA certificate
- [x] #3 Generates per-node server certificates signed by the CA
- [x] #4 Creates JKS keystores and truststores for each Kafka component
- [x] #5 Stores CA cert in a shared truststore
- [x] #6 Certificates use SAN entries with private IPs and hostnames
- [x] #7 All key material placed in /etc/kafka/ssl/ on target nodes
- [x] #8 extendedKeyUsage includes both serverAuth and clientAuth per doc-11
- [x] #9 Certificates generated on Ansible controller and distributed to target nodes
- [x] #10 SSL directory permissions set to 0750 (dir) and 0640 (files) owned by kafka:kafka
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Create role directory structure

```
ansible/roles/tls-certs/
├── defaults/main.yml
├── vars/main.yml
├── tasks/
│   ├── main.yml
│   ├── ca.yml
│   ├── node-certs.yml
│   └── distribute.yml
├── handlers/main.yml
├── templates/
│   └── openssl-san.cnf.j2
└── files/
    └── .gitkeep
```

### Step 2: Create defaults/main.yml

```yaml
tls_cert_dir: /etc/kafka/ssl
tls_ca_cn: 'KafkaLabCA'
tls_ca_ou: 'KafkaLab'
tls_ca_o: 'KafkaLab'
tls_ca_c: 'US'
tls_ca_validity_days: 3650
tls_node_validity_days: 365
tls_keystore_password: "{{ vault_tls_keystore_password | default('changeit') }}"
tls_truststore_password: "{{ vault_tls_truststore_password | default('changeit') }}"
tls_key_password: "{{ vault_tls_key_password | default('changeit') }}"
tls_ca_password: "{{ vault_tls_ca_password | default('changeit') }}"
tls_key_size: 2048
tls_key_algorithm: RSA
tls_dns_domain: kafkalab.internal
tls_generate_on_controller: true
tls_local_cert_dir: /opt/confluent/tls-staging
```

### Step 3: Create vars/main.yml

```yaml
tls_ca_key: "{{ tls_local_cert_dir }}/ca.key"
tls_ca_cert: "{{ tls_local_cert_dir }}/ca.crt"
tls_truststore_file: kafka.truststore.jks
tls_keystore_prefix: kafka
```

### Step 4: Create tasks/main.yml

```yaml
- name: Import CA generation tasks
  ansible.builtin.import_tasks: ca.yml

- name: Import node certificate generation tasks
  ansible.builtin.import_tasks: node-certs.yml

- name: Import certificate distribution tasks
  ansible.builtin.import_tasks: distribute.yml
```

### Step 5: Create tasks/ca.yml

Run on the Ansible controller (delegate_to: localhost, run_once: true):

1. **Create staging directory** `{{ tls_local_cert_dir }}` on controller.
2. **Generate CA private key** using `community.crypto.openssl_privatekey` or `openssl genrsa` command:
   - `openssl genrsa -aes256 -passout pass:{{ tls_ca_password }} -out {{ tls_ca_key }} {{ tls_key_size }}`
3. **Generate self-signed CA certificate**:
   - `openssl req -new -x509 -key {{ tls_ca_key }} -passin pass:{{ tls_ca_password }} -out {{ tls_ca_cert }} -days {{ tls_ca_validity_days }} -subj "/CN={{ tls_ca_cn }}/OU={{ tls_ca_ou }}/O={{ tls_ca_o }}/C={{ tls_ca_c }}"`
4. **Create shared truststore** (JKS) containing only the CA cert:
   - `keytool -import -keystore {{ tls_local_cert_dir }}/{{ tls_truststore_file }} -alias CARoot -file {{ tls_ca_cert }} -storepass {{ tls_truststore_password }} -noprompt`

### Step 6: Create tasks/node-certs.yml

Loop over all Kafka platform hosts (ZK + brokers + schema_registry + kafka_connect). For each node, run on controller (delegate_to: localhost):

1. **Generate node keystore with keypair**:
   ```
   keytool -genkey -keystore {{ node }}.keystore.jks -alias {{ node }}
     -validity {{ tls_node_validity_days }} -keyalg {{ tls_key_algorithm }} -keysize {{ tls_key_size }}
     -storepass {{ tls_keystore_password }} -keypass {{ tls_key_password }}
     -dname "CN={{ node }}.{{ tls_dns_domain }},OU={{ tls_ca_ou }},O={{ tls_ca_o }},C={{ tls_ca_c }}"
     -ext SAN=DNS:{{ node }}.{{ tls_dns_domain }},IP:{{ hostvars[node]['ansible_host'] }}
   ```
2. **Export CSR** from keystore:
   ```
   keytool -certreq -keystore {{ node }}.keystore.jks -alias {{ node }} -file {{ node }}.csr -storepass {{ tls_keystore_password }}
   ```
3. **Render OpenSSL SAN extension config** from `openssl-san.cnf.j2` with DNS and IP SANs for the node.
4. **Sign CSR with CA**:
   ```
   openssl x509 -req -CA {{ tls_ca_cert }} -CAkey {{ tls_ca_key }}
     -in {{ node }}.csr -out {{ node }}-signed.crt
     -days {{ tls_node_validity_days }} -CAcreateserial
     -passin pass:{{ tls_ca_password }}
     -extfile {{ node }}-san.cnf -extensions v3_req
   ```
   The SAN extension config must include `extendedKeyUsage=serverAuth,clientAuth` (both required per doc-11 for inter-broker mTLS).
5. **Import CA cert into node keystore**:
   ```
   keytool -import -keystore {{ node }}.keystore.jks -alias CARoot -file {{ tls_ca_cert }} -storepass {{ tls_keystore_password }} -noprompt
   ```
6. **Import signed cert into node keystore**:
   ```
   keytool -import -keystore {{ node }}.keystore.jks -alias {{ node }} -file {{ node }}-signed.crt -storepass {{ tls_keystore_password }}
   ```

### Step 7: Create templates/openssl-san.cnf.j2

```ini
[v3_req]
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:{{ cert_node_fqdn }}, IP:{{ cert_node_ip }}
```

### Step 8: Create tasks/distribute.yml

For each target node:

1. **Create SSL directory** `{{ tls_cert_dir }}` on target. Owner `{{ kafka_user }}:{{ kafka_group }}`, mode `0750`.
2. **Copy node keystore** to `{{ tls_cert_dir }}/{{ node }}.keystore.jks`. Mode `0640`.
3. **Copy truststore** to `{{ tls_cert_dir }}/{{ tls_truststore_file }}`. Mode `0640`.
4. **Set ownership** to `{{ kafka_user }}:{{ kafka_group }}`.

### Step 9: Create handlers/main.yml

Empty or minimal — TLS cert changes trigger broker/ZK restarts via their own handlers, not the TLS role.

### Step 10: Update site.yml

Add a new play before the component-specific plays, or add `tls-certs` role to each component play. Recommended: add as a role in each play after `confluent-common`:

```yaml
roles:
  - common
  - disk-setup
  - java
  - confluent-common
  - tls-certs
  - zookeeper    # or kafka-broker, etc.
```

### Key References
- Target cert directory: /etc/kafka/ssl/ on all nodes
- CA generates on controller (delegate_to: localhost)
- SAN must include both DNS (node.kafkalab.internal) and IP
- extendedKeyUsage must include serverAuth AND clientAuth (doc-11)
- Passwords should reference vault variables (vault_tls_*_password)
- All nodes: zk-01 through zk-03, kb-01 through kb-03, plus schema_registry and kafka_connect hosts
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Created ansible/roles/tls-certs/ with CA generation (delegate_to: localhost, run_once), per-node cert generation with SAN extension (serverAuth+clientAuth per doc-11), and certificate distribution to /etc/kafka/ssl/ (mode 0750/0640, kafka:kafka). openssl-san.cnf.j2 template used for signing. site.yml updated with tls-certs in both ZK and Kafka broker plays.
<!-- SECTION:FINAL_SUMMARY:END -->
