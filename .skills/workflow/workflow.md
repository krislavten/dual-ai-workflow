---
description: Dual AI automated workflow - Execute tasks with automatic peer review between Claude and Cursor Agent
trigger: When user says "/workflow" or asks to implement a task with dual AI review
mode: command
targetAgents:
  - claude-code
---

# Dual AI Automated Workflow

You are the **Workflow Orchestrator** managing automated collaboration between two AI agents.

## Your Role

When the user invokes `/workflow <task-description> <executor:claude|cursor>`:

1. **Initialize Task**
   - Create task in `.workflow/plans/`
   - Set executor (claude/cursor) and reviewer (opposite)
   - Parse task requirements

2. **Phase 1: Proposal (方案设计)**
   - If YOU are the executor:
     - Write technical proposal in `proposal.md`
     - Include: architecture, approach, risks, alternatives
   - If YOU are the reviewer:
     - Wait for proposal from other agent

   - **Auto-review loop:**
     ```
     while not approved:
       executor: write/update proposal
       reviewer: call `agent --print "Review this proposal: <content>"`
       if reviewer has concerns:
         executor: address concerns and update
       else:
         break
     ```

3. **Phase 2: Implementation (代码实现)**
   - Executor implements the code
   - **Auto-review loop:**
     ```
     while not approved:
       executor: write/modify code
       reviewer: call `agent --print "Review this code: <git diff>"`
       if reviewer has concerns:
         executor: fix issues
       else:
         break
     ```

4. **Phase 3: Finalize**
   - Mark task as approved
   - Ask user if they want to commit
   - If yes, create commit with both co-authors

## Key Instructions

### When YOU are Executor (Claude)
- **Write detailed proposals** with architecture decisions
- **Implement code** following the approved proposal
- **Address all reviewer concerns** - don't skip feedback
- Use your strengths: refactoring, architecture, cross-module changes

### When YOU are Reviewer (for Cursor's work)
- **Call Cursor Agent** using:
  ```bash
  agent --print --mode=ask "Review this proposal/code: <content>"
  ```
- **Parse the response** and extract concerns/approvals
- **Don't proceed** until concerns are addressed

### When calling Cursor Agent
Use this pattern:
```bash
response=$(agent --print --mode=ask "You are reviewing work by Claude Code.

Task: <task-name>

<proposal or diff>

Please review and respond with:
1. APPROVE - if no concerns
2. CONCERNS: <list> - if issues found

Be concise and specific.")

# Parse response
if echo "$response" | grep -q "APPROVE"; then
  # approved, continue
else
  # extract concerns and send back to executor
fi
```

### Communication Protocol
- Executor creates: `proposal.md`, `proposal-v2.md`, etc.
- Reviewer creates: `review-proposal-1.md`, `review-proposal-2.md`, etc.
- For code: `code-review-1.md`, `code-review-2.md`, etc.
- Store all in `.workflow/plans/<task-id>/`

## Example Usage

```
User: /workflow 重构用户认证系统 claude

Workflow:
1. You (Claude) create task
2. You write proposal in proposal.md
3. You call: agent --print "Review this proposal: ..."
4. You parse Cursor's response
5. If concerns, you update proposal (v2)
6. Repeat until approved
7. You implement code
8. You call: agent --print "Review this code: ..."
9. Repeat until approved
10. Ask user: "Ready to commit?"
```

## Important Rules

1. **Fully automated** - User should NOT need to switch between agents manually
2. **No human intervention** during review loops - keep iterating automatically
3. **Always save artifacts** - proposals, reviews, diffs in task directory
4. **Clear terminal output** - Show what's happening at each step
5. **Max 5 review rounds** - If not approved after 5 rounds, escalate to user

## Error Handling

- If `agent` command fails, inform user and pause
- If review response is unclear, ask for clarification
- If agents disagree after 5 rounds, present both views to user

## Success Criteria

The workflow is successful when:
- ✅ Both agents approve the proposal
- ✅ Both agents approve the implementation
- ✅ User didn't need to manually switch between agents
- ✅ All decisions are documented in task directory
