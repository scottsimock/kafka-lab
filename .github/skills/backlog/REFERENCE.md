# Backlog Reference

## File layout

Backlog.md stores all task files flat under `backlog/tasks/`. Subdirectories are not scanned.
Epic membership is expressed through parent-child IDs (`TASK-1` → `TASK-1.1`, `TASK-1.2`, …).

```
backlog/
├── tasks/
│   ├── task-1 - kafka-producer-setup.md          ← epic TASK-1
│   ├── task-1.1 - create-producer-config.md      ← child of TASK-1
│   ├── task-1.2 - add-retry-logic.md             ← child of TASK-1
│   ├── task-2 - consumer-group-config.md         ← epic TASK-2
│   └── task-2.1 - register-consumer-group.md     ← child of TASK-2
└── docs/
    ├── docs.001-architecture-overview.md
    └── docs.002-kafka-topic-naming.md
```

> **Never place task files in subdirectories.** Backlog.md only reads `backlog/tasks/*.md` and will lose visibility of any file moved into a subfolder.

## Edge cases

### Empty backlog

Backlog.md starts numbering at `TASK-1`. When no tasks exist in an epic, the first child is `TASK-N.1`.
When no docs exist, start at `docs.001`.

### Numbering gaps

Always use the highest existing number + 1. Do not fill gaps left by deleted or archived items.

### Existing epic re-use

When a task clearly belongs to an existing epic (same domain, same feature area), add it there
rather than creating a new epic. Use `backlog-task_list` to review scope before deciding.

### Multiple tasks in one request

Create all tasks under the same epic when they belong together.
Determine the epic once, then create each task with the same `parentTaskId`.

## Epic file template

```md
# Epic: <Title>

## Overview

<High-level description of what this epic covers and why it matters.>

## Goals

- <Goal 1>
- <Goal 2>

## Conditions of Completion

- [ ] <Measurable outcome 1>
- [ ] <Measurable outcome 2>
```

## MCP tool quick reference

| Action | Tool |
|---|---|
| List epics / tasks | `backlog-task_list` |
| Create epic or task | `backlog-task_create` |
| View a task | `backlog-task_view` |
| Edit a task | `backlog-task_edit` |
| List docs | `backlog-document_list` |
| Create a doc | `backlog-document_create` |
| View a doc | `backlog-document_view` |
| Update a doc | `backlog-document_update` |
