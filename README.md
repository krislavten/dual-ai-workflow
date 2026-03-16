# Dual AI Workflow

双 AI 协作工作流工具 - 支持 Claude Code 和 Cursor Agent 动态角色协作

## 核心理念

不固定 AI 角色，而是根据任务类型动态分配：

- **执行者 (Executor)**: 负责写方案、写代码
- **观察者 (Reviewer)**: 负责 review 方案、review 实现

### 任务分配原则

- **Cursor Agent 执行**: 小改动、单点修改、具体功能实现
- **Claude Code 执行**: 重构、架构设计、原则性讨论、跨模块改动

## 安装

```bash
# 克隆仓库
git clone <your-repo-url> ~/.dual-ai-workflow

# 添加到 PATH
echo 'export PATH="$HOME/.dual-ai-workflow/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 或创建软链接
ln -s ~/.dual-ai-workflow/bin/workflow ~/.local/bin/workflow
```

## 使用流程

### 1. 在项目中初始化
```bash
cd your-project
workflow init
```

### 2. 创建任务
```bash
# Claude 作为执行者（适合重构、架构设计）
workflow create "refactor-auth-system" claude

# Cursor 作为执行者（适合小改动、功能实现）
workflow create "fix-login-bug" cursor
```

### 3. 完整工作流

```bash
# 编辑任务描述
vim .workflow/plans/<task-id>/task.md

# 执行者写方案
workflow propose <task-id>

# 观察者 review 方案
workflow review-proposal <task-id>

# 如需修改，重复上述步骤，直到双方满意

# 批准方案
workflow approve-proposal <task-id>

# 执行者实现代码
workflow implement <task-id>

# 观察者 review 代码
workflow review-code <task-id>

# 如需修改，重复上述步骤

# 最终批准
workflow approve <task-id>

# 提交代码
git commit && git push
```

## 工作流状态

每个任务的进度都会保存在 `.workflow/plans/<task-id>/` 目录中：

```
.workflow/
└── plans/
    └── 20260316-211730-refactor-auth/
        ├── meta.json              # 任务元数据和状态
        ├── task.md                # 任务描述
        ├── proposal.md            # 方案文档
        ├── proposal-review-1.md   # 第一轮方案审查
        ├── proposal-review-2.md   # 第二轮方案审查（如有）
        ├── code-review-1.md       # 第一轮代码审查
        ├── code-review-2.md       # 第二轮代码审查（如有）
        └── changes.txt            # 改动的文件列表
```

## 命令列表

- `workflow init` - 在项目中初始化工作流
- `workflow create <name> [executor]` - 创建新任务
- `workflow list` - 列出所有任务
- `workflow status <task-id>` - 查看任务状态
- `workflow propose <task-id>` - 执行者编写方案
- `workflow review-proposal <task-id>` - 观察者 review 方案
- `workflow approve-proposal <task-id>` - 批准方案
- `workflow implement <task-id>` - 执行者实现代码
- `workflow review-code <task-id>` - 观察者 review 代码
- `workflow approve <task-id>` - 最终批准

## 示例场景

### 场景 1: 大型重构 (Claude 执行)

```bash
workflow create "refactor-api-layer" claude
# Claude Code 作为执行者进行架构设计
# Cursor Agent 作为观察者提供代码层面的审查
```

### 场景 2: 修复 Bug (Cursor 执行)

```bash
workflow create "fix-memory-leak" cursor
# Cursor Agent 快速定位和修复
# Claude Code 作为观察者确保修复的完整性
```

## 配置

可以在项目的 `.workflow/config.json` 中自定义配置（TODO）

## License

MIT
