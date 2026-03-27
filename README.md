## Project Overview
- We are creating a lab environment to test the resiliency and failover properties of one or two web applications passing messages in confluent kafka clusters. 
- Confluent kafka is the primary use case for testing resiliency. The web applications will just be a nice user interface to see the end user experience.
- Confluent Kafka will also use confluent connect, cluster linking, schema registry and zookeeper. 
- The project will be deployed into multiple azure regions and multi-availabilty zones.
- The kafka components will run on virtual machines.
- For code deployemnts, will use the terraform azapi provider, ansible and github actions.
- Azure Chaos Studio will be used to test resiliency.
- Custom web application will be created for end user testing. 