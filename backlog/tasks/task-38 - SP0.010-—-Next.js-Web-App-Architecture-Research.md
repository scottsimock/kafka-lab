---
id: TASK-38
title: SP0.010 — Next.js Web App Architecture Research
status: To Do
assignee: []
created_date: '2026-03-30 13:42'
updated_date: '2026-03-30 13:48'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://nextjs.org/docs'
  - 'https://nextjs.org/docs/app/building-your-application/routing'
  - 'https://learn.microsoft.com/en-us/azure/azure-functions/functions-overview'
  - 'https://github.com/confluentinc/confluent-kafka-javascript'
priority: medium
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Next.js 15 App Router architecture for the Kafka management web application. Cover API route design for Kafka operations, confluent-kafka-javascript client integration, Azure Function App hosting with VNet integration, and the 4-view dashboard design.\n\nKey areas:\n- Next.js 15 App Router: server components, client components, API route handlers\n- confluent-kafka-javascript: client library for Kafka admin, producer, consumer operations\n- API route design: REST endpoints for topic CRUD, message produce/consume, cluster health\n- Azure Function App hosting: Node.js runtime, custom handler vs built-in, cold start mitigation\n- VNet integration: Function App VNet injection to reach private Kafka brokers\n- Dashboard views: Cluster Overview, Topic Manager, Message Explorer, Health Monitor\n- Real-time updates: SSE or WebSocket for live metrics and message streaming\n- Authentication: Azure AD integration for web app access\n- Build and deployment: standalone output for Function App deployment\n\nExpected output: backlog document doc-SP0.010-nextjs-web-app-architecture
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Next.js 15 App Router patterns documented for server/client components
- [ ] #2 confluent-kafka-javascript client library API documented for admin, producer, consumer
- [ ] #3 API route design documented for topic CRUD, message operations, cluster health
- [ ] #4 Azure Function App hosting configuration documented for Next.js
- [ ] #5 VNet integration approach for Function App to reach Kafka documented
- [ ] #6 4-view dashboard component hierarchy documented (Cluster Overview, Topic Manager, Message Explorer, Health Monitor)
- [ ] #7 Real-time update mechanism recommended (SSE vs WebSocket) with rationale
- [ ] #8 Build output configuration for Azure Function App deployment documented
- [ ] #9 All findings reference official Next.js, Confluent, and Azure documentation
<!-- AC:END -->
