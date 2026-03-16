# 使用示例

## 示例 1: 重构认证系统（Claude 执行）

这是一个大型重构任务，涉及架构设计和多个模块的改动，适合由 Claude Code 执行。

```bash
# 1. 初始化工作流（如果还没初始化）
cd ~/develop/pilot
workflow init

# 2. 创建任务，指定 Claude 为执行者
workflow create "refactor-auth-system" claude

# 3. 编辑任务描述
vim .workflow/plans/20260316-211730-refactor-auth-system/task.md

# 4. Claude Code 编写技术方案
# 在 Claude Code 中说：
# "请为任务 20260316-211730-refactor-auth-system 编写技术方案，保存到相应目录"

# 5. Cursor Agent review 方案
workflow review-proposal 20260316-211730-refactor-auth-system
# 在 Cursor 中使用 agent review 方案

# 6. 如果需要修改，Claude 更新方案，然后再次 review
# 重复直到双方满意

# 7. 批准方案
workflow approve-proposal 20260316-211730-refactor-auth-system

# 8. Claude Code 实现代码
workflow implement 20260316-211730-refactor-auth-system
# 在 Claude Code 中根据方案实现

# 9. Cursor Agent review 代码
workflow review-code 20260316-211730-refactor-auth-system

# 10. 如果需要修改，继续修改和 review

# 11. 最终批准
workflow approve 20260316-211730-refactor-auth-system

# 12. 提交代码
git add .
git commit -m "refactor: redesign authentication system

- Extract auth logic into separate service
- Implement JWT token refresh mechanism
- Add role-based access control
- Update API endpoints to use new auth flow

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

## 示例 2: 修复登录 Bug（Cursor 执行）

这是一个具体的 bug 修复，范围明确，适合由 Cursor Agent 快速处理。

```bash
cd ~/develop/rush-app
workflow init  # 如果需要

# 创建任务，指定 Cursor 为执行者
workflow create "fix-login-redirect" cursor

# 编辑任务描述
vim .workflow/plans/20260316-213000-fix-login-redirect/task.md

# Cursor Agent 编写方案
workflow propose 20260316-213000-fix-login-redirect
# 在 Cursor 中使用 agent 编写方案

# Claude Code review
workflow review-proposal 20260316-213000-fix-login-redirect
# 在 Claude Code 中 review

# 批准并实现
workflow approve-proposal 20260316-213000-fix-login-redirect
workflow implement 20260316-213000-fix-login-redirect

# Cursor 实现代码，Claude review
workflow review-code 20260316-213000-fix-login-redirect

# 批准并提交
workflow approve 20260316-213000-fix-login-redirect
git add .
git commit -m "fix: correct login redirect behavior"
git push
```

## 示例 3: 添加新功能（协作决定）

当不确定应该由谁执行时：

```bash
# 创建任务时不指定执行者，让工具交互式询问
workflow create "add-user-profile-page"

# 工具会提示选择:
# 1) claude  - 用于重构、架构设计、原则性讨论
# 2) cursor  - 用于小改动、单点修改、具体功能
# 选择 (1/2):

# 根据功能的复杂度和影响范围选择合适的执行者
```

## 常用命令组合

### 快速查看所有任务
```bash
workflow list
```

### 查看特定任务详情
```bash
workflow status <task-id>
```

### 查看任务目录中的所有文件
```bash
ls -la .workflow/plans/<task-id>/
```

### 查看方案内容
```bash
cat .workflow/plans/<task-id>/proposal.md
```

### 查看最新的 review
```bash
cat .workflow/plans/<task-id>/proposal-review-1.md
cat .workflow/plans/<task-id>/code-review-1.md
```

## 工作流技巧

### 1. 方案讨论阶段

如果 review 提出了问题，执行者应该：
- 直接修改 `proposal.md`
- 或创建 `proposal-v2.md` 保留历史版本
- 然后观察者进行新一轮 review

### 2. 代码 Review 阶段

如果代码需要修改：
- 执行者修改代码
- 保存新的 diff: `git diff > .workflow/plans/<task-id>/changes-v2.diff`
- 观察者再次 review

### 3. 保存讨论记录

可以在任务目录中创建 `discussion.md` 记录双方的讨论：

```bash
echo "## Discussion" >> .workflow/plans/<task-id>/discussion.md
echo "### Round 1" >> .workflow/plans/<task-id>/discussion.md
# 记录讨论内容
```

### 4. 团队协作

如果需要团队共享工作流记录：

```bash
# 修改 .workflow/.gitignore，允许提交
echo "# Share workflow with team" > .workflow/.gitignore
echo "!plans/" >> .workflow/.gitignore
echo "!config.json" >> .workflow/.gitignore

# 提交到项目仓库
git add .workflow/
git commit -m "docs: add workflow records for <task>"
```
