---
description: 'Sprint workflow, agent roles, naming conventions, and execution rules for the kafka-lab project'
applyTo: '**'
---

# Sprint Workflow

This instruction defines the agent-based sprint harness for the kafka-lab project. All agents reference this file for workflow rules, naming conventions, and execution protocols.

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                          HUMAN (Terminal)                               │
│                                                                         │
│   "start sprint SP1"          "continue sprint SP1"          Review PR  │
└──────────┬──────────────────────────┬───────────────────────────────────┘
           │                          │
           ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        RUBY  (Foreground)                               │
│                     Sprint Orchestrator                                  │
│                                                                         │
│   • Creates branch: sprint/SP{N}-{description}                          │
│   • Derives state from backlog (stateless)                              │
│   • Invokes PO → SM → TL in sequence                                   │
│   • Creates PR against main at sprint end                               │
│   • STOPS after every sprint — waits for human                          │
└────┬────────────────┬────────────────┬──────────────────────────────────┘
     │                │                │
     ▼                ▼                ▼
┌──────────┐  ┌──────────────┐  ┌─────────────────────────────────────┐
│ PO       │  │ SM           │  │ TL  (Foreground)                    │
│(Fgnd)    │  │(Fgnd)        │  │ Tech Lead                           │
│          │  │              │  │                                     │
│ Creates  │  │ Reviews all  │  │  • Builds execution order           │
│ sprint   │◄─┤ tasks in one │  │  • Manages coder/tester pools (x3)  │
│ + story  │─►│ pass. Up to  │  │  • Handles retry loop (max 3)       │
│ + research│  │ 3 PO↔SM     │  │  • Serializes file-contending tasks │
│ tasks    │  │ iterations   │  │  • Returns when all Done/Blocked    │
└──────────┘  └──────────────┘  └──────┬──────────────┬───────────────┘
                                       │              │
                          ┌────────────┘              └────────────┐
                          │  (up to 3 concurrent)                  │
                          ▼                                        ▼
               ┌─────────────────────┐              ┌─────────────────────┐
               │ CODER  (Background) │              │ TESTER (Background)  │
               │                     │              │                      │
               │ • Reads task AC     │              │ • Reviews coder work │
               │ • Writes code/docs  │              │ • Runs tests         │
               │ • Writes tests      │              │ • Scores via rubric  │
               │ • Commits changes   │              │ • Pass ≥ threshold   │
               │ • Logs work to task │              │ • Fail → feedback    │
               └─────────┬───────────┘              └──────────┬──────────┘
                         │                                     │
                         └──────────┐          ┌───────────────┘
                                    ▼          ▼
                          ┌──────────────────────────┐
                          │   BACKLOG (Message Bus)   │
                          │                           │
                          │  Tasks ←→ Status changes  │
                          │  Milestones, Documents    │
                          │  Notes (timestamped logs)  │
                          │                           │
                          │  All agents read/write    │
                          │  via backlog MCP tools    │
                          └──────────────────────────┘
```

## Sprint Lifecycle

### Phase 1 — Planning

```text
Ruby ──► PO creates tasks ──► SM reviews ──┐
              ▲                             │
              └──── fix issues ◄────────────┘
                    (max 3 iterations)
```

1. Ruby creates the git branch and milestone.
2. PO creates the sprint task (`task-SPRINT-SP{N}-{description}`) and all story/research tasks in one batch.
3. SM reviews all tasks in a single pass against the quality checklist.
4. If SM finds issues, PO fixes them. Up to 3 PO↔SM iterations.

### Phase 2 — Execution

```text
TL ──► assign task ──► Coder (background) ──► Dev Complete
                                                    │
TL ◄── read score ◄── Tester (background) ◄────────┘
 │
 ├── score ≥ threshold ──► Done
 └── score < threshold ──► add guidance ──► reassign to Coder
                           (max 3 cycles, then Blocked)
```

1. TL builds an execution order from task dependencies and file references.
2. TL assigns tasks to up to 3 concurrent coders.
3. When a coder finishes (`Dev Complete`), TL assigns the task to a tester.
4. If the tester passes (≥ threshold), the task is `Done`.
5. If the tester fails, TL adds guidance and reassigns to a coder. Max 3 cycles.
6. After 3 failures, the task is `Blocked`.

### Phase 3 — Closure

1. TL returns to Ruby when all tasks are `Done` or `Blocked`.
2. Ruby commits any remaining changes and creates a PR against `main`.
3. Ruby STOPS and waits for the human to review and merge.

## Task Status Machine

```text
┌─────────┐   TL assigns    ┌─────────────┐   Coder finishes   ┌──────────────┐
│ To Do   │ ───────────────► │ In Progress │ ─────────────────► │ Dev Complete │
└─────────┘                  └─────────────┘                    └──────┬───────┘
                                   ▲                                   │
                                   │                          TL assigns tester
                            TL reassigns                               │
                            (score < threshold)                        ▼
                                   │                           ┌─────────────┐
                                   └─────────────────────────  │ In Review   │
                                                               └──────┬──────┘
                                                                      │
                                                        ┌─────────────┼──────────────┐
                                                        │             │              │
                                                        ▼             ▼              ▼
                                                   ┌────────┐   ┌─────────┐   ┌──────────┐
                                                   │ Done   │   │In Prog. │   │ Blocked  │
                                                   │(pass)  │   │(retry)  │   │(3 fails) │
                                                   └────────┘   └─────────┘   └──────────┘
```

## Naming Conventions

### Task IDs

| Type | Pattern | Example |
|---|---|---|
| Sprint | `task-SPRINT-SP{N}-{description}` | `task-SPRINT-SP0-research-and-planning` |
| Story | `task-story-SP{N}.{NNN}-{description}` | `task-story-SP1.003-create-vnet` |
| Research | `task-research-SP{N}.{NNN}-{description}` | `task-research-SP0.005-confluent-cluster-linking` |

- `{N}` is the sprint number (0, 1, 2, ...).
- `{NNN}` is a zero-padded 3-digit ordinal within the sprint (001, 002, ...).
- `{description}` uses kebab-case.

### Documents

| Type | Pattern | Example |
|---|---|---|
| Research doc | `doc-SP{N}.{NNN}-{description}` | `doc-SP0.005-confluent-cluster-linking` |

Research documents have a 1:1 mapping with their research tasks.

### Git Branches

| Pattern | Example |
|---|---|
| `sprint/SP{N}-{description}` | `sprint/SP0-research-and-planning` |

### Milestones

One milestone per sprint: `SP0`, `SP1`, `SP2`, etc. All tasks within a sprint carry the sprint milestone.

### Commit Messages

Format: `feat(SP{N}.{NNN}): {description}`

Example: `feat(SP1.003): create vnet module`

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

## Execution Rules

| Rule | Value |
|---|---|
| Max concurrent coders | 3 |
| Max concurrent testers | 3 |
| Max coder→tester retry cycles | 3 (then Blocked) |
| Max PO↔SM review iterations | 3 |
| Target tasks per sprint | ~10 |
| Target time per task | ~2 minutes (soft) |
| Target time per sprint | ~25 minutes (soft) |
| Agent failure retries | 1 (then Blocked) |
| Mid-sprint task additions | Not allowed |

## Sprint 0 — Special Structure

Sprint 0 has two sequential parts on a single branch:

```text
Human: "start sprint SP0"
  │
  ▼
Ruby ──► SP0P1 (Research)
  │       PO creates research tasks
  │       SM reviews
  │       TL assigns coders to produce backlog/docs
  │       Research threshold: 95%
  │
  ▼
Ruby STOPS ──► Human reviews research output
  │
Human: "continue sprint SP0"
  │
  ▼
Ruby ──► SP0P2 (Backlog Planning)
  │       PO reviews research docs + REQUIREMENTS.md
  │       PO creates SP1, SP2, ... sprint tasks and story tasks
  │       SM reviews all planned tasks
  │       No TL/coders — planning only
  │
  ▼
Ruby creates PR ──► STOPS ──► Human reviews and merges
```

### SP0 State Detection

| Backlog State | Phase | Action |
|---|---|---|
| No tasks in SP0 milestone | SP0P1 not started | Begin SP0P1 |
| Research tasks exist, not all Done/Blocked | SP0P1 in progress | Resume TL |
| All research tasks Done/Blocked, no SP1+ tasks | SP0P1 complete | Begin SP0P2 |
| SP1+ sprint/story tasks exist | SP0P2 in progress | Resume PO/SM |

## Agent Execution Modes

Agents run in specific execution modes matching the architecture diagram. These are strict requirements, not suggestions.

| Agent | Mode | Rationale |
|---|---|---|
| Ruby | `sync` (foreground) | Orchestrator — human must observe progress |
| PO | `sync` (foreground) | Invoked by Ruby sequentially |
| SM | `sync` (foreground) | Invoked by Ruby sequentially |
| TL | `sync` (foreground) | Invoked by Ruby sequentially |
| Coder | `background` | TL manages pool of up to 3 concurrent coders |
| Tester | `background` | TL manages pool of up to 3 concurrent testers |

- **Never** run Ruby, PO, SM, or TL as background agents. The human must see their output in real time.
- Coders and Testers run in the background so TL can manage concurrency and collect results.

## Agent Communication

- All agents use backlog MCP tools exclusively for task state management.
- No raw file edits to the `backlog/` directory.
- Agents prefix output with their role tag: `[Ruby]`, `[PO]`, `[SM]`, `[TL]`, `[Coder]`, `[Tester]`.
- Communication style is purely functional — no personality, direct and professional.

## Work Logging

All agents append timestamped entries to task notes via `notesAppend`:

```markdown
## [Role] YYYY-MM-DDTHH:MM:SSZ
- Summary of work done
- Key outputs/artifacts
- Relevant metrics (coverage, score, etc.)
```

## Task Assignment Tracking

The `assignee` field on backlog tasks tracks who is working on what:

- TL sets `assignee: ["coder-1"]` when assigning to a coder.
- TL sets `assignee: ["tester-1"]` when assigning to a tester.
- Combined with status, the TL can query the backlog to see all in-flight work.

## Technical Debt and Carryover

- Blocked tasks stay in their original sprint milestone for history.
- The PO creates a new carryover task in the next sprint referencing the blocked task.
- Carryover tasks incorporate failure notes and refine acceptance criteria.

## PR Lifecycle

Ruby owns the full PR lifecycle:

1. Commits any uncommitted work on the sprint branch.
2. Creates a PR against `main` with a structured body containing:
   - Sprint goal summary
   - Completed tasks with scores
   - Blocked tasks with reasons
   - Sprint metrics (completion rate, average score)
   - Link to the sprint task in the backlog
3. Does NOT auto-merge. The human reviews and merges.
