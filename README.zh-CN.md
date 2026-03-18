# Sparring

一个 Claude Code 插件，为 AI 编码引入自动 peer review —— 一个 AI 写，另一个 AI 挑战。

就像拳击里的对练搭档——互相推动对方变强，而不是为了分出胜负。

## 为什么需要

AI Agent 写代码很快，但会犯错——幻觉 API、遗漏边界情况、引入隐蔽的回归。让人逐一 review 每段 AI 生成的代码，成本太高。

**这个插件引入第二个 AI 作为自动审查者。** Claude Code 写方案和代码，Cursor Agent 以严格的"找 bug"心态进行审查——最多 5 轮，直到双方达成一致。你只在关键节点介入决策。

效果：AI 产出更可靠，人工 review 更少，心智负担更低。

## 安装

```
/plugin marketplace add krislavten/dual-ai-workflow
/plugin install sparring@sparring
```

然后运行 `/sparring:setup` 安装依赖、选择审查模型。

## 命令

| 命令 | 说明 |
|------|------|
| `/sparring:setup` | 安装依赖、选择模型、配置权限 |
| `/sparring:workflow <任务>` | 普通模式 —— 先讨论再自动审查 |
| `/sparring:yolo <任务>` | YOLO 模式 —— 全自动，只确认提交 |
| `/sparring:issue <看板URL> [issue编号]` | Issue 模式 —— 从 GitHub Issue 获取任务 |

## 工作流程

```
你描述任务
  ↓
执行者写方案
  ↓
审查者挑战方案（最多 5 轮）
  ↓
你确认方案
  ↓
执行者写代码
  ↓
审查者挑战代码（最多 5 轮）
  ↓
你确认并提交
```

**交叉审查原则**：在给你任何结论、建议或决策之前，执行者会先让另一个 AI 审查。不只是方案和代码，任何重要的技术建议都要过审。

- **普通模式** —— 你先参与方案讨论，然后 AI 双方自动完成 review
- **YOLO 模式** —— AI 端到端全自动处理，你只确认最终提交
- **Issue 模式** —— 任务来自 GitHub Issue，讨论过程自动同步到 Issue 评论

## Issue 驱动工作流

独立功能，适合通过 GitHub Issues 和 Project 看板管理工作的团队。

使用时传入看板链接：
```
/sparring:issue https://github.com/orgs/your-org/projects/3 106
```

自动完成：
- 认领 Issue，在看板上移到「进行中」
- AI 讨论过程自动同步到 Issue 评论，带身份标记
- 完成后创建 PR，Issue 移到「审查中」

不需要固定配置——每次对话传入看板链接即可。

## 审查者配置

审查者（Cursor Agent）的模型和 prompt 配置在 `agents/cursor.md`，由 `/sparring:setup` 生成。

默认模型：`gpt-5.3-codex-xhigh`，配合严格的审查 prompt —— 不讨好、不客套，假设代码里有 bug 去找它，关注边界情况和竞态条件。

按需覆盖：
```bash
export WORKFLOW_AGENT_MODEL=opus-4.6-thinking
```

## License

MIT
