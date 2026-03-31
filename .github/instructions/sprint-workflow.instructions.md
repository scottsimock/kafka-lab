---
description: 'Sprint conventions: naming, branching, quality rubrics, and task lifecycle'
applyTo: '**'
---

# Sprint Conventions

This instruction defines naming conventions, branching patterns, quality rubrics, and task lifecycle states for the kafka-lab project. Sprint orchestration is handled by Squad (see `.github/agents/squad.agent.md` and `.squad/` for orchestration rules).

## Task Status Machine

Tasks flow through these states in the backlog. Orchestration logic (Squad or otherwise) moves tasks between states based on work completion and quality checks.

```text
┌─────────┐   Agent assigns   ┌─────────────┐   Work finishes   ┌──────────────┐
│ To Do   │ ─────────────────► │ In Progress │ ────────────────► │ Dev Complete │
└─────────┘                    └─────────────┘                   └──────┬───────┘
                                     ▲                                  │
                                     │                         Review assigned
                              Reassignment                              │
                              (retry needed)                            ▼
                                     │                          ┌─────────────┐
                                     └────────────────────────  │ In Review   │
                                                                └──────┬──────┘
                                                                       │
                                                        ┌──────────────┼──────────────┐
                                                        │              │              │
                                                        ▼              ▼              ▼
                                                   ┌────────┐   ┌─────────┐   ┌──────────┐
                                                   │ Done   │   │In Prog. │   │ Blocked  │
                                                   │(pass)  │   │(retry)  │   │(failed)  │
                                                   └────────┘   └─────────┘   └──────────┘
```

## Naming Conventions

### Backlog IDs (auto-generated)

The Backlog.md MCP tool auto-generates IDs. You cannot set custom IDs.

| Item | Auto-generated ID | Example |
|---|---|---|
| Sprint (parent) | `TASK-{N}` | `TASK-5` |
| Child task | `TASK-{N}.{M}` | `TASK-5.3` |

Sprint membership is expressed through the parent-child ID relationship, not through the ID string itself.

### Task Titles

Titles encode sprint number and ordinal for human readability and cross-referencing:

| Type | Title format | Example |
|---|---|---|
| Sprint | `SP{N} — {Goal}` | `SP1 — Core Networking and Compute` |
| Story | `SP{N}.{NNN} — {Description}` | `SP1.003 — Create VNet Module` |
| Research | `SP{N}.{NNN} — {Description}` | `SP0.005 — Confluent Cluster Linking` |

### Labels

Labels distinguish task types:

| Type | Label |
|---|---|
| Sprint | `sprint` |
| Story | `story` |
| Research | `research` |

### Parent-Child Structure

Every story and research task MUST be created as a child of its sprint task by passing `parentTaskId` to `backlog-task_create`. This is the primary structural mechanism — without it, the task is orphaned.

### Documents

| Type | Pattern | Example |
|---|---|---|
| Research doc | Created via `backlog-document_create` | `docs.005-confluent-cluster-linking` |

### Git Branches

| Pattern | Example |
|---|---|
| `sprint/SP{N}-{description}` | `sprint/SP0-research-and-planning` |

### Milestones

One milestone per sprint: `SP0`, `SP1`, `SP2`, etc. All tasks within a sprint carry the sprint milestone.

### Commit Messages

Format: `feat(SP{N}.{NNN}): {description}`

Example: `feat(SP1.003): create vnet module`

The `SP{N}.{NNN}` in the commit message matches the ordinal in the task title.

## Quality Rubrics

### Coding Tasks (90% pass threshold)

| Category | Weight | Evaluates |
|---|---|---|
| Acceptance Criteria | 30% | All AC items met |
| Tests | 25% | Tests exist, pass, ≥90% coverage |
| Code Quality | 20% | Clean, follows codebase conventions |
| Documentation | 15% | Implementation notes, inline docs |
| Dependencies | 10% | No broken imports, no regressions |

### Research Tasks (95% pass threshold)

| Category | Weight | Evaluates |
|---|---|---|
| Accuracy | 30% | Facts correct, sources authoritative |
| Completeness | 25% | All AC items addressed, no gaps |
| Sources | 20% | References cited, URLs valid, primary sources |
| Documentation Quality | 15% | Executive summary, clear structure, examples |
| Actionability | 10% | Usable as implementation guidance |

## Work Logging

Agents append timestamped entries to task notes via `notesAppend`:

```markdown
## [Agent Name] YYYY-MM-DDTHH:MM:SSZ
- Summary of work done
- Key outputs/artifacts
- Relevant metrics (coverage, score, etc.)
```

## Task Assignment Tracking

The `assignee` field on backlog tasks tracks who is working on what. Squad agents set the assignee field when taking ownership of a task. Combined with status, this allows any agent to query the backlog to see all in-flight work.

## Technical Debt and Carryover

- Blocked tasks stay in their original sprint milestone for history.
- When a task is blocked, a new carryover task is created in the next sprint referencing the blocked task.
- Carryover tasks incorporate failure notes and refine acceptance criteria.
