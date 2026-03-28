---
name: backlog
description: Manage backlog epics, tasks, and docs using the Backlog.md MCP in a consistent manner. Use when creating or updating backlog items, when input type is one of [epic, task, doc], or when user mentions epics, tasks, stories, or project documentation.
---

# Backlog

Interact with the project backlog using the Backlog.md MCP tools.
Identify the input type — `epic`, `task`, or `doc` — then follow the corresponding workflow.

## ID and file conventions

The Backlog.md MCP auto-generates IDs in the format `TASK-N` (epics) and `TASK-N.M` (child tasks).
All task files live flat in `backlog/tasks/` — the tool does not scan subdirectories.
Epic membership is expressed through parent-child IDs, not folder hierarchy.

| Item | File |
|---|---|
| Epic `TASK-1` | `backlog/tasks/task-1 - <slug>.md` |
| Task `TASK-1.3` | `backlog/tasks/task-1.3 - <slug>.md` |

> **Constraint:** Never move task files out of `backlog/tasks/` root. Backlog.md will lose visibility of any file placed in a subfolder.

## Epics

**Before creating a new epic**, check whether the work fits an existing one:

```
backlog-task_list  →  review titles and labels for epics
```

If a match exists, use that epic. If not, create a new one:

1. Create the epic using `backlog-task_create`:
   - `title`: short descriptive title
   - `labels`: include `epic`
2. Note the auto-generated ID (e.g., `TASK-5`).

**Epic file structure:**

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

## Tasks

Tasks are grouped with their epic through the parent-child ID system.

1. Identify the parent epic and its ID (e.g., `TASK-5`).
2. Create the task using `backlog-task_create`:
   - `parentTaskId`: parent epic's ID (e.g., `TASK-5`)
   - Populate `title`, `description`, `acceptanceCriteria`, `priority`, and `status` as appropriate.
3. The task file lands at `backlog/tasks/task-5.N - <slug>.md` where `N` is the auto-assigned child number.

## Docs

Docs are written to `backlog/docs/`.

1. Find the next number: use `backlog-document_list` and find the highest `docs.###` ID, then increment.
2. Create the doc using `backlog-document_create`:
   - title determines the slug
3. The doc file lands at: `backlog/docs/docs.###-<slug>.md`

**File name format:** `docs.###-<slug>.md`

## Numbering

All sequence numbers are zero-padded to 3 digits: `001`, `002`, `003`, ...

Prefer MCP list tools to determine the next number. If the list is empty, start at `001`.

## Slug rules

Slugs are lowercase, hyphen-separated, and capped at 5 words.
Examples: `kafka-producer-setup`, `consumer-group-config`, `auth-flow`.

See [REFERENCE.md](REFERENCE.md) for file layout examples and edge cases.
