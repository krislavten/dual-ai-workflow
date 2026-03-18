# Sparring — AI 左右脑互搏

一个 Claude Code 插件。一个 AI 写，另一个 AI 找茬。像拳击陪练一样，互相推动变强。

[English](README.en.md)

## 快速体验

```bash
# 1. 安装插件
/plugin marketplace add krislavten/dual-ai-workflow
/plugin install sparring@sparring

# 2. 初始化（自动装依赖、选模型）
/sparring:setup

# 3. 开始用
/sparring:workflow 给登录接口加 rate limiting
```

就这么简单。Claude 写方案和代码，Cursor Agent 自动审查，你只管拍板。

## 为什么需要

AI 写代码快，但会犯错——幻觉 API、漏掉边界、引入回归。让人逐一 review 每段 AI 代码？不现实。

**Sparring 引入第二个 AI 做自动审查。** Claude Code 写方案和代码，Cursor Agent 以"假设有 bug，找到它"的心态审查——最多 5 轮，直到双方一致。你只在关键节点介入。

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

## 审查者配置

Cursor Agent 的模型和 prompt 在 `agents/cursor.md`，由 `/sparring:setup` 生成。

默认：`gpt-5.3-codex-xhigh`，严格审查 prompt — 不讨好、不客套、假设有 bug 去找它。

临时切模型：
```bash
export WORKFLOW_AGENT_MODEL=opus-4.6-thinking
```

## License

MIT
