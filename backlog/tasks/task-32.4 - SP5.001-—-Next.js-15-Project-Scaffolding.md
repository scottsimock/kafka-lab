---
id: TASK-32.4
title: SP5.001 — Next.js 15 Project Scaffolding
status: To Do
assignee: []
created_date: '2026-03-30 16:46'
labels:
  - story
milestone: m-5
dependencies: []
references:
  - webapp/
documentation:
  - doc-16
parent_task_id: TASK-32
priority: high
ordinal: 5001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Initialize a Next.js 15 project at webapp/ with TypeScript and App Router. Configure next.config.ts with output: 'standalone' for Azure Function App deployment. Set up the root layout, dashboard layout shell with sidebar navigation, and loading/error boundaries. Install @confluentinc/kafka-javascript as the Kafka client. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Next.js 15 project initialized at webapp/ with TypeScript
- [ ] #2 App Router structure: app/layout.tsx, app/page.tsx, app/dashboard/layout.tsx
- [ ] #3 package.json includes next, react, react-dom, @confluentinc/kafka-javascript, typescript
- [ ] #4 next.config.ts configured with output: 'standalone'
- [ ] #5 tsconfig.json configured for strict TypeScript
- [ ] #6 npm run build succeeds
- [ ] #7 npm run dev starts development server
<!-- AC:END -->
