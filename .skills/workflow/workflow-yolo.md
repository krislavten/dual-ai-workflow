---
description: Dual AI YOLO workflow - Fully automated task execution with peer review, minimal user intervention
trigger: When user says "/workflow-yolo"
mode: command
targetAgents:
  - claude-code
---

# Dual AI Workflow - YOLO Mode 🚀

Fully automated execution. You handle everything, user only confirms final commit.

## Flow

```
User: /workflow-yolo <task> <executor>
  ↓
Executor: Draft proposal independently
  ↓
Executor ↔ Reviewer: Auto-iterate (no user)
  ↓
Executor: Implement code
  ↓
Executor ↔ Reviewer: Auto-iterate (no user)
  ↓
Executor: "✅ Done! Commit? (yes/no)"
  ↓
User: yes
  ↓
Commit!
```

## Instructions

### If YOU are the Executor

1. **Create task**: `workflow create "<name>" <executor>`

2. **Draft proposal independently**
   - Don't ask user for input
   - Use your best judgment
   - Write complete technical proposal
   - Save to `.workflow/plans/<task-id>/proposal.md`

3. **Auto-review loop**
   ```bash
   for round in 1..5; do
     response=$(agent --print --mode=ask "Review this proposal: ...")
     if [[ $response == *"APPROVE"* ]]; then
       break
     else
       # Update proposal based on concerns
       # Save as proposal-v{round}.md
     fi
   done
   ```

4. **Implement code**
   - Follow approved proposal
   - Write all necessary code
   - Run tests

5. **Auto-code review loop**
   ```bash
   for round in 1..5; do
     diff=$(git diff)
     response=$(agent --print --mode=ask "Review this code: $diff")
     if [[ $response == *"APPROVE"* ]]; then
       break
     else
       # Fix issues
     fi
   done
   ```

6. **Present final result**
   ```
   ✅ Task complete and peer-reviewed!

   Summary: [What was done]

   Changes:
   - [File 1]: [Description]
   - [File 2]: [Description]

   Review iterations:
   - Proposal: {N} rounds
   - Code: {M} rounds

   📄 Full details: .workflow/plans/<task-id>/
   📊 Diff: .workflow/plans/<task-id>/final.diff

   Ready to commit? (yes/no)
   ```

7. **If user approves**: Create commit with both co-authors

### If YOU are the Reviewer

- Wait to be called by executor via `agent --print`
- Review thoroughly
- Respond with `APPROVE` or `CONCERNS: <list>`
- Don't involve user

## Key Differences from Normal Mode

| Aspect | Normal Mode | YOLO Mode |
|--------|-------------|-----------|
| User discussion | Yes, co-design | No, executor decides |
| Proposal approval | User confirms | Auto-approved by peer |
| Code approval | User confirms | Auto-approved by peer |
| User checkpoints | 3 (start, plan, code) | 1 (commit only) |

## When to Use YOLO

✅ Good for:
- Small, well-defined tasks
- Bug fixes with clear reproduction
- Routine refactoring
- Adding simple features
- You trust AI to handle autonomously

❌ Not good for:
- Architectural changes
- Security-critical features
- Ambiguous requirements
- Cross-team coordination
- First time in new codebase

## Example

```bash
User: /workflow-yolo 修复用户头像上传失败的bug cursor

# Cursor works autonomously:
# 1. Reproduces bug
# 2. Writes proposal with root cause analysis
# 3. Gets Claude review (3 rounds)
# 4. Implements fix
# 5. Gets Claude code review (2 rounds)
# 6. All tests pass

Cursor: ✅ Bug fixed!

Summary: File upload middleware was rejecting image/webp format

Changes:
- middleware/upload.ts: Added webp to allowed types
- tests/upload.test.ts: Added webp test case

Ready to commit? (yes/no)

User: yes

Cursor: [commits] Done! 🎉
```

## Notes

- **Speed**: Much faster than normal mode
- **Risk**: Higher - less human oversight
- **Audit**: Still full trail in `.workflow/plans/`
- **Rollback**: Easy with git if issues found later
