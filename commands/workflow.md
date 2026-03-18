---
description: Dual AI collaborative workflow - Execute tasks with automatic Cursor Agent peer review
argument-hint: <task-description> <claude|cursor>
---

# Dual AI Workflow

You are the **Workflow Orchestrator** managing collaboration between two AI agents with user checkpoints.

## Modes

### Normal Mode (default): `/workflow <task> <executor>`
User participates at key decision points:
1. User + Executor discuss and draft proposal together
2. Executor ↔ Reviewer auto-iterate on proposal (no user)
3. **User confirms proposal**
4. Executor ↔ Reviewer auto-implement code (no user)
5. **User confirms implementation**
6. Commit

## Phase 1: Plan Stage

### Step 1: User + Executor Co-design

When the user invokes `/workflow <task-description> <executor:claude|cursor>`:

1. **Initialize Task**
   ```bash
   workflow init  # if not exists
   workflow create "<task-name>" <executor>
   ```

2. **Engage User in Discussion**
   - Ask clarifying questions about requirements
   - Discuss approach options with user
   - Understand constraints and priorities
   - **Output**: Draft outline of proposal

### Step 2: Executor Writes Formal Proposal

3. **Write Complete Proposal**
   - Create `.workflow/plans/<task-id>/proposal.md`
   - Include: executive summary, architecture design, implementation approach, risks and mitigations, alternatives considered

### Step 3: Auto-Review Loop (No User)

4. **Executor ↔ Reviewer Iteration**
   ```
   while not approved and rounds < 5:
     reviewer: call `workflow review-proposal <task-id>`
     if APPROVE: break
     else: executor address concerns, update proposal
   ```

### Step 4: User Confirmation

5. **Present to User** with summary, wait for approval
6. If user says no: go back to Step 1. If yes: proceed to Phase 2.

## Phase 2: Implementation Stage

### Step 5: Auto-Implementation (No User)

7. **Executor ↔ Reviewer Auto-Code**
   ```
   executor: implement code per proposal
   while not approved and rounds < 5:
     reviewer: call `workflow review-code <task-id>`
     if APPROVE: break
     else: executor fix issues
   ```

### Step 6: User Final Confirmation

8. **Present Implementation** with changes summary, test status, diff
9. **Commit if Approved**

## Key Instructions

### When YOU are Executor (Claude)

1. **Engage user first** - Ask questions, discuss approaches
2. **Co-create draft** with user input
3. **Write formal proposal** incorporating user's preferences
4. **Auto-iterate with reviewer** until both approve
5. **Present to user** with summary, wait for approval
6. **Implement code** after user confirms
7. **Auto-iterate on code** with reviewer
8. **Present to user** for final approval

### When YOU are Reviewer (for Cursor's work)
- **Use the `workflow` CLI** or call agent directly
- **Parse the response** and extract concerns/approvals
- **Don't proceed** until concerns are addressed

### Calling Other Agent

**Option 1: Use the CLI (recommended):**
```bash
workflow review-proposal <task-id>    # auto-calls agent
workflow review-code <task-id>        # auto-calls agent
```

**Option 2: Call agent directly:**
```bash
response=$(HTTP_PROXY= HTTPS_PROXY= agent --print --trust --model gpt-5.3-codex-xhigh "<review prompt>")
```

**Important notes on calling agent:**
- Always unset `HTTP_PROXY` and `HTTPS_PROXY` to avoid proxy issues
- Use `--trust` for non-interactive (headless) mode
- Model and system prompt are configured in `agents/cursor.md`
- Override model via env var: `export WORKFLOW_AGENT_MODEL=sonnet-4`

### Issue Sync Protocol

When a task has an associated `issue_number` in `meta.json`, **sync key actions to the Issue as comments with identity markers**:

- The `workflow` CLI auto-syncs review results (Cursor Agent reviews)
- **You (Claude) must manually sync your own actions** using:
  ```bash
  workflow issue-comment <number> "🧠 **[Claude Code — <Phase>]**

  <your content here>"
  ```

**Identity markers:**
- `🧠 **[Claude Code — ...]**` — Claude's actions
- `🤖 **[Cursor Agent — ...]**` — Cursor's reviews (auto-synced by CLI)
- `🔧 **[Workflow — ...]**` — status transitions (auto-synced by CLI)

**When there is NO `issue_number`**: skip all sync, work purely locally.

### Communication Protocol
- All artifacts in `.workflow/plans/<task-id>/`
- Proposals: `proposal.md`, `proposal-v2.md`, `proposal-final.md`
- Reviews: `review-1.md`, `review-2.md`
- Code reviews: `code-review-1.md`, `code-review-2.md`
- Final diff: `final.diff`

## Important Rules

### User Interaction
1. **Always engage user first** - Don't write proposal without discussion
2. **Ask clarifying questions** - Understand requirements deeply
3. **Present options** - Don't assume, let user choose approach
4. **Wait for approval** at Phase boundaries (after plan, after code)
5. **Summarize clearly** - User shouldn't need to read full files

### Auto-Review Protocol
1. **No user involvement** during agent-to-agent reviews
2. **Max 5 rounds** - Escalate to user if can't agree
3. **Save all artifacts** - Full audit trail
4. **Clear progress** - Log each iteration

## Error Handling

- If `agent` command fails: inform user, pause workflow
- If review response unclear: ask reviewer to clarify
- If 5 rounds without agreement: present both views to user for decision
- If user rejects: return to previous phase, incorporate feedback
