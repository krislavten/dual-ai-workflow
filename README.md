# Sparring — AI 左右脑互搏

一个 Claude Code 插件。一个 AI 写，另一个 AI 找茬。像拳击陪练一样，互相推动变强。

[English](README.en.md)

## 快速体验

```bash
# 1. 安装插件
/plugin marketplace add krislavten/dual-ai-workflow
/plugin install sparring@sparring

# 2. 重启会话（输入 /exit 后重新打开 claude）

# 3. 初始化（自动装依赖、选模型）
/sparring:setup

# 4. 开始用
/sparring:workflow 给登录接口加 rate limiting
```

就这么简单。Claude 写方案和代码，审查者可选 **Cursor Agent / Codex CLI / 智谱 GLM**，你只管拍板。支持[主/备降级](#主--备降级)——主 reviewer 挂了自动切到备用 backend，工作流不阻塞。

## 为什么需要

AI 写代码快，但会犯错——幻觉 API、漏掉边界、引入回归。让人逐一 review 每段 AI 代码？不现实。

**Sparring 引入第二个 AI 做自动审查。** Claude Code 写方案和代码，审查者可选 Cursor Agent / Codex CLI / 智谱 GLM，以"假设有 bug，找到它"的心态审查——最多 5 轮，直到双方一致。你只在关键节点介入。支持配置主+备，主 reviewer 调用失败时自动降级。

效果：**AI 产出更可靠，人工 review 更少，心智负担更低。**

## 命令

| 命令 | 说明 |
|------|------|
| `/sparring:setup` | 安装依赖、选模型、配权限 |
| `/sparring:workflow <任务>` | 普通模式 — 先讨论，再自动审查 |
| `/sparring:yolo <任务>` | YOLO 模式 — 全自动，只确认提交 |
| `/sparring:issue <看板URL> [编号]` | Issue 模式 — 从 GitHub Issue 接任务 |

## 工作流程

```
你描述任务
  ↓
Claude 写方案
  ↓
Cursor 挑战方案（最多 5 轮）
  ↓
你确认
  ↓
Claude 写代码
  ↓
Cursor 挑战代码（最多 5 轮）
  ↓
你确认并提交
```

### 交叉审查原则

不只审方案和代码。**Claude 给你任何建议或结论之前，都会先让 Cursor 审一遍。**

"建议用 Redis 做缓存" → 先让 Cursor 质疑 → 确认没问题或调整后 → 再告诉你。

### 三种模式

- **普通** — 你参与方案讨论，AI 双方自动完成审查，你最后拍板
- **YOLO** — AI 全自动，你只确认最终提交。适合小改动和明确任务
- **Issue** — 任务来自 GitHub Issue，讨论自动同步到 Issue 评论

## Issue 驱动工作流

给团队用的。通过 GitHub Issues + Project 看板管理工作。

```
/sparring:issue https://github.com/orgs/your-org/projects/3 106
```

自动完成：认领 Issue → 看板移到「进行中」→ AI 讨论同步到 Issue 评论 → 完成后提 PR → 移到「审查中」

所有评论带身份标记，一眼看出谁说的：
- 🧠 Claude Code — 方案、实现
- 🤖 Cursor Agent — 审查意见
- 🔧 Workflow — 状态流转

每次对话传看板链接就行，不需要固定配置。

## 多 Agent 并行 + 审查（配合 ClawTeam）

Sparring 负责审查质量，[ClawTeam](https://github.com/HKUDS/ClawTeam) 负责多 agent 并行编排。两个组合使用，每个 agent 既能并行加速，又有质量保障。

```
ClawTeam 分 3 个任务并行
  ├── Claude #1: auth 模块  ← Sparring: Cursor 审查
  ├── Claude #2: database 层 ← Sparring: Cursor 审查
  └── Claude #3: frontend   ← Sparring: Cursor 审查
```

### 安装 ClawTeam

```bash
pipx install clawteam
```

### 使用

```bash
# 1. 创建团队
clawteam team spawn-team my-project -d "重构用户系统" -n leader

# 2. Spawn 多个 Claude Code worker，各自独立工作 + Sparring 审查
clawteam spawn tmux claude --team my-project --agent-name auth \
  --task "实现 auth 模块。写完后运行 workflow review-code my-project 让 Cursor 审查"

clawteam spawn tmux claude --team my-project --agent-name db \
  --task "实现 database 层。写完后运行 workflow review-code my-project 让 Cursor 审查"

# 3. 看所有 agent 同时工作
clawteam board attach my-project
```

每个 worker 在独立的 git worktree + tmux window 里工作，互不干扰。

### Issue + Team：从看板接任务，拆分并行开发

适合大的 Issue——一个人做太慢，拆成子任务让多个 agent 并行。

```bash
# 1. 认领 Issue
workflow --project https://github.com/orgs/your-org/projects/3 issue-claim 106

# 2. 读 Issue 内容，规划子任务
gh issue view 106 --json body,title

# 3. 创建团队，按子任务 spawn worker
clawteam team spawn-team issue-106 -d "Issue #106: 重构用户认证" -n leader

clawteam spawn tmux claude --team issue-106 --agent-name auth \
  --task "实现 OAuth2 模块。完成后运行 workflow review-code issue-106 让 Cursor 审查"

clawteam spawn tmux claude --team issue-106 --agent-name tests \
  --task "给认证模块写集成测试。完成后运行 workflow review-code issue-106 让 Cursor 审查"

# 4. 等所有 worker 完成后，合并并提 PR
# leader 合并各 worktree，创建 PR 关联 Issue
workflow --project https://github.com/orgs/your-org/projects/3 issue-done 106 <pr-url>
```

### 自动接单：Loop 轮询看板

让 Claude 定时轮询看板，有新 Issue 自动认领并启动 Team。

```bash
# 在 Claude Code 里用 /loop 技能，每 5 分钟轮询一次
/loop 5m /sparring:issue https://github.com/orgs/your-org/projects/3
```

或者用 `workflow` CLI 手动轮询：

```bash
# 一次性扫描可认领的 Issue
workflow --project https://github.com/orgs/your-org/projects/3 issue-poll

# 持续轮询（用 watch）
watch -n 300 workflow --project https://github.com/orgs/your-org/projects/3 issue-poll
```

流程：发现新 Issue → 认领 → 分析复杂度 → 小任务直接 Sparring 单 agent 做 → 大任务启动 ClawTeam 并行。

## 审查后端配置

支持三种 backend，可自由组合主备：

| Backend | 说明 | 特点 |
|---------|------|------|
| `cursor` | Cursor Agent（默认） | 本机走 Cursor 账号 |
| `codex` | Codex CLI | 本机走 OpenAI 账号 |
| `glm` | 智谱 GLM API | 国产、pay-as-you-go，适合降级备份 |

### 配置方式

从低到高优先级：**内置默认 → 全局 config → 项目 config → 环境变量**。

```bash
# 一键生成全局配置（chmod 600，存 API key）
workflow config init

# 项目级配置（团队共享 backend 选型，api_key 仍放全局）
workflow config init project

# 看合并后的生效配置（key 自动掩码）
workflow config show

# 取单个值
workflow config get review.backend
workflow config get glm.api_key   # 输出掩码
```

**全局配置** `~/.config/sparring/config.json`（chmod 600，存 api_key，不入库）：

```json
{
  "review": {
    "backend": "cursor",
    "fallback": "glm",
    "timeout": 60,
    "retries": 1
  },
  "glm": {
    "api_key": "<id.secret>",
    "model": "glm-5.1"
  }
}
```

**项目配置** `.sparring/config.json`（默认入库，团队共享；`.sparring/.gitignore` 自动屏蔽 secrets）：

```json
{
  "review": {
    "backend": "cursor",
    "fallback": "glm"
  }
}
```

### 主 + 备降级

主 backend 调用失败（超时、网络错、CLI 异常等任意非零退出）时，自动切到备 backend。

触发降级时日志会明确提示：
```
⚠ 主 backend Cursor Agent 调用失败，降级到 GLM...
```

**三种典型组合**：

- **A) 纯 GLM** — `review.backend = glm`，国产按量付费
- **B) Cursor 主 + GLM 备** — 推荐，Cursor 抽风也不阻塞（`review.backend = cursor`, `review.fallback = glm`）
- **C) Codex 主 + GLM 备** — Codex 额度省着用

### 环境变量（覆盖 config.json 任意字段）

主推 `SPARRING_*` 前缀，历史 `WORKFLOW_*` 仍兼容。命名规则：`SPARRING_<大写_下划线>` 对应 `key.path`。

```bash
# 常用
export SPARRING_REVIEW_BACKEND=glm       # review.backend
export SPARRING_REVIEW_FALLBACK=cursor   # review.fallback
export SPARRING_GLM_API_KEY=<id.secret>  # glm.api_key
export SPARRING_REVIEW_TIMEOUT=120       # review.timeout
export SPARRING_REVIEW_RETRIES=2         # review.retries

# 历史变量（仍生效）
export WORKFLOW_REVIEW_BACKEND=glm
export WORKFLOW_REVIEW_BACKEND_FALLBACK=cursor
export WORKFLOW_GLM_API_KEY=<id.secret>
```

### 各 backend 参数

| key | 默认 | 说明 |
|---|---|---|
| `cursor.model` | 读 `agents/cursor.md` | 临时切：`SPARRING_CURSOR_MODEL` |
| `codex.model` | 读 codex config | 可填 `gpt-5.4` 等 |
| `codex.effort` | null | `none\|minimal\|low\|medium\|high\|xhigh` |
| `codex.home` | `/tmp/workflow-codex-home-<user>` | codex 本地状态 |
| `glm.api_key` | **必填** | 从 <https://open.bigmodel.cn/usercenter/apikeys> 申请 |
| `glm.model` | `glm-5.1` | 换其他智谱模型 |
| `glm.thinking` | `disabled` | 开 `enabled` 质量更高但慢 |
| `glm.max_tokens` | `8192` | 开 thinking 时建议 `65536` |
| `glm.temperature` | `0.3` | review 场景不需要太高 |
| `glm.api_base` | 官方 URL | 可换自建网关 |

### 验证

```bash
workflow verify   # 主/备 backend 连通性 + 模型 + key 掩码
```

## 后台审查作业（可选）

当审查耗时较长时，可将 review 放到后台执行：

```bash
workflow review-proposal-bg <task-id>
workflow review-code-bg <task-id>

workflow review-status [job-id|task-id]
workflow review-result <job-id>
workflow review-cancel <job-id>
```

## License

MIT
