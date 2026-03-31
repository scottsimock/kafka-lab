# Task Documentation Standard

## Purpose

This standard formalizes how squad agents document their work in backlog tasks. Proper documentation creates a visible paper trail that shows:
- Which agent completed what work
- When handoffs between agents occurred
- What artifacts were created
- What quality scores and review outcomes were achieved

Humans can scan tasks and see the entire lifecycle — from assignment through review to Done.

## Core Fields

### Acceptance Criteria

**Format:** Markdown checklist `- [ ] #N {criterion text}`

**Status:** 
- `[ ]` — not started or incomplete
- `[x]` — completed

**Rules:**
1. Agents check off criteria as they complete them using `backlog-task_edit` with `acceptanceCriteriaCheck: [N]`
2. Criteria are numbered sequentially starting from 1
3. Never manually rewrite all criteria — use the `acceptanceCriteriaCheck` parameter to toggle status
4. Reviewers may uncheck criteria via `acceptanceCriteriaUncheck: [N]` if work is deficient

**Example:**
```markdown
Acceptance Criteria:
- [x] #1 Module directory exists at terraform/modules/virtual-network/
- [x] #2 versions.tf declares azapi provider >= 2.0
- [ ] #3 terraform validate passes
```

### Implementation Notes

**Format:** Agent-stamped log entries appended chronologically

**Structure:**
```markdown
## [Agent Name] YYYY-MM-DDTHH:MM:SSZ
- Summary of work completed
- Key decisions made
- Artifacts produced (file paths, document IDs, commit messages)
- Quality metrics if applicable (test pass rate, coverage %, score)
```

**Rules:**
1. Use `backlog-task_edit` with `notesAppend: ["## [Agent] timestamp\n- work summary"]`
2. Always include ISO 8601 timestamp (UTC preferred, local time acceptable with timezone offset)
3. Agent names match squad roster: Coder, Tester, TL (Team Lead), Ripley, Smiley, etc.
4. List concrete outputs: file paths, document IDs, commit SHAs, command results
5. Keep summaries concise — 3-8 bullet points per entry

**Example:**
```markdown
Implementation Notes:
--------------------------------------------------
## [TL] 2026-03-30T16:42:00-04:00
- Assigned to coder-1 for Wave 1 execution
- Task: Create VM Terraform module using AzAPI

## [Coder-1] 2026-03-30T16:43:00-04:00
- Created terraform/modules/virtual-machine/ with main.tf, variables.tf, outputs.tf, versions.tf
- NIC with accelerated networking and static IP
- VM with Ubuntu 22.04 LTS Gen2, SSH auth, UAMI, zone placement
- Conditional data disk (Premium_LRS) when data_disk_size_gb > 0
- terraform fmt and validate passed
- Committed: feat(SP2.001)

## [Tester-1] 2025-07-24T12:50:00Z
- Score: 14/14 (100%) — **PASS**
- terraform init -backend=false: PASS
- terraform validate: PASS
- terraform fmt -check: PASS (exit 0)
- All 14 AC items met
```

### Implementation Plan

**Format:** Structured markdown with headings

**Purpose:** Pre-execution planning created by TL or implementor before coding begins

**Typical sections:**
- Files to Create
- Design Decisions
- Integration Points
- Step-by-step instructions

**Rules:**
1. Use `backlog-task_edit` with `planSet` or `planAppend`
2. Optional — not all tasks need implementation plans
3. Typically added by TL during sprint planning or by implementor during task kickoff
4. May include code snippets, configuration examples, or pseudocode

### Final Summary

**Format:** Prose paragraph or structured completion notes

**Purpose:** Post-completion summary for PR descriptions and sprint reports

**Rules:**
1. Use `backlog-task_edit` with `finalSummary` or `finalSummaryAppend`
2. Written by implementor or TL when task reaches Done
3. Should be readable by humans unfamiliar with implementation details
4. Include: what was built, key design choices, deferred items if any

**Example:**
```markdown
Created ansible/roles/kafka-broker/ with full role structure. server.properties.j2 uses sectioned {% if %} guards for PLAINTEXT vs SASL_SSL listeners, TLS settings, tiered storage, and self-balancing — all extensible independently. All defaults for SP3.005/007/008 are pre-loaded. SCRAM bootstrap task uses --zookeeper flag. admin.properties.j2 template for CLI ops. 6g heap with G1GC. Systemd unit with ZK ordering. Handler chain with 6 retries/10s. site.yml updated.
```

## Agent Workflow

### Implementor (Coder, Parker, Dallas, etc.)

1. **On task start:**
   - Append note: `"## [Agent] {timestamp}\n- Starting work on {task title}"`
   - Set status to `In Progress` via `backlog-task_edit`

2. **During implementation:**
   - Check off acceptance criteria as you complete them: `acceptanceCriteriaCheck: [1, 3, 5]`
   - Append notes with file paths, decisions, and artifacts: `notesAppend: ["..."]`

3. **On completion:**
   - Append final note with artifacts and commit message
   - Write `finalSummary` if task is complex or multi-file
   - Set status to `Dev Complete`

### Reviewer (Tester, Sid, Lambert, etc.)

1. **On review start:**
   - Append note: `"## [Agent] {timestamp}\n- Reviewing {task title}"`

2. **During review:**
   - Document findings in notes with structured format:
     ```
     - Score: {rubric score}%
     - {Category}: {score}/{max} — {finding}
     - Required improvements: {numbered list}
     ```
   - Use `acceptanceCriteriaUncheck: [N]` if criteria not met
   - Set status to `In Progress` if retry needed

3. **On approval:**
   - Append final note with PASS verdict and score
   - Check all remaining AC items: `acceptanceCriteriaCheck: [1,2,3,...]`
   - Set status to `Done`

### Lead (Smiley, Ripley, TL)

1. **On assignment:**
   - Append note: `"## [TL] {timestamp}\n- Assigned to {agent} for {work description}"`
   - Set `assignee` field

2. **On handoff:**
   - Append note documenting handoff: `"{Implementor} completed → {Reviewer} reviewing"`

3. **On escalation:**
   - Append note with context: `"Issue: {description}. Action: {resolution}"`

## Handoff Documentation

### Critical Handoff Points

1. **TL → Implementor:** Assignment note with context
2. **Implementor → Reviewer:** Dev Complete note with artifacts
3. **Reviewer → Implementor (retry):** Review note with findings + In Progress status
4. **Reviewer → Done:** PASS note + Done status
5. **Any → Blocked:** Block note with reason + Blocked status

### Handoff Note Template

```markdown
## [Agent] {timestamp}
- **Handoff:** {From Agent} completed {work} → {To Agent} {next action}
- Context: {brief description}
- Artifacts: {file paths or commit SHA}
```

**Example:**
```markdown
## [TL] 2026-03-30T19:23:00Z
- **Handoff:** Coder-2 completed SP1.005 → Tester-2 reviewing
- Artifacts: terraform/modules/virtual-network/, commit abc123
- Critical path: unlocks TASK-28.8 and TASK-28.11
```

## Quality Score Recording

### Review Rubric Results

Reviewers append structured score breakdown:

```markdown
## [Tester] {timestamp}
- Score: {percentage}% — {PASS|FAIL}
- Acceptance Criteria: {count passed}/{count total}
- {Rubric Category}: {score}/{max} — {finding}
- {Rubric Category}: {score}/{max} — {finding}
- ...
- Result: {PASS|FAIL} (threshold: {90|95}%)
```

### Research Quality (95% threshold)

```markdown
- Accuracy: 82/100 — UAMI credential format incorrect
- Completeness: 93/100 — All AC covered, missing KRaft examples
- Sources: 88/100 — URLs use /current/ not /7.8/
- Documentation Quality: 96/100 — Well structured
- Actionability: 93/100 — UAMI issue reduces usability
```

### Coding Quality (90% threshold)

```markdown
- Acceptance Criteria: 30/30 — All 10 AC items met
- Tests: 25/25 — terraform validate passes
- Code Quality: 20/20 — Clean, follows conventions
- Documentation: 15/15 — All vars have descriptions
- Dependencies: 10/10 — No broken references
```

## Task Status Discipline

Agents MUST update task status when crossing lifecycle boundaries:

| Transition | When | Who | Tool call |
|---|---|---|---|
| To Do → In Progress | Agent starts work | Implementor | `status: "In Progress"` |
| In Progress → Dev Complete | Work finished | Implementor | `status: "Dev Complete"` |
| Dev Complete → In Review | Review assigned | Reviewer | `status: "In Review"` |
| In Review → Done | Review passes | Reviewer | `status: "Done"` |
| In Review → In Progress | Review fails, retry needed | Reviewer | `status: "In Progress"` |
| Any → Blocked | Task cannot proceed | Any | `status: "Blocked"` |

## Tools Reference

### Checking Acceptance Criteria

```javascript
backlog-task_edit({
  id: "TASK-29.1",
  acceptanceCriteriaCheck: [1, 3, 5]  // Check items 1, 3, and 5
})
```

### Appending Implementation Notes

```javascript
backlog-task_edit({
  id: "TASK-29.1",
  notesAppend: [
    "## [Coder] 2026-03-30T16:43:00Z\n- Created VM module\n- Committed: feat(SP2.001)"
  ]
})
```

### Setting Status

```javascript
backlog-task_edit({
  id: "TASK-29.1",
  status: "Dev Complete"
})
```

### Combined Edit (typical completion)

```javascript
backlog-task_edit({
  id: "TASK-29.1",
  acceptanceCriteriaCheck: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  notesAppend: [
    "## [Tester] 2026-03-30T19:35:00Z\n- Score: 100% — PASS\n- All AC met"
  ],
  status: "Done"
})
```

## Anti-Patterns

### ❌ Don't Do This

1. **Checking AC without notes:**
   ```javascript
   // Missing documentation of what was done
   backlog-task_edit({ id: "TASK-X", acceptanceCriteriaCheck: [1,2,3] })
   ```

2. **Generic notes without artifacts:**
   ```markdown
   ## [Coder] 2026-03-30T16:43:00Z
   - Finished the module
   ```

3. **Missing timestamps:**
   ```markdown
   ## [Coder]
   - Created files
   ```

4. **Status changes without notes:**
   ```javascript
   // What work was done? Who reviewed it?
   backlog-task_edit({ id: "TASK-X", status: "Done" })
   ```

5. **Unchecked AC with Done status:**
   ```markdown
   Status: Done
   Acceptance Criteria:
   - [ ] #1 Module exists  ← Still unchecked!
   ```

### ✅ Do This Instead

1. **Check AC with notes documenting artifacts:**
   ```javascript
   backlog-task_edit({
     id: "TASK-29.1",
     acceptanceCriteriaCheck: [1, 2, 3],
     notesAppend: [
       "## [Coder] 2026-03-30T16:43:00Z\n- Created terraform/modules/vm/ (4 files)\n- AC1-3: main.tf, variables.tf, outputs.tf all present"
     ]
   })
   ```

2. **Specific notes with file paths and decisions:**
   ```markdown
   ## [Coder] 2026-03-30T16:43:00Z
   - Created terraform/modules/virtual-machine/ with main.tf, variables.tf, outputs.tf, versions.tf
   - NIC with accelerated networking and static IP
   - Conditional data disk via count = var.data_disk_size_gb > 0 ? 1 : 0
   - Committed: feat(SP2.001)
   ```

3. **Always include ISO 8601 timestamp:**
   ```markdown
   ## [Coder] 2026-03-30T16:43:00-04:00
   ```

4. **Status changes with completion notes:**
   ```javascript
   backlog-task_edit({
     id: "TASK-29.1",
     notesAppend: ["## [Tester] 2026-03-30T19:35:00Z\n- Review complete: PASS 100%"],
     status: "Done"
   })
   ```

5. **Done status only when all AC checked:**
   ```javascript
   backlog-task_edit({
     id: "TASK-29.1",
     acceptanceCriteriaCheck: [1,2,3,4,5,6,7,8,9,10],  // All criteria
     status: "Done"
   })
   ```

## Documentation Ceremony

To ensure documentation quality, add a Documentation Check step to the review process.

### When

During code review, before marking task as Done.

### What Reviewers Check

1. **Acceptance Criteria:** All criteria are checked off
2. **Implementation Notes:** At least 2 entries (implementor start + completion, reviewer verdict)
3. **Timestamps:** All notes have ISO 8601 timestamps
4. **Artifacts:** Notes list concrete outputs (files, commits, document IDs)
5. **Status alignment:** Task status matches AC completion (all checked = Done)
6. **Handoff visibility:** Can trace work from assignment → implementation → review → done

### Reviewer Action

If documentation is deficient:
1. Append note documenting the gap: `"## [Tester] {timestamp}\n- Documentation incomplete: {missing item}"`
2. Do NOT set to Done
3. Request implementor to update notes before retry

## Summary

Task documentation creates a durable record of squad work. When followed consistently:

- **Humans can see handoffs** — every task shows who worked on it, when, and what they delivered
- **Quality is visible** — review scores and pass/fail verdicts are recorded
- **Artifacts are traceable** — file paths, commits, and document IDs link tasks to deliverables
- **Status is accurate** — AC checkmarks and status field stay synchronized

All agents use `backlog-task_edit` to append notes, check criteria, and update status as work progresses. This standard ensures the backlog remains the single source of truth for sprint execution.
