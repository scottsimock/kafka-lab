## Project Overview
- We are creating a lab environment to test the resiliency and failover properties of one or two web applications passing messages in confluent kafka clusters. 
- Confluent kafka is the primary use case for testing resiliency. The web applications will just be a nice user interface to see the end user experience.
- Confluent Kafka will also use confluent connect, cluster linking, schema registry and zookeeper. Kafka should use tiered storage and be self balancing.
- The project will be deployed into multiple azure regions and multi-availabilty zones.
- The kafka components will run on virtual machines.
- Kafka clusters will run in the regions and zones described in the Azure Environment section below.
- For code deployemnts, will use the terraform azapi provider, ansible and github actions.
- Azure Chaos Studio will be used to test resiliency.
- Custom web application will be created for end user testing. The web application will run in the same regions and azs as the kafka clusters. it will be used to create new topics, partitions, write messages and read message from any topic and must be designed so its easy to use. 
- we need one click deployment to push out the entire code base
- start with a single region and single az for in the deveopment envirnment. once the app is running and working against the confluent cluster in dev, then add a second region in development to test multi region. afterward we  can deploy into the production regions.

## Azure Environment

### Regions

| Region | Role | Purpose |
|---|---|---|
| `southcentralus` | Primary | Main production workloads |
| `mexicocentral` | Secondary | Secondary and HA workloads |
| `canadaeast` | DR | Disaster recovery |

### Availability Zones

| Region | Zone | Usage |
|---|---|---|
| `southcentralus` | Zone 1 | Main deployments |
| `southcentralus` | Zone 2 | High availability (HA) replicas |
| `mexicocentral` | Zone 1 | Default zone for secondary and HA workloads |
| `canadaeast` | Zone 1 | Default zone for DR workloads |

### Resource Groups

All resources must be deployed to the following resource group:

| Resource Group | Region |
|---|---|
| `klc-rg-kafkalab-scus` | `southcentralus` |

Do not create new resource groups or deploy resources to any other resource group without explicit instruction.

### Data at Rest

Every Azure resource must be encrypted with a **Customer Managed Key (CMEK)**. Provision one dedicated CMK per resource — do not share keys across resources.

If a service does not support CMEK, apply the following tag to that resource instead:

```hcl
tags = {
  "compliance.data-at-rest" = "No CMEK"
}
```

### Authentication

Every Azure resource must authenticate using a **User Assigned Managed Identity (UAMI)**. Provision one dedicated UAMI per workflow and grant it only the permissions required for that workflow (least privilege).

If a service does not support UAMI, use a **System Assigned Managed Identity** instead.

If a service supports neither, use the next available authentication method and apply the following tag to that resource:

```hcl
tags = {
  "compliance.authentication" = "No Managed Identity"
}
```

Never omit the tag when managed identity is not used. The tag serves as an explicit audit marker that the absence of managed identity is intentional and acknowledged.

### Data in Transit

All data in transit must be encrypted. The minimum accepted TLS version is **TLS 1.2**. Prefer TLS 1.3 where the service supports it.

Always configure the minimum TLS version explicitly on every resource — do not rely on service defaults:

```hcl
min_tls_version = "TLS1_2"
```

If a service does not support enforcing a minimum TLS version, apply the following tag:

```hcl
tags = {
  "compliance.data-in-transit" = "No TLS Enforcement"
}
```

Never omit the tag when TLS enforcement is unavailable. Plaintext or unencrypted transports are not permitted under any circumstance.

### Networking

#### Private Network Topology

All Azure resources must be deployed into private Virtual Networks (VNets). No resource may have a public endpoint or be directly reachable from the internet, with the sole exception of the web application front door (see [Public Ingress](#public-ingress) below).

- Provision one VNet per region where resources are deployed.
- Use VNet peering or Azure Private Link to connect resources across VNets.
- Disable public network access on every resource that supports it:

```hcl
public_network_access_enabled = false
```

If a service does not support disabling public network access, apply the following tag:

```hcl
tags = {
  "compliance.networking" = "No Private Endpoint"
}
```

Never omit the tag when private endpoint enforcement is unavailable.

#### Private Endpoints

Every Azure PaaS or managed service (e.g., Storage, Key Vault, Event Hubs, Service Bus, databases) must be accessed exclusively through **Azure Private Endpoints**. One dedicated private endpoint per service instance is required — do not share private endpoints across services.

#### Private DNS

Private DNS Zones must be provisioned and linked to the VNet for every service that uses a private endpoint. Use the canonical Azure private DNS zone names (e.g., `privatelink.blob.core.windows.net`, `privatelink.vaultcore.azure.net`). Private DNS Zones must not be publicly resolvable.

A records within each private DNS zone must resolve to the private endpoint NIC IP address, not the service's public hostname.

#### Public Ingress

The **web application** is the only resource permitted to accept inbound traffic from the public internet. All public HTTPS traffic must terminate at a managed ingress layer (e.g., Azure Application Gateway or Azure Front Door) before reaching the application backend.

- Expose only port **443 (HTTPS)**; port 80 (HTTP) must redirect to HTTPS.
- Restrict inbound rules on all other resources to deny traffic originating from outside the VNet or approved peered networks.

#### Public TLS Certificates

Public-facing HTTPS endpoints must use TLS certificates issued by **Let's Encrypt** via the ACME protocol. Certificate issuance and renewal must be automated — manual certificate management is not permitted.

- Use the ACME DNS-01 or HTTP-01 challenge as appropriate for the ingress configuration.
- Automate renewal before expiry (Let's Encrypt certificates are valid for 90 days; renew at 60 days or earlier).
- Store issued certificates in Azure Key Vault. Grant the ingress resource read access to the certificate via its UAMI.

Internal service-to-service traffic within the VNet uses TLS enforced at the resource level per the [Data in Transit](#data-in-transit) rules above; separate certificate issuance is not required for private endpoints.

## References

### Confluent Documentation

- [Confluent Platform Overview](https://docs.confluent.io/platform/current/platform.html)
- [Confluent Kafka Documentation](https://docs.confluent.io/kafka/introduction.html)
- [Confluent Cluster Linking](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/overview.html)
- [Confluent Schema Registry](https://docs.confluent.io/platform/current/schema-registry/index.html)
- [Confluent Kafka Connect](https://docs.confluent.io/platform/current/connect/index.html)
- [Confluent Replication and Disaster Recovery](https://docs.confluent.io/platform/current/multi-dc-deployments/replication/index.html)

### Microsoft Documentation

- [Azure Virtual Machines](https://learn.microsoft.com/en-us/azure/virtual-machines/overview)
- [Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview)
- [Azure Regions and Availability Zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
- [Terraform AzAPI Provider](https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider)
- [Azure Managed Identities](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [GitHub Actions on Azure](https://learn.microsoft.com/en-us/azure/developer/github/github-actions)