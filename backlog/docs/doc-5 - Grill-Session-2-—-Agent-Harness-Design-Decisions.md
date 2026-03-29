---
id: doc-5
title: Grill Session 2 — Agent Harness Design Decisions
type: other
created_date: '2026-03-29 18:25'
---
# Grill Session 2 — Agent Harness Design Decisions

Captured 2026-03-29. These decisions define the agent-based sprint harness for the kafka-lab project.

## Architecture Decisions

### 1. Agent Communication Model
**Decision:** Backlog task status as the message bus.
All agents read/write backlog tasks via the backlog MCP tools. Status transitions (`To Do` → `In Progress` → `Dev Complete` → `In Review` → `Done`) serve as the coordination signal between agents.

### 2. Agent Execution Model
**Decision:** Custom `.agent.md` files for all roles.
- `ruby.agent.md` — main orchestrator (foreground)
- `subagents/product-owner.agent.md` — PO (foreground, invoked by Ruby)
- `subagents/scrum-master.agent.md` — SM (foreground, invoked by Ruby)
- `subagents/tech-lead.agent.md` — TL (foreground, invoked by Ruby)
- `subagents/coder.agent.md` — Coder (background, invoked by TL)
- `subagents/tester.agent.md` — Tester (background, invoked by TL)

All agents inherit full capabilities from general-purpose agents.

### 3. Shared Context
**Decision:** All agents reference shared instructions via their `instructions:` frontmatter field and relevant skills via their frontmatter.
- Coder/Tester: all coding-standards instructions + all technical skills
- PO/SM: markdown + devops-core-principles + backlog skill
- TL: devops-core-principles + backlog skill
- Ruby: markdown + backlog skill

### 4. State Recovery
**Decision:** Ruby derives state entirely from the backlog (stateless). On "continue sprint X", Ruby queries task statuses by milestone to determine the current phase and resume point.

### 5. Agent Handoff Protocol
**Decision:** Status-based transitions only.

| Transition | Status Change | Who |
|---|---|---|
| TL assigns to coder | `To Do` → `In Progress` | TL |
| Coder finishes | `In Progress` → `Dev Complete` | Coder |
| TL assigns to tester | `Dev Complete` → `In Review` | TL |
| Tester passes (≥threshold) | `In Review` → `Done` | Tester |
| Tester fails (<threshold) | `In Review` → `In Progress` | TL |

Each agent appends timestamped notes when changing status.

## Naming Conventions

### 6. Task Naming
- Sprint tasks: `task-SPRINT-SP{N}-{description}` (uppercase SPRINT)
- Story tasks: `task-story-SP{N}.{NNN}-{description}` (zero-padded 3-digit ordinal)
- Research tasks: `task-research-SP{N}.{NNN}-{description}`

### 7. Document Naming
- Research documents: `doc-SP{N}.{NNN}-{description}` (1:1 mapping with research tasks)

### 8. Git Branch Naming
- Sprint branches: `sprint/SP{N}-{description}` (e.g., `sprint/SP0-research-and-planning`)

### 9. Milestones
- One backlog milestone per sprint: `SP0`, `SP1`, etc.
- All tasks within a sprint get the sprint's milestone

### 10. Task Assignment
- Use the `assignee` field on backlog tasks (e.g., `["coder-1"]`, `["tester-2"]`)
- Combined with status to track what's in flight

## Execution Rules

### 11. Parallelism
**Decision:** Maximum 3 concurrent coders. TL manages a pool and assigns next task when a coder finishes.

### 12. File Contention Prevention
**Decision:** TL serializes tasks that share files using dependency analysis. Tasks touching the same files are not assigned to concurrent coders. Task `references` field lists affected files.

### 13. Retry Limit
**Decision:** 3 Coder→Tester cycles max per task. After 3 failures, task is marked `Blocked` with failure history appended to notes.

### 14. Git Commit Strategy
**Decision:** Coder commits after each task completion with message format: `feat(SP{N}.{NNN}): {description}`.

### 15. Sprint Sizing
**Decision:** ~10 tasks per sprint (soft target). ~2 minutes per task, ~25 minutes per sprint. Soft enforcement through PO/SM scoping — not hard runtime limits.

### 16. Mid-Sprint Changes
**Decision:** Not allowed. Human queues changes for next sprint. If truly blocking, human stops sprint, adds task, then continues (Ruby re-derives state).

### 17. Agent Failure Handling
**Decision:** One retry attempt, then mark task as `Blocked` with error details. TL moves on to next task. Ruby reports blocked tasks in PR summary.

## Quality Standards

### 18. Coding Task Rubric (90% pass threshold)

| Category | Weight | Evaluates |
|---|---|---|
| Acceptance Criteria | 30% | All AC items met |
| Tests | 25% | Tests exist, pass, ≥90% coverage |
| Code Quality | 20% | Clean, follows codebase conventions |
| Documentation | 15% | Implementation notes, inline docs |
| Dependencies | 10% | No broken imports, no regressions |

### 19. Research Task Rubric (95% pass threshold)

| Category | Weight | Evaluates |
|---|---|---|
| Accuracy | 30% | Facts correct, sources authoritative |
| Completeness | 25% | All AC items addressed, no gaps |
| Sources | 20% | References cited, URLs valid, primary sources |
| Documentation Quality | 15% | Executive summary, clear structure, examples |
| Actionability | 10% | Usable as implementation guidance |

## Sprint 0 Design

### 20. SP0 Structure
**Decision:** One branch (`sprint/SP0-research-and-planning`), two sequential parts (SP0P1 research, SP0P2 backlog planning). Ruby pauses between parts for human review.

### 21. Research Execution
**Decision:** Coder agent handles research tasks — researching IS the work. No separate researcher agent.

### 22. PO ↔ SM Collaboration
**Decision:** PO creates sprint task + all story/research tasks in one batch. SM reviews in a single pass. Max 3 PO↔SM iterations.

## Lifecycle Decisions

### 23. PR Lifecycle
**Decision:** Ruby owns exclusively. At sprint end: commit uncommitted work, create PR against main with structured body (goal summary, completed tasks with scores, blocked tasks, link to sprint task). Ruby does NOT auto-merge.

### 24. Sprint Completion Criteria
**Decision:** All tasks in milestone are `Done` or `Blocked`. No `In Progress` or `In Review` tasks remain.

### 25. Technical Debt Carryover
**Decision:** PO creates a new carryover task in the next sprint referencing the blocked task. Original stays in its sprint milestone for history.

### 26. Sprint Retrospective
**Decision:** No formal retro. Ruby's PR summary serves as the sprint record.

### 27. Sprint Scope Beyond SP0
**Decision:** Only SP0 is pre-defined. SP1+ are created by PO during SP0P2 based on research findings.

### 28. Agent Communication Style
**Decision:** Purely functional. No personality. Agents identify by role tag (e.g., `[PO]`, `[TL]`, `[Coder-1]`). Direct, professional communication.

## Work Logging

### 29. Format
All agents append structured sections to backlog task implementation notes via `notesAppend`:

```markdown
## [Role] YYYY-MM-DDTHH:MM:SSZ
- Summary of work done
- Key outputs/artifacts
- Relevant metrics (coverage, score, etc.)
```

## Backlog Integration

### 30. Tooling
All agents use backlog MCP tools exclusively (`backlog-task_*`, `backlog-document_*`, `backlog-milestone_*`). No raw file edits to `backlog/` directory. No parallel tracking systems.
