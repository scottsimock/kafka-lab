<!-- BACKLOG.MD MCP GUIDELINES START -->

<CRITICAL_INSTRUCTION>

## BACKLOG WORKFLOW INSTRUCTIONS

This project uses Backlog.md MCP for all task and project management activities.

**CRITICAL GUIDANCE**

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_workflow_overview()` tool to load the tool-oriented overview (it lists the matching guide tools).

- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow
- **Already familiar?** You should have the overview cached ("## Backlog.md Overview (MCP)")
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work

These guides cover:
- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and finalization
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

</CRITICAL_INSTRUCTION>

<!-- BACKLOG.MD MCP GUIDELINES END -->

---

# Dual-Agent Development System

This project uses a **two-agent architecture** to separate planning from implementation. All work flows through the Backlog.md MCP — it is the single source of truth and the only communication channel between agents.

## Architecture Overview

```
  User
    │
    ▼
┌──────────────────────┐
│  /orchestrator        │  ◄── Skill: .claude/skills/orchestrator/
│  (Technical Lead)     │
│                       │
│  - Gathers requirements
│  - Creates backlog tasks
│  - Delegates to /dev  │
│  - Reviews results    │
│  - NEVER writes code  │
└──────────┬───────────┘
           │  invokes via Skill tool
           ▼
┌──────────────────────┐
│  /dev <task-id>       │  ◄── Skill: .claude/skills/dev/
│  (Developer Subagent) │
│                       │
│  - Reads task from backlog
│  - Implements code    │
│  - Writes unit tests  │
│  - Updates task notes │
│  - Runs in forked ctx │
└──────────────────────┘
```

## Agent 1: Orchestrator (`/orchestrator`)

**Role:** Technical Lead — plans and coordinates, never codes.

**Location:** `.claude/skills/orchestrator/SKILL.md`

**Invocation:** User types `/orchestrator <objective or request>`

**Responsibilities:**
- Gather requirements from the user via clarifying questions
- Decompose work into epics (parent tasks) and tasks (child tasks) in the backlog
- Enforce the dot-notation task ID naming convention: `task.{epic#}.{task#}` (e.g., `task.1.1`, `task.1.2`)
- Ensure every task has clear acceptance criteria including mandatory unit tests
- Delegate implementation by invoking `/dev <task-id>` for each ready task
- Review subagent output against acceptance criteria
- Mark tasks complete or return them with feedback

**Restrictions:**
- MUST NOT use Edit, Write, Bash, or NotebookEdit to modify project files
- MUST NOT generate code — only describe requirements in the backlog
- MUST get user approval before creating tasks

## Agent 2: Developer Subagent (`/dev`)

**Role:** Implementer — writes code and tests based on backlog tasks.

**Location:** `.claude/skills/dev/SKILL.md`

**Invocation:** Orchestrator invokes via Skill tool (not user-invocable)

**Execution:** Runs in a **forked context** (`context: fork`) — isolated from the main conversation. The backlog is the only way it receives requirements.

**Responsibilities:**
- Read the assigned task from the backlog using the provided task ID
- Explore the codebase to understand conventions and patterns
- Implement the code described in the task
- Write unit tests (mandatory for every task that produces code)
- Run tests and linting to validate the work
- Update the task with implementation notes and check off acceptance criteria

**Restrictions:**
- MUST NOT mark tasks as complete — only the orchestrator does that
- MUST NOT ask the user for clarification — documents blockers in the task instead
- MUST NOT modify files outside the task's scope

## Task ID Convention

All tasks follow dot-notation naming in their titles:

| Level | Format | Example |
|-------|--------|---------|
| Epic (parent) | `task.{epic#}: {name}` | `task.1: Kafka Producer Service` |
| Task (child) | `task.{epic#}.{task#}: {name}` | `task.1.1: Create producer config` |

- Epics are created as parent tasks with the `epic` label
- Tasks are linked to epics via `parentTaskId`
- Dependencies between tasks are tracked via the `dependencies` field

## Workflow Summary

1. **User** invokes `/orchestrator` with an objective
2. **Orchestrator** asks clarifying questions, confirms understanding
3. **Orchestrator** creates milestone, epics, and tasks in the backlog
4. **User** approves the task breakdown
5. **Orchestrator** sets task to `In Progress` and invokes `/dev <task-id>`
6. **Developer** reads the task, implements, writes tests, updates notes
7. **Orchestrator** reviews output, marks task `Done` or returns with feedback
8. Repeat steps 5-7 until all tasks are complete
9. **Orchestrator** reports final summary to the user

## Key Rules

- **Backlog is the only communication channel** between orchestrator and developer
- **Unit tests are mandatory** — every task that produces code must include tests
- **No code in task descriptions** — describe *what*, not *how*
- **Orchestrator never codes; developer never plans** — separation of concerns is absolute
