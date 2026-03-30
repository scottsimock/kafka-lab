---
id: doc-11
title: SP0.005 — Kafka Security and Authentication
type: other
created_date: '2026-03-30 15:49'
---
# SP0.005 — Kafka Security and Authentication

## Executive Summary

Apache Kafka and Confluent Platform 7.8.x implement security through three independent but complementary layers. The first layer, **encryption in transit**, uses TLS/SSL to protect all data moving between brokers and clients. By default, Kafka communicates in `PLAINTEXT`; production deployments must configure TLS on all listeners. The second layer, **authentication**, identifies who is making a request. Kafka supports multiple authentication mechanisms: SASL variants (PLAIN, SCRAM-SHA-256/512, GSSAPI/Kerberos, OAUTHBEARER) and mutual TLS (mTLS), where both sides present certificates. The third layer, **authorization**, determines what authenticated principals may do. Kafka's native authorization model uses Access Control Lists (ACLs), while Confluent Platform extends this with Role-Based Access Control (RBAC) backed by the Metadata Service (MDS). All three layers are independently configured and must be explicitly enabled — there is no secure-by-default state.

For the kafka-lab project the networking context is decisive. All brokers, clients, and inter-cluster links reside inside Azure Private VNets with no public endpoints. This eliminates the primary attack vector that TLS encryption is designed to mitigate for Internet-exposed clusters — eavesdropping over untrusted networks. However, TLS remains mandatory for two reasons: first, Azure private networking does not protect against lateral movement within the VNet (compromised VM can still sniff intra-VNet traffic without TLS); second, Cluster Linking across the three regions (southcentralus → mexicocentral → canadaeast) traverses Azure backbone VNet peering, which, while private, is not end-to-end encrypted by default at the application layer. All authentication mechanisms should therefore be combined with `SASL_SSL` or `SSL` protocols — never `SASL_PLAINTEXT` or `PLAINTEXT`.

The recommended authentication model for kafka-lab is **SASL/SCRAM-SHA-512 with SASL_SSL** for client-to-broker and broker-to-broker (inter-broker) authentication, combined with **Confluent RBAC** for fine-grained authorization, and supplemented with **mTLS** for Cluster Linking links between regions. SASL/SCRAM-SHA-512 integrates cleanly with KRaft (Confluent Platform 7.8.x ships KRaft-first), avoids the complexity of a PKI CA for routine client credential management, and supports credential rotation without rolling restarts. RBAC layered on top replaces hundreds of hand-crafted ACL entries with role-based assignments that scale as the number of services and teams grows. mTLS for Cluster Linking is specifically recommended because link credentials are static, long-lived machine identities — exactly the use case where certificate-based identity is stronger than password-based identity.

---

## SASL/SCRAM Analysis

### Overview

SASL/SCRAM (Salted Challenge Response Authentication Mechanism) is specified in RFC 5802. It is a challenge-response mechanism: the client and server exchange challenge and response messages such that the server authenticates the client without ever transmitting or storing the plain-text password. The server stores a salted, iterated hash of the credential, making offline dictionary attacks against the credential store significantly harder than with PLAIN. Confluent Platform 7.8.x supports `SCRAM-SHA-256` and `SCRAM-SHA-512`; always use SHA-512 (minimum 4096 iterations) for production.

### Setup Steps (KRaft Mode — CP 7.8.x)

KRaft replaces ZooKeeper in Confluent Platform 7.8.x. SCRAM credentials in KRaft are stored in the metadata quorum. Controllers cannot use SCRAM for controller-to-controller communication; they use `SSL`. Brokers can use SCRAM for broker-to-broker and broker-to-client authentication.

**Step 1 — Create cluster and bootstrap SCRAM credentials on each controller:**

```bash
# Generate cluster ID
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"

# Format storage on each controller node, injecting SCRAM credentials
# This must be run on EVERY controller before first startup
bin/kafka-storage.sh format \
  --config /etc/kafka/controller.properties \
  --cluster-id $KAFKA_CLUSTER_ID \
  --release-version 3.8 \
  --add-scram 'SCRAM-SHA-512=[name=broker-internal,password=<broker-password>]' \
  --add-scram 'SCRAM-SHA-512=[name=admin,password=<admin-password>]'
```

**Step 2 — Broker `server.properties` SASL configuration:**

```properties
# Listeners: separate ports for inter-broker (INTERNAL) and client (CLIENT)
listeners=INTERNAL://0.0.0.0:9093,CLIENT://0.0.0.0:9092
advertised.listeners=INTERNAL://<broker-fqdn>:9093,CLIENT://<broker-fqdn>:9092
listener.security.protocol.map=INTERNAL:SASL_SSL,CLIENT:SASL_SSL

# Inter-broker uses SCRAM-SHA-512
security.inter.broker.protocol=SASL_SSL
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-512

# JAAS for broker (inline, preferred over separate JAAS file)
listener.name.internal.scram-sha-512.sasl.jaas.config=\
  org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="broker-internal" \
  password="<broker-password>";

# TLS settings (see mTLS section for keystore/truststore details)
ssl.truststore.location=/var/private/ssl/kafka.server.truststore.jks
ssl.truststore.password=<truststore-password>
ssl.keystore.location=/var/private/ssl/kafka.server.keystore.jks
ssl.keystore.password=<keystore-password>
ssl.key.password=<key-password>
```

**Step 3 — Add/manage credentials at runtime (post-startup):**

```bash
# Add a new application user
kafka-configs --bootstrap-server broker1:9093 \
  --command-config admin.properties \
  --alter \
  --add-config 'SCRAM-SHA-512=[iterations=8192,password=<app-password>]' \
  --entity-type users \
  --entity-name app-service-a

# Rotate a credential (same command, new password)
kafka-configs --bootstrap-server broker1:9093 \
  --command-config admin.properties \
  --alter \
  --add-config 'SCRAM-SHA-512=[iterations=8192,password=<new-password>]' \
  --entity-type users \
  --entity-name app-service-a

# Delete a credential (revoke access)
kafka-configs --bootstrap-server broker1:9093 \
  --command-config admin.properties \
  --alter \
  --delete-config 'SCRAM-SHA-512' \
  --entity-type users \
  --entity-name app-service-a

# List credentials
kafka-configs --bootstrap-server broker1:9093 \
  --command-config admin.properties \
  --describe \
  --entity-type users \
  --entity-name app-service-a
```

### Credential Management

- Credentials are stored in the KRaft metadata log, replicated across all controllers.
- For the initial set of users (broker-to-broker), credentials must be injected via `kafka-storage.sh --add-scram` before first startup.
- Post-startup users are managed with `kafka-configs --bootstrap-server`.
- Credentials do **not** require a broker restart to take effect — changes propagate through metadata replication.
- Credential rotation is non-disruptive: update the credential in Kafka, then update the client configuration.

### Pros and Cons

| Factor | Assessment |
|---|---|
| **Security strength** | Strong — SHA-512 with salting prevents plain-text exposure and rainbow-table attacks |
| **Setup complexity** | Low — no PKI infrastructure required |
| **Operational overhead** | Low — runtime credential management, no cert rotation |
| **KRaft compatibility** | Full for broker-to-broker and client; controllers use SSL for controller-to-controller |
| **Credential rotation** | Non-disruptive; no rolling restart needed |
| **Revocation speed** | Immediate via `kafka-configs` |
| **Multi-tenancy** | Clean — each service gets its own named credential |
| **Cluster Linking** | Supported — SASL_SSL with SCRAM works for link auth |
| **Audit trail** | Username visible in Kafka logs and ACL/RBAC principal mappings |
| **Cons** | Passwords must be securely stored (Azure Key Vault recommended); no hardware-backed identity |

### When to Use

- Client-to-broker authentication for all application services.
- Broker-to-broker (inter-broker) authentication within a cluster.
- Cluster Linking when certificate management is not warranted for a specific link.
- Environments where PKI infrastructure is unavailable or excessive for the risk profile.

---

## mTLS Analysis

### Overview

Mutual TLS (mTLS) extends one-way TLS (where the client verifies the server) to two-way authentication where the broker also verifies the client's certificate. The client's identity is derived from the certificate's Subject Distinguished Name (DN) or Subject Alternative Name (SAN). In Confluent Platform, the principal mapped from an mTLS certificate is the certificate's Subject field (e.g., `CN=service-a,OU=kafka-lab`), which then participates in ACL and RBAC authorization exactly like a SASL-derived principal.

### CA Setup

For kafka-lab, use a **private CA** (not a public CA). The CA cert is placed in the truststore of every broker and client; certificates signed by this CA are automatically trusted.

```bash
# 1. Generate CA key and self-signed certificate (valid 10 years — rotate annually)
openssl req -new -x509 -keyout ca.key -out ca.crt -days 3650 \
  -subj "/CN=KafkaLabCA/OU=KafkaLab/O=Org/C=US" \
  -passout pass:<ca-passphrase>

# 2. Per-broker: generate keystore and CSR
keytool -genkey -keystore kafka.broker1.keystore.jks \
  -alias broker1 -validity 365 -keyalg RSA -keysize 2048 \
  -storepass <keystore-pass> -keypass <key-pass> \
  -dname "CN=broker1.kafkalab.internal,OU=kafka-lab,O=Org,C=US" \
  -ext SAN=DNS:broker1.kafkalab.internal,IP:10.0.0.4

keytool -certreq -keystore kafka.broker1.keystore.jks \
  -alias broker1 -file broker1.csr \
  -storepass <keystore-pass>

# 3. CA signs the CSR
openssl x509 -req -CA ca.crt -CAkey ca.key \
  -in broker1.csr -out broker1-signed.crt \
  -days 365 -CAcreateserial -passin pass:<ca-passphrase> \
  -extensions v3_req \
  -extfile <(printf "[v3_req]\nextendedKeyUsage=serverAuth,clientAuth\nsubjectAltName=DNS:broker1.kafkalab.internal")

# 4. Import CA cert and signed cert into the broker keystore
keytool -import -keystore kafka.broker1.keystore.jks \
  -alias CARoot -file ca.crt -storepass <keystore-pass> -noprompt
keytool -import -keystore kafka.broker1.keystore.jks \
  -alias broker1 -file broker1-signed.crt -storepass <keystore-pass>

# 5. Create shared truststore (all brokers and clients share this)
keytool -import -keystore kafka.truststore.jks \
  -alias CARoot -file ca.crt -storepass <truststore-pass> -noprompt
```

> **Important:** Certificates must include `extendedKeyUsage=serverAuth,clientAuth` because every broker acts as both client and server in inter-broker communication. A cert with only `serverAuth` will cause the TLS handshake to fail.

### Broker Configuration for mTLS

```properties
listeners=SSL://0.0.0.0:9093
advertised.listeners=SSL://<broker-fqdn>:9093
security.inter.broker.protocol=SSL

ssl.truststore.location=/var/private/ssl/kafka.truststore.jks
ssl.truststore.password=<truststore-pass>
ssl.keystore.location=/var/private/ssl/kafka.broker1.keystore.jks
ssl.keystore.password=<keystore-pass>
ssl.key.password=<key-pass>
ssl.client.auth=required

# Enable hostname verification (default: https)
ssl.endpoint.identification.algorithm=https
```

### Certificate Rotation

Certificates have a finite validity period (365 days recommended). The rotation procedure is:

1. Generate a new key pair and CSR for the target broker/client.
2. Have the CA sign the new CSR.
3. Import the new signed cert into a new keystore (do not replace in place).
4. Update the broker/client configuration to point to the new keystore path.
5. Perform a rolling restart of brokers — one broker at a time, verifying health before proceeding.
6. For clients: deploy updated `ssl.keystore.location` to the client configuration and restart.

For Cluster Linking with PEM-format certs, rotation does not require a full keystore replacement — update the PEM inline in the link configuration using `kafka-cluster-links --alter`.

### CA Certificate Rotation

CA rotation is the most disruptive operation. The procedure is:

1. Generate new CA cert and key.
2. Add both old and new CA certs to the truststore (dual-CA trust period).
3. Re-issue all leaf certificates under the new CA.
4. Perform rolling restarts to deploy new keystores.
5. Once all certs are re-issued, remove the old CA from the truststore.
6. Final rolling restart to remove old CA from trust.

### Pros and Cons

| Factor | Assessment |
|---|---|
| **Security strength** | Very high — hardware-backed identity possible (Azure Key Vault HSM) |
| **Setup complexity** | High — requires PKI infrastructure, CA management |
| **Operational overhead** | High — certificate rotation requires rolling restarts |
| **KRaft compatibility** | Full — SSL is the only option for controller-to-controller auth |
| **Credential rotation** | Disruptive — rolling restart required per broker cert change |
| **Revocation speed** | Slow — CRL/OCSP or ACL deny rules; no instant revocation |
| **Multi-tenancy** | Moderate — each service needs its own cert; CN must be unique |
| **Cluster Linking** | Excellent — PEM inline format simplifies link-level cert config |
| **Audit trail** | Certificate DN visible in broker logs and principal mappings |
| **Cons** | PKI management overhead; cert rotation requires coordination; revocation is complex |

### When to Use

- Controller-to-controller authentication (mandatory in KRaft; SCRAM not supported here).
- Cluster Linking inter-region authentication (long-lived machine-to-machine identity).
- Environments with existing PKI infrastructure (Azure Key Vault + Managed HSM).
- High-security scenarios where hardware-backed keys are required.

---

## Confluent RBAC

### Overview

Confluent Role-Based Access Control (RBAC) is an authorization layer built on top of the Kafka authorization framework. It replaces or supplements native Kafka ACLs with predefined roles bound to principals across multiple Confluent Platform resources — Kafka topics, consumer groups, Schema Registry, ksqlDB, Connect, Flink, and Control Center — all managed through a single central authority, the Metadata Service (MDS).

### Metadata Service (MDS) Setup

MDS runs on Confluent Server (the Confluent distribution of the Kafka broker). Every broker in the cluster must be configured with MDS.

```properties
# Enable MDS on all brokers
confluent.metadata.server.listeners=http://0.0.0.0:8090
confluent.metadata.server.advertised.listeners=http://<broker-fqdn>:8090
confluent.metadata.server.authentication.method=BEARER

# Token service (for bearer tokens)
confluent.metadata.server.token.key.path=/var/private/ssl/tokenKeypair.pem

# LDAP integration (for user/group management)
confluent.metadata.server.ldap.ssl.enabled=true
ldap.java.naming.provider.url=ldaps://ldap.kafkalab.internal:636
ldap.java.naming.security.principal=CN=kafka-ldap,OU=ServiceAccounts,DC=kafkalab,DC=internal
ldap.java.naming.security.credentials=<ldap-password>
ldap.user.search.base=OU=Users,DC=kafkalab,DC=internal
ldap.user.name.attribute=sAMAccountName
ldap.group.search.base=OU=Groups,DC=kafkalab,DC=internal
ldap.group.name.attribute=cn
ldap.group.member.attribute=member

# Confluent Server Authorizer (enables RBAC + ACL co-existence)
authorizer.class.name=io.confluent.kafka.security.authorizer.ConfluentServerAuthorizer
confluent.authorizer.access.rule.providers=CONFLUENT,ZK_ACL
super.users=User:admin;User:mds-bootstrap
```

### Predefined Roles

| Role | Scope | Permissions | Typical Use |
|---|---|---|---|
| `super.user` | Cluster (bootstrap) | All resources, no enforcement | Initial bootstrap only; not a true RBAC role |
| `SystemAdmin` | Cluster | Full access — view/manage role bindings, monitor, read, write, manage all resources | Initial setup only; 1–2 users max |
| `ClusterAdmin` | Cluster | Create/manage topics and brokers; no data read/write | Platform ops team |
| `UserAdmin` | Cluster | Manage role bindings for users and groups | IAM/security team |
| `SecurityAdmin` | Cluster | Manage encryption, audit logs, security config | Security team |
| `AuditAdmin` | Cluster | Manage audit log configuration | Compliance team |
| `Operator` | Cluster | Monitor health; pause/resume/scale connectors | SRE/ops team |
| `ResourceOwner` | Resource | Full access to specific resource (read, write, manage, delegate) | Topic/schema owners |
| `DeveloperRead` | Resource | Read a specific resource (topic, schema, etc.) | Consumer services |
| `DeveloperWrite` | Resource | Write to a specific resource | Producer services |
| `DeveloperManage` | Resource | Manage (configure) a specific resource | Developer leads |

### Role Binding Commands

```bash
# Grant SystemAdmin to the ops user (bootstrap)
confluent iam rbac role-binding create \
  --principal User:kafka-admin \
  --role SystemAdmin \
  --kafka-cluster-id <cluster-id>

# Grant ResourceOwner on a topic to a service account
confluent iam rbac role-binding create \
  --principal User:payments-service \
  --role ResourceOwner \
  --kafka-cluster-id <cluster-id> \
  --resource Topic:payments.transactions

# Grant DeveloperRead on a topic prefix to a consumer group owner
confluent iam rbac role-binding create \
  --principal User:analytics-team \
  --role DeveloperRead \
  --kafka-cluster-id <cluster-id> \
  --resource Topic:payments. \
  --prefix

# Grant DeveloperWrite on Schema Registry subject
confluent iam rbac role-binding create \
  --principal User:payments-service \
  --role DeveloperWrite \
  --schema-registry-cluster-id <sr-cluster-id> \
  --resource Subject:payments.transactions-value

# List all role bindings for a principal
confluent iam rbac role-binding list \
  --principal User:payments-service \
  --kafka-cluster-id <cluster-id>

# Remove a role binding
confluent iam rbac role-binding delete \
  --principal User:payments-service \
  --role DeveloperRead \
  --kafka-cluster-id <cluster-id> \
  --resource Topic:payments.transactions
```

### RBAC and ACL Co-existence

RBAC does not prevent existing Kafka ACLs from working. The Confluent Server Authorizer evaluates both RBAC role bindings and native ACLs. A principal is authorized if either the RBAC binding or an ACL allows the operation. This allows incremental migration: existing ACL-secured clusters can add RBAC incrementally without breaking any existing access.

RBAC does **not** support DENY rules. To deny access, use native ACL `--deny-principal` entries.

---

## Authentication Model Comparison

| Factor | SASL/SCRAM-SHA-512 | mTLS | Confluent RBAC (with MDS) | SASL/SCRAM + RBAC (recommended) |
|---|---|---|---|---|
| **Setup complexity** | Low | High (PKI required) | High (MDS + LDAP setup) | Medium (SCRAM + MDS; no PKI for clients) |
| **Security level** | High | Very High | High (authorization layer) | Very High |
| **Ops overhead** | Low | High (cert rotation, rolling restart) | Medium (MDS uptime, LDAP sync) | Medium |
| **Credential rotation** | Non-disruptive (kafka-configs) | Disruptive (rolling restart) | Non-disruptive (role bindings) | Non-disruptive |
| **Cluster Linking support** | Yes (SASL_SSL on link) | Yes (mTLS on link, PEM inline) | N/A (authorization only) | Yes — SCRAM for link auth |
| **KRaft controller-to-controller** | No (SSL only) | Yes | N/A | mTLS for controllers |
| **Multi-cluster management** | Per-cluster credentials | Per-cluster PKI | Centralized via MDS | Centralized via MDS + per-cluster SCRAM |
| **Audit trail quality** | Username in logs | Certificate DN in logs | Role binding audit log in MDS | Username + role audit in MDS |
| **Private VNet suitability** | Excellent | Excellent | Excellent | Excellent |
| **Recommended for kafka-lab** | Yes (clients + inter-broker) | Yes (controllers + Cluster Linking) | Yes (authorization) | ✅ Primary recommendation |

---

## Recommendation

### Recommended Model: SASL/SCRAM-SHA-512 + mTLS (controllers/links) + Confluent RBAC

For the kafka-lab project, the recommended security architecture is a layered model:

**Authentication:**
- **SASL/SCRAM-SHA-512 over SASL_SSL** for all client-to-broker connections and broker-to-broker (inter-broker) connections. This provides strong, operationally simple authentication with non-disruptive credential rotation.
- **mTLS (SSL)** for controller-to-controller communication within each cluster (mandatory in KRaft — SCRAM is not supported for this path).
- **mTLS with PEM-format certificates** for Cluster Linking between the three Azure regions. Links are long-lived machine-to-machine connections; certificate-based identity is more appropriate than shared passwords, and the PEM inline format in Confluent Platform 7.8.x means no shared filesystem dependency across brokers.

**Authorization:**
- **Confluent RBAC** for all authorization. RBAC provides centralized, auditable, role-based access control across all Confluent Platform components (Kafka, Schema Registry, Connect, Control Center). RBAC scales as the number of services and teams grows, avoiding the maintenance burden of hundreds of individual ACL entries.

**Rationale for this project:**
1. **Private VNet context:** All communication is within Azure private networking. This reduces the urgency for mTLS for every single client, making SASL/SCRAM an appropriate and simpler choice for client auth.
2. **UAMI environment:** Azure resources authenticate to Azure services via UAMI. Kafka itself does not natively consume UAMI tokens (unlike Azure Event Hubs, which supports OAuth with Azure AD). Therefore, application services must maintain Kafka-specific credentials. SCRAM credentials stored in Azure Key Vault and injected at runtime (via Ansible or Kubernetes secrets) are the appropriate pattern.
3. **KRaft-first (7.8.x):** KRaft mandates mTLS for controllers, so a PKI CA is already required. Extending that CA to cover Cluster Linking certificates is a natural reuse with minimal additional overhead.
4. **Multi-region Cluster Linking:** The three-region topology (southcentralus → mexicocentral → canadaeast) involves long-lived, machine-identity links. mTLS certificates stored in Azure Key Vault HSM, with automated rotation via Azure Certificate Manager, provide the right identity model for these infrastructure-level connections.
5. **RBAC for scale:** As the project grows, RBAC prevents ACL sprawl. Starting with RBAC from day one avoids a painful migration later.

---

## ACL Configuration Patterns

> **Note:** With Confluent RBAC enabled, prefer role bindings over raw ACLs for all new access grants. Use native ACLs only for DENY rules (RBAC does not support DENY) or for components not covered by RBAC.

### Setup: Command Config File

```properties
# admin.properties — used with --command-config flag
bootstrap.servers=broker1:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="admin" \
  password="<admin-password>";
ssl.truststore.location=/etc/kafka/ssl/truststore.jks
ssl.truststore.password=<truststore-pass>
```

### Topic-Level ACLs

```bash
# Allow a producer to write to a specific topic
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:payments-producer \
  --operation Write --operation Describe \
  --topic payments.transactions

# Allow a consumer to read from a topic
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:payments-consumer \
  --operation Read --operation Describe \
  --topic payments.transactions

# Allow access to all topics under a prefix (Prefixed pattern)
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:analytics-service \
  --operation Read --operation Describe \
  --topic payments. \
  --resource-pattern-type prefixed

# Allow topic creation (for services that auto-create topics)
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:app-service \
  --operation Create \
  --cluster
```

### Consumer Group ACLs

```bash
# Allow a consumer to join and manage offsets in a specific group
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:payments-consumer \
  --operation Read \
  --group payments-consumer-group

# Allow access to all consumer groups under a prefix
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:analytics-service \
  --operation Read \
  --group analytics- \
  --resource-pattern-type prefixed

# Full consumer pattern: must grant both topic Read and group Read
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:analytics-service \
  --operation Read --operation Describe \
  --topic events. \
  --resource-pattern-type prefixed

kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:analytics-service \
  --operation Read \
  --group analytics- \
  --resource-pattern-type prefixed
```

### Transactional Producer ACLs

Transactional producers require ACLs on both the `TransactionalId` resource and the target topic:

```bash
# Allow transactional writes (Write + Describe on TransactionalId)
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:payments-tx-producer \
  --operation Write --operation Describe \
  --transactional-id payments-tx-

kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:payments-tx-producer \
  --operation IdempotentWrite \
  --cluster

kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:payments-tx-producer \
  --operation Write --operation Describe \
  --topic payments.transactions
```

### Inter-Service ACL Examples

```bash
# Schema Registry service account: full Schema Registry access via RBAC
confluent iam rbac role-binding create \
  --principal User:schema-registry \
  --role ResourceOwner \
  --schema-registry-cluster-id <sr-id> \
  --resource Subject:

# Kafka Connect worker: describe cluster + manage internal topics
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:connect-worker \
  --operation Read --operation Write --operation Create --operation Describe \
  --topic connect- \
  --resource-pattern-type prefixed

kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties \
  --add --allow-principal User:connect-worker \
  --operation Read \
  --group connect- \
  --resource-pattern-type prefixed

# List all ACLs
kafka-acls --bootstrap-server broker1:9093 --command-config admin.properties --list
```

---

## Inter-Broker and Cluster Linking Auth

### Inter-Broker Authentication (KRaft)

In Confluent Platform 7.8.x KRaft mode, the cluster has two distinct internal communication paths:

**1. Controller-to-controller (CONTROLLER listener):**
Must use `SSL` protocol. SCRAM is not supported. Each controller node requires a unique TLS certificate with both `serverAuth` and `clientAuth` extended key usage.

```properties
# controller.properties (controller-mode nodes)
process.roles=controller
listeners=CONTROLLER://0.0.0.0:9090
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:SSL

# TLS config for controller
ssl.truststore.location=/var/private/ssl/kafka.truststore.jks
ssl.truststore.password=<truststore-pass>
ssl.keystore.location=/var/private/ssl/kafka.controller.keystore.jks
ssl.keystore.password=<keystore-pass>
ssl.key.password=<key-pass>
ssl.client.auth=required
ssl.endpoint.identification.algorithm=https
```

**2. Broker-to-broker (INTERNAL listener):**
Can use `SASL_SSL` with `SCRAM-SHA-512`.

```properties
# server.properties (broker nodes)
process.roles=broker
listeners=INTERNAL://0.0.0.0:9093,CLIENT://0.0.0.0:9092
listener.security.protocol.map=INTERNAL:SASL_SSL,CLIENT:SASL_SSL
security.inter.broker.protocol=SASL_SSL
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-512

listener.name.internal.scram-sha-512.sasl.jaas.config=\
  org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="broker-internal" \
  password="<broker-password>";

# Brokers also need TLS for SASL_SSL
ssl.truststore.location=/var/private/ssl/kafka.truststore.jks
ssl.truststore.password=<truststore-pass>
ssl.keystore.location=/var/private/ssl/kafka.broker.keystore.jks
ssl.keystore.password=<keystore-pass>
ssl.key.password=<key-pass>
ssl.endpoint.identification.algorithm=https
```

### Cluster Linking Authentication (Multi-Region)

Cluster Linking in kafka-lab spans three regions. Each link is configured with its own credentials on the destination cluster. The link principal must be granted appropriate ACLs on the source cluster.

**Step 1 — Create link credentials on source cluster (for the link principal):**

```bash
# On source cluster: create a dedicated link user
kafka-configs --bootstrap-server source-broker:9093 \
  --command-config admin.properties \
  --alter \
  --add-config 'SCRAM-SHA-512=[password=<link-password>]' \
  --entity-type users \
  --entity-name cluster-link-scus-to-mxc

# Grant required ACLs on source cluster for Cluster Linking
kafka-acls --bootstrap-server source-broker:9093 --command-config admin.properties \
  --add --allow-principal User:cluster-link-scus-to-mxc \
  --operation Read --operation Describe --operation DescribeConfigs \
  --topic '*' --resource-pattern-type literal

kafka-acls --bootstrap-server source-broker:9093 --command-config admin.properties \
  --add --allow-principal User:cluster-link-scus-to-mxc \
  --operation Describe --operation DescribeConfigs \
  --cluster
```

**Step 2 — Create the cluster link on destination cluster with mTLS (recommended for links):**

```properties
# link-config.properties (passed to kafka-cluster-links --config-file)
# Using mTLS with PEM inline — no shared filesystem required
security.protocol=SSL
ssl.keystore.type=PEM
ssl.truststore.type=PEM
ssl.endpoint.identification.algorithm=https
ssl.keystore.certificate.chain=-----BEGIN CERTIFICATE-----\n<cert-chain>\n-----END CERTIFICATE-----
ssl.keystore.key=-----BEGIN ENCRYPTED PRIVATE KEY-----\n<private-key>\n-----END ENCRYPTED PRIVATE KEY-----
ssl.key.password=<key-pass>
ssl.truststore.certificates=-----BEGIN CERTIFICATE-----\n<ca-cert>\n-----END CERTIFICATE-----
```

```bash
# Create the link on destination cluster
kafka-cluster-links --bootstrap-server dest-broker:9093 \
  --command-config admin.properties \
  --create \
  --link scus-to-mxc \
  --config-file link-config.properties \
  --cluster-id <source-cluster-id>
```

**Alternatively — SASL/SCRAM on the link (simpler but uses password):**

```properties
# link-config-scram.properties
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="cluster-link-scus-to-mxc" \
  password="<link-password>";
ssl.truststore.location=/var/private/ssl/kafka.truststore.jks
ssl.truststore.password=<truststore-pass>
```

**ACL authorization on source cluster for Cluster Linking:** The link principal requires `Describe`, `Read`, and `DescribeConfigs` on all mirrored topics and the cluster resource. Without these ACLs, the link will fail with authorization errors.

---

## Example Security Configuration

### Broker `server.properties` — Complete Security Section

```properties
# ============================================================
# Security: Listeners and Protocol Map
# ============================================================
listeners=CONTROLLER://0.0.0.0:9090,INTERNAL://0.0.0.0:9093,CLIENT://0.0.0.0:9092
advertised.listeners=INTERNAL://broker1.kafkalab.internal:9093,CLIENT://broker1.kafkalab.internal:9092
listener.security.protocol.map=CONTROLLER:SSL,INTERNAL:SASL_SSL,CLIENT:SASL_SSL
controller.listener.names=CONTROLLER
inter.broker.listener.name=INTERNAL

# ============================================================
# Security: Inter-Broker SASL/SCRAM
# ============================================================
security.inter.broker.protocol=SASL_SSL
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-512

listener.name.internal.scram-sha-512.sasl.jaas.config=\
  org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="broker-internal" \
  password="${file:/etc/kafka/secrets/broker-internal.pwd:password}";

# ============================================================
# Security: TLS (shared by all SSL/SASL_SSL listeners)
# ============================================================
ssl.truststore.location=/var/private/ssl/kafka.truststore.jks
ssl.truststore.password=${file:/etc/kafka/secrets/ssl.pwd:truststore.password}
ssl.keystore.location=/var/private/ssl/kafka.broker1.keystore.jks
ssl.keystore.password=${file:/etc/kafka/secrets/ssl.pwd:keystore.password}
ssl.key.password=${file:/etc/kafka/secrets/ssl.pwd:key.password}
ssl.client.auth=required
ssl.endpoint.identification.algorithm=https
ssl.protocol=TLSv1.3
ssl.enabled.protocols=TLSv1.3,TLSv1.2

# ============================================================
# Security: Controller mTLS (KRaft)
# ============================================================
listener.name.controller.ssl.truststore.location=/var/private/ssl/kafka.truststore.jks
listener.name.controller.ssl.truststore.password=${file:/etc/kafka/secrets/ssl.pwd:truststore.password}
listener.name.controller.ssl.keystore.location=/var/private/ssl/kafka.controller1.keystore.jks
listener.name.controller.ssl.keystore.password=${file:/etc/kafka/secrets/ssl.pwd:keystore.password}
listener.name.controller.ssl.key.password=${file:/etc/kafka/secrets/ssl.pwd:key.password}
listener.name.controller.ssl.client.auth=required

# ============================================================
# Security: Authorization (RBAC + ACLs)
# ============================================================
authorizer.class.name=io.confluent.kafka.security.authorizer.ConfluentServerAuthorizer
confluent.authorizer.access.rule.providers=CONFLUENT,ZK_ACL
super.users=User:admin;User:mds-bootstrap

# ============================================================
# Security: Confluent MDS (RBAC)
# ============================================================
confluent.metadata.server.listeners=https://0.0.0.0:8090
confluent.metadata.server.advertised.listeners=https://broker1.kafkalab.internal:8090
confluent.metadata.server.authentication.method=BEARER
confluent.metadata.server.token.key.path=/var/private/ssl/tokenKeypair.pem
confluent.metadata.server.ssl.truststore.location=/var/private/ssl/kafka.truststore.jks
confluent.metadata.server.ssl.truststore.password=${file:/etc/kafka/secrets/ssl.pwd:truststore.password}
confluent.metadata.server.ssl.keystore.location=/var/private/ssl/kafka.broker1.keystore.jks
confluent.metadata.server.ssl.keystore.password=${file:/etc/kafka/secrets/ssl.pwd:keystore.password}
confluent.metadata.server.ssl.key.password=${file:/etc/kafka/secrets/ssl.pwd:key.password}
```

### Client `security.properties` — Application Service

```properties
# client-security.properties — Application service client config
bootstrap.servers=broker1.kafkalab.internal:9092,broker2.kafkalab.internal:9092

# Authentication: SASL/SCRAM-SHA-512 over TLS
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="payments-service" \
  password="<retrieved-from-azure-keyvault>";

# TLS: Trust the internal CA
ssl.truststore.location=/etc/kafka/ssl/kafka.truststore.jks
ssl.truststore.password=<truststore-pass>
ssl.endpoint.identification.algorithm=https
ssl.protocol=TLSv1.3
```

### Password Externalization

In Confluent Platform 7.8.x, passwords in `server.properties` can be externalized using `${file:/path/to/file:key}` syntax to avoid storing secrets in the properties file. For Ansible-managed deployments, write the secrets file from Ansible Vault and set restrictive permissions (0400).

---

## References

- Confluent Platform Security Overview: <https://docs.confluent.io/platform/current/security/index.html>
- SASL Authentication in Confluent Platform: <https://docs.confluent.io/platform/current/security/authentication/sasl/overview.html>
- Use SASL/SCRAM Authentication in Confluent Platform: <https://docs.confluent.io/platform/current/security/authentication/sasl/scram/overview.html>
- KRaft Security in Confluent Platform: <https://docs.confluent.io/platform/current/security/component/kraft-security.html>
- Use TLS Authentication in Confluent Platform: <https://docs.confluent.io/platform/current/security/authentication/mutual-tls/overview.html>
- Configure mTLS RBAC in Confluent Platform: <https://docs.confluent.io/platform/current/security/authorization/rbac/configure-mtls-rbac.html>
- mTLS with RBAC in Confluent Platform: <https://docs.confluent.io/platform/current/security/authorization/rbac/mtls-rbac.html>
- RBAC Overview in Confluent Platform: <https://docs.confluent.io/platform/current/security/rbac/index.html>
- RBAC Predefined Roles: <https://docs.confluent.io/platform/current/security/rbac/rbac-predefined-roles.html>
- Use Access Control Lists (ACLs) for Authorization: <https://docs.confluent.io/platform/current/security/authorization/acls/overview.html>
- Manage ACLs in Confluent Platform: <https://docs.confluent.io/platform/current/security/authorization/acls/manage-acls.html>
- Enable Security for a KRaft-Based Cluster: <https://docs.confluent.io/platform/current/security/security_tutorial.html>
- Add Security to Running Clusters (Incremental): <https://docs.confluent.io/platform/7.8/security/incremental-security-upgrade.html>
- Manage Security for Cluster Linking on Confluent Platform: <https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/security.html>
- Configure Metadata Service (MDS): <https://docs.confluent.io/platform/current/kafka/configure-mds/index.html>
- KIP-651 PEM Format for SSL Certificates: <https://cwiki.apache.org/confluence/display/KAFKA/KIP-651+-+Support+PEM+format+for+SSL+certificates+and+private+key>
- KIP-684 mTLS on SASL_SSL Listeners: <https://cwiki.apache.org/confluence/display/KAFKA/KIP-684+-+Support+mutual+TLS+authentication+on+SASL_SSL+listeners>
- RFC 5802 SCRAM Specification: <https://tools.ietf.org/html/rfc5802>
- Confluent Platform Security Tools (certificate generation scripts): <https://github.com/confluentinc/confluent-platform-security-tools>
