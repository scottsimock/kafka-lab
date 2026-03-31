---
id: TASK-32.2
title: SP5.010 — Schema Browser View and API Routes
status: In Progress
assignee:
  - Dallas
created_date: '2026-03-30 16:46'
updated_date: '2026-03-31 19:12'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.5
references:
  - webapp/app/api/schemas/
  - webapp/app/dashboard/(views)/schemas/
documentation:
  - doc-6
  - doc-16
parent_task_id: TASK-32
priority: medium
ordinal: 5010
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create Schema Registry API routes and a Schema Browser dashboard view. API routes query Schema Registry REST API (http://schema-registry:8081) for subjects and schema versions. Browser view shows registered subjects, versions, compatibility settings, and schema definitions. Per doc-6 and doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 API route at app/api/schemas/route.ts returns list of registered subjects
- [ ] #2 API route at app/api/schemas/[subject]/route.ts returns schema versions for a subject
- [ ] #3 Schema browser view at app/dashboard/(views)/schemas/page.tsx
- [ ] #4 Displays subject names, latest version, compatibility mode
- [ ] #5 Schema detail shows full schema definition with syntax highlighting
<!-- AC:END -->
