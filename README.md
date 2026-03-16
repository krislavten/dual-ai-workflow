# Dual AI Workflow

双 AI 协作工作流工具 - 支持 Claude Code 和 Cursor Agent 动态角色协作

## ✨ 两种工作模式

### 👥 普通模式（默认）- 协作式

```bash
# 在 Claude Code 中
/workflow 重构用户认证系统 claude
```

**你参与关键决策点：**
1. 💬 **你 + AI 一起讨论**方案（问答式，共同设计）
2. 🤖 AI 写正式方案 → 自动跟另一个 AI review（你不参与）
3. ✅ **你确认方案**
4. 🤖 AI 实现代码 → 自动跟另一个 AI review（你不参与）
5. ✅ **你确认实现**
6. ✅ **你确认提交**

**3个决策点，其余自动化**

### 🚀 YOLO 模式 - 全自动

```bash
/workflow-yolo 修复登录重定向bug cursor
```

**AI 完全自主：**
1. 🤖 AI 独立分析和设计
2. 🤖 两个 AI 自动讨论方案
3. 🤖 AI 实现代码
4. 🤖 两个 AI 自动 review 代码
5. ✅ **你只确认最后提交**

**1个决策点，极速完成**

---

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
git clone git@github.com:krislavten/dual-ai-workflow.git ~/develop/dual-ai-workflow

# 运行安装脚本
cd ~/develop/dual-ai-workflow
./install.sh
```

安装脚本会：
- 创建 `workflow` 命令软链接到 `~/.local/bin/`
- 安装 `/workflow` skill 到 `~/.claude/skills/`

## 使用方式

### 方式 1: Skill（推荐）⚡

#### 普通模式 - 你参与设计

```
/workflow 重构用户认证系统，使用JWT替换session claude
```

**流程：**
1. AI 跟你对话，问需求细节
2. 你们一起讨论技术方案
3. AI 写正式方案 → 自动跟另一个 AI 讨论优化
4. AI 给你看最终方案，**你确认**
5. AI 实现代码 → 自动跟另一个 AI code review
6. AI 给你看实现，**你确认**
7. 提交

**你控制方向，AI 负责执行和互审**

#### YOLO 模式 - 完全托管

```
/workflow-yolo 修复用户头像上传失败 cursor
```

**流程：**
1. AI 自主分析问题
2. 两个 AI 自动讨论方案
3. AI 实现代码
4. 两个 AI 自动 review
5. AI 给你看结果，**你确认提交**

**适合小改动和明确任务**

### 方式 2: 命令行工具（手动模式）

如果你想要手动控制每一步：

#### 1. 在项目中初始化
```bash
cd your-project
workflow init
```

#### 2. 创建任务
```bash
# Claude 作为执行者（适合重构、架构设计）
workflow create "refactor-auth-system" claude

# Cursor 作为执行者（适合小改动、功能实现）
workflow create "fix-login-bug" cursor
```

#### 3. 完整工作流

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
