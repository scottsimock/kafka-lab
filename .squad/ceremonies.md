# Ceremonies

> Team meetings that happen before or after work. Each squad configures their own.

## Design Review

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | before |
| **Condition** | multi-agent task involving 2+ agents modifying shared systems |
| **Facilitator** | lead |
| **Participants** | all-relevant |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. Review the task and requirements
2. Agree on interfaces and contracts between components
3. Identify risks and edge cases
4. Assign action items

---

## Retrospective

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | after |
| **Condition** | build failure, test failure, or reviewer rejection |
| **Facilitator** | lead |
| **Participants** | all-involved |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. What happened? (facts only)
2. Root cause analysis
3. What should change?
4. Action items for next iteration

---

## Sprint Closeout

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | after |
| **Condition** | all tasks in a sprint reach Done status |
| **Facilitator** | lead |
| **Participants** | lead-only |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. Verify all sprint tasks are Done and acceptance criteria met
2. Stage and commit all sprint work on the sprint branch (`sprint/SP{N}-{description}`)
3. Push the branch to origin
4. Create a pull request via `gh pr create` targeting `main` with title `SP{N} — {Sprint Goal}`
5. Include sprint summary (task count, highlights, key decisions) in the PR body

**Runs before:** Sprint Report (closeout packages the code; report documents the sprint)

---

## Sprint Report

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | after |
| **Condition** | all tasks in a sprint reach Done status |
| **Facilitator** | lead |
| **Participants** | lead-only |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Output:** `.squad/reports/SP{N}-report.md` (individual) + `.squad/reports/sprint-summary.md` (consolidated)

**Agenda:**
1. Gather task data from backlog (counts, quality scores, priorities)
2. Write individual sprint report with summary, deliverables, tasks table, decisions, and team contributions
3. Update consolidated sprint summary with new row and cumulative stats
4. Record report in decisions inbox
