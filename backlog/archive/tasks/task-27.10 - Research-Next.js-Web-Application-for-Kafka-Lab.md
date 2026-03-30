---
id: TASK-27.10
title: 'Research: Next.js Web Application for Kafka Lab'
status: To Do
assignee: []
created_date: '2026-03-30 13:38'
labels:
  - research
  - SP0P1
milestone: m-0
dependencies: []
references:
  - 'https://nextjs.org/docs'
  - 'https://nextjs.org/docs/app/building-your-application/routing'
  - 'https://github.com/confluentinc/confluent-kafka-javascript'
  - 'https://github.com/tulios/kafkajs'
documentation:
  - doc-SP0.011-nextjs-web-application
parent_task_id: TASK-27
priority: high
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Next.js web application architecture for the Kafka lab management UI. The web app provides topic, partition, and message management through a browser interface, with real-time message streaming capabilities.

Focus areas:
- Next.js 15 App Router: file-based routing, layouts, server components vs client components
- API Route Handlers for Kafka operations (produce, consume, list topics/partitions)
- Real-time message streaming: SSE vs WebSocket vs polling
- Kafka client library: confluent-kafka-javascript vs kafkajs tradeoffs
- UI component architecture for topic/partition/message management
- Deployment options: containerized on Azure (App Service, Container Apps, or VM-based)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document covers Next.js 15 App Router architecture: file-based routing, layouts, server vs client components
- [ ] #2 Document covers API Route Handlers for Kafka operations: produce messages, consume messages, manage topics
- [ ] #3 Document covers real-time message streaming patterns: SSE, WebSocket, or polling with tradeoffs
- [ ] #4 Document covers Kafka client integration: confluent-kafka-javascript or kafkajs library comparison
- [ ] #5 Document covers UI component strategy for topic/partition/message management views
- [ ] #6 Document covers deployment: containerized Next.js on Azure (App Service, Container Apps, or VM)
- [ ] #7 All findings cite official Next.js and relevant library documentation with URLs
- [ ] #8 Executive summary of 300 words or fewer leads the document
<!-- AC:END -->
