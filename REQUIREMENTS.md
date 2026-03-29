## Project Overview
- We are creating a lab environment to test the resiliency and failover properties of one or two web applications passing messages in confluent kafka clusters. 
- Confluent kafka is the primary use case for testing resiliency. The web applications will just be a nice user interface to see the end user experience.
- Confluent Kafka will also use confluent connect, cluster linking, schema registry and zookeeper. Kafka should use tiered storage and be self balancing.
- The project will be deployed into multiple azure regions and multi-availabilty zones.
- The kafka components will run on virtual machines.
- Kafka clusters will run in the regions and zones described in the azure-environment instructions file.
- For code deployemnts, will use the terraform azapi provider, ansible and github actions.
- Azure Chaos Studio will be used to test resiliency.
- Custom web application will be created for end user testing. The web application will run in the same regions and azs as the kafka clusters. it will be used to create new topics, partitions, write messages and read message from any topic and must be designed so its easy to use. 
- we need one click deployment to push out the entire code base
- start with a single region and single az for in the deveopment envirnment. once the app is running and working against the confluent cluster in dev, then add a second region in development to test multi region. afterward we  can deploy into the production regions.

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