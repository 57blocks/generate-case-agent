# Playwright Test Harness

[![English](https://img.shields.io/badge/Language-English-blue)](./README.md)
[![简体中文](https://img.shields.io/badge/%E8%AF%AD%E8%A8%80-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-red)](./README.zh-CN.md)

> 通过一张测试用例截图和一句触发短语，自动生成可运行的 Playwright 测试。

这个仓库提供了一套基于 Claude Code 的 Playwright agent harness。将它安装到你的
Playwright 项目后，你可以提供一张测试用例截图（来自 CSV、表格或文档）或一段自然语言描述，
harness 会自动执行完整流程：

**需求拆解 → 架构设计 → MCP 验证 → 代码生成 → 自动调试 → 知识沉淀**

最终产出是在你的仓库上下文中可运行、可通过的测试，以及可复用的项目经验，便于后续继续生成测试。

---

## 快速开始

```bash
# 1. 在你的 Playwright 项目根目录下，把 harness 拷进来
git clone <this-repo> /tmp/playwright-test-harness
cp -r /tmp/playwright-test-harness/.claude/agents .claude/
cp -r /tmp/playwright-test-harness/.claude/skills .claude/
cp -r /tmp/playwright-test-harness/scripts .
chmod +x scripts/*.sh

# 2. 运行 preflight，检查项目是否具备 harness 所需的基础设施
bash scripts/preflight.sh
```

`preflight` 会逐项扫描你的项目，告诉你哪些能力已经具备、哪些缺失，以及哪些虽然不是硬性要求，
但缺失后会降低生成质量。**建议先修复 ❌ 错误项，再决定是否补齐 ⚠️ 警告项。**
关于每一项缺失会带来什么影响，以及如何补齐，请继续阅读
[“占位符与项目契约”](#占位符与项目契约agent-从你项目的哪里取数)。

```bash
# 3. preflight 通过后，在 Claude Code 会话里触发 harness
#    丢一张测试用例截图，再加一句触发短语，例如：
#       增加 SA-001 用例
#       add test for TC-050
#       更新 TC-050 用例
```

编排者 agent 会自动启动整条流水线。遇到失败时，会最多自动迭代修复 5 次。

---

```
"增加 SA-001 用例"                       analyst
        +              ─────────►   ┌────────►─────────► architect
   一张截图                          │                       │
                                     │                       ▼
                                     │                    coder
                                     │                       │
                                     │       ┌────────────── ▼
                                     │       │           runner ◄──┐
                                     │       │             │       │
                                     │       │ 失败时       │       │ 自动迭代
                                     └◄──────┴─────────────┤       │
                                                           ▼       │
                                                    summarizer ◄───┘
                                                           │
                                                           ▼
                                               你仓库中的一条通过测试
                                               + 写回 CLAUDE.md 的经验沉淀
```

---

## 为什么要做这个

手写 Playwright 测试通常是重复性工作：解析用例 → 找到或编写 Page Object → 在真实 UI
上验证 selector → 编写 spec → 调试各种不可避免的 timing 问题。这套 harness 将每一步
交给专门的 agent 处理，再通过轻量级的文件协议把它们串联起来，因此你可以：

- 用一张截图生成一条可运行的测试。
- 让 agent **自行迭代调试失败**，例如 selector 漂移、spinner 等待、虚拟滚动等常见问题。
- 将本次运行积累下来的经验自动写回你项目的 `CLAUDE.md`，为后续测试生成提供参考。

---

## 架构

整个 harness 由 6 个 agent 组成：1 个编排者和 5 个流水线阶段。每个阶段都会将自己的产物写入
`/tmp/tc_{case_id}_{stage}.md`；下一阶段**只读取这个文件**，不会读取上一阶段的聊天输出。
这种设计能让每个 agent 的上下文保持干净、职责保持聚焦。

```
[1] test-analyst     →  /tmp/tc_{id}_requirement.md
[2] test-architect   →  /tmp/tc_{id}_design.md         （使用 MCP Playwright 验证 selector）
[3] test-coder       →  编写 spec + Page Object 文件
[4] test-runner      →  /tmp/tc_{id}_run_report.md     （失败时迭代；必要时回退到第 1 / 2 阶段）
[5] test-summarizer  →  将经验更新回你仓库的 CLAUDE.md / agent / memory
```

| Agent | 职责 | 模型 |
|---|---|---|
| `add-test` | 编排者：负责阶段间路由并守护 artifacts | sonnet |
| `test-analyst` | 读取截图、必要时澄清需求，并将测试用例拆解为原子单元 | sonnet |
| `test-architect` | 选择 Page Object，并使用 MCP 验证新 selector | sonnet |
| `test-coder` | 只负责编写代码；不开浏览器，也不发明 selector | haiku |
| `test-runner` | 运行测试、根据 stack trace 分类失败、尽可能修复或上抛 | haiku |
| `test-summarizer` | 在测试通过后进行审计，并更新项目知识库 | sonnet |

---

## 用法

### 触发短语

编排者（`add-test` agent）支持识别中英文的多种自然触发短语：

| 短语 | 动作 |
|---|---|
| 增加 SA-001 用例 | 新增一条测试，ID = SA-001 |
| add test for TC-050 | 新增一条测试，ID = TC-050 |
| 更新 TC-050 用例 | 更新一条已有测试 |
| update test TC-050 | 更新一条已有测试 |
| 在 supioadmin 文件夹下增加用例 | 在指定目录下新增测试 |
| add a new test file | 新增一条测试（暂时没有具体 case ID） |

把测试用例截图发进对话（CSV / 表格 / 文档格式都可以，只要内容清晰可读），再附上一句触发短语。
编排者会自动沿着流水线执行下去。如果截图中没有清楚说明 role、environment 或测试数据，
analyst 会主动发起澄清。

### 你会看到什么

- **澄清问题**：由 analyst 在必要时提出
- **破坏性变更警告**：当 architect 发现新方案与现有代码冲突时提示
- **迭代更新信息**：由 runner 输出，例如 `Iteration 2: fix selector issue…`
- **会话总结**：说明实现了什么、复用了什么，以及向 `CLAUDE.md` 回写了哪些经验

### 自动迭代

当测试失败时，`test-runner` 会读取 stack trace，对失败进行分类，然后：

- 直接修复 timing、断言或页面上下文问题，或
- 上抛给 `test-architect`（selector 失败或设计问题）—— 只有 architect 有 MCP 能重新验证 selector；若根因是需求理解偏差，architect 会进一步上抛给 `test-analyst`

默认最多迭代 5 次，超过后会停止并汇报结果。

---

## 项目知识应该放在哪里

harness 将项目知识划分为五类，每一类都有明确的归属。**不要混在一起维护。**

| 类别 | 例子 | 应该放在哪里 |
|---|---|---|
| **A. 通用 Playwright / MCP 规则** | “不要用 `isVisible()` 来门控点击”；MCP 验证流程 | harness 的 `.claude/context/coding-rules.md` 模板（由用户复制到自己的项目中） |
| **B. 项目专属编码风格** | “Files tab 断言不带扩展名”；”等待 `.ant-spin-spinning` 消失” | **目标项目自己的** `CLAUDE.md` 和/或 `.claude/context/coding-rules.md` |
| **C. 可复用操作 Skill** | 业务流程（”登录 + 创建 + 验证”）或项目专属的技术模式（”以某角色登录”、”等待 AI 处理完成”），被多条测试复用 | **目标项目自己的** `.claude/skills/*.md`（本 harness 仅提供一个示例） |
| **D. 项目级事实** | 已开启的 feature flag、稳定的测试数据 ID、环境约束 | **目标项目的** `.claude/context/project-facts.md` —— 由 summarizer 写入，通过 git 共享给整个团队 |
| **E. 真实可运行的代码示例** | 一条通过的 spec 及其 Page Object | 你项目中现有的 `tests/` 和 `pages/` —— architect 会自行 grep 并参考 |

> 这个 harness 仓库只提供 **A**（模板）和 **C**（一个示例）。**B** 和 **D** 完全属于你的项目，
> **E** 应直接从你的代码库中读取，无需额外复制出来。

### Skill 的定位（C 类）

Skill 是一种**可复用的操作模板**，被多条测试调用。它可以是：

- **业务流程**：与应用领域相关的多步操作（创建 case、提交表单、发布 timeline）。
- **技术模式**：项目专属但非业务逻辑的重复步骤（以指定角色登录、等待 AI 处理完成、通过 connector 上传文件）。

`example-flow.md` 是一份模板，展示 skill 的写法。`test-architect` 在设计新测试之前，会扫描
目标项目的 `.claude/skills/` 目录，当关键词匹配时，优先复用这些文件中的代码模板，而不是从头重新发明。

如果你想了解 skill 的写法，可以直接查看
[`.claude/skills/example-flow.md`](.claude/skills/example-flow.md)。

---

## 占位符与项目契约（agent 从你项目的哪里取数）

打开 `.claude/agents/test-coder.md`，你会看到很多类似 `<project-fixtures-import>`、
`{ROLE}` 和 `{fixture1}` 的占位符。**这些并不是让你手动替换的**，而是给 LLM agent 使用的模板。
运行时，agent 会自动扫描你项目中的对应参考物，并完成填充。

但前提是：**这些参考物必须真实存在于你的项目里**。这正是 `preflight` 检查的内容。
下面这张表解释了每个占位符或配置项的来源，方便你系统性地补齐缺失部分：

| 占位符 / 配置 | agent 如何填充 | 你的项目需要提供什么 | 缺失后的后果 |
|---|---|---|---|
| `<project-fixtures-import>` | 读取你项目现有 spec 的 import 路径 | 至少一个可运行的 `*.spec.ts` | coder 不知道如何 import |
| `<project-constants-import>` | 同上 | 同上 | 同上 |
| `RoleName.{ROLE}` | 读取 `utils/constants.ts`（或类似文件）中的 enum | 项目中的角色枚举文件 | analyst 会反复询问 role 应该如何填写 |
| `{fixture1}, {fixture2}` | 读取 `fixtures.ts` 中导出的 fixture 名称 | 一个 fixtures 文件，并通过它注入 Page Object | 生成的测试可能会直接 `new XxxPage(...)` |
| `{module}`（新 spec 文件位置） | glob 你项目现有的 `tests/**` 目录结构 | 至少一到两个已组织好的测试目录 | 新文件可能落在不合适的位置 |
| `{snake_feature_name}` | 从用例描述自动生成 | 无 | - |
| `{CASE_ID}`、`{CASE_NAME}` | 从你的截图 / 文本输入中提取 | 无 | - |
| `<target-app-url>`（architect MCP 用） | 从 ROLE_CONFIG / 环境变量 / 你提供的 URL 中提取 | 项目中的 URL 配置，或你直接提供给 architect 的 URL | architect 无法在真实 UI 上验证 selector |
| `MENU.{X}`、`gotoMenu(...)` 一类导航 | 读取 BasePage / 共享 helper 中的导航方法 | 最好有 BasePage 和命名清晰的导航 helper | 生成的测试可能采用不一致的导航方式 |
| 项目编码风格（断言、loading 等待） | 读取 `.claude/context/coding-rules.md` + `CLAUDE.md` | 至少提供其中一份，并写清楚规范 | architect 会退回到通用规则 |

### 一个项目至少要准备什么

可以把 `preflight` 的结果分为两个级别来理解：

**❌ 错误（必须修复）**
- `playwright.config.ts` 存在 —— 否则 harness 无法运行
- `scripts/*.sh` 已复制且具备可执行权限 —— 否则 runner / typecheck / lint 都会失败

**⚠️ 警告（强烈推荐）**
- `playwright.test-only.config.ts` —— 没有的话，runner 每次迭代都要执行完整的 `globalSetup`，速度会慢一个数量级
- fixtures 文件 —— 没有的话，生成代码的风格会与现有测试不一致
- 角色枚举（`utils/constants.ts` ��类似文件）—— 没有的话，每次都要手动告诉 analyst role 是什么
- Page Object 目录 —— 没有的话，新方法可能会被放到奇怪的位置
- `CLAUDE.md` —— 没有的话，architect 缺乏项目上下文，准确率会明显下降
- `.claude/context/coding-rules.md` —— 没有的话，architect 会退回到通用 Playwright 规则，导致组件库特定的等待 / selector 写法不准确
- MCP Playwright server —— 没有的话，architect 只能猜 selector，runner 会反复卡在 selector 错误上

### 如果我的项目里完全没有这些怎么办？

可以分两步处理：

1. **第一次运行** —— 先修复 ❌ 项，再触发一次。让 architect 创建初始的 fixtures、role 枚举和 Page Object 雏形。
   这些生成结果会成为后续测试的“种子参考物”。
2. **后续运行** —— 到这时 `preflight` 应该已经全绿。随着继续生成新测试，agent 会有“邻居”可以学习，整体风格会统一很多。

---

## 目标项目需要具备什么

必须具备：

- 一套可运行的 Playwright 配置（`@playwright/test` + 一个 config 文件）
- 一个 `playwright.test-only.config.ts`，能够按测试名运行单条测试，且不执行全局 setup/teardown —— `scripts/test-quick.sh` 依赖它

强烈推荐：

- 在项目根目录放置一份 `CLAUDE.md`，说明你的编码约定
- 一份 `.claude/context/coding-rules.md`（可以从 harness 提供的模板开始 —— 见 [`.claude/context/coding-rules.md`](.claude/context/coding-rules.md)）
- 将 Page Object 放在可被 glob 检索到的位置（如 `pages/**`、`tests/pageObjects/**` 等）
- 使用 Playwright fixtures 注入你的 Page Object，这样生成的测试可以使用解构语法：
  `async ({ pageA, pageB }) => { … }`

可选但非常有帮助：

- 在 Claude Code 会话中挂载一个 MCP Playwright server。architect 会在编写 selector 之前，先到真实 UI 上进行验证。安装方式见
  [Anthropic MCP 文档](https://modelcontextprotocol.io)。

---

## IDE 兼容性

这套 harness **专为 Claude Code 设计**，依赖三项 Claude Code 特有能力：sub-agent 编排、
MCP Playwright 工具，以及通过 `Agent` 工具在阶段之间进行路由。

| IDE | 状态 | 说明 |
|---|---|---|
| Claude Code | ✅ 原生支持 | 支持完整流水线、自动失败迭代、MCP selector 验证 |
| Cursor | ⚠️ 可改造 | Cursor 2.4+（2026年1月 GA）通过 `.cursor/agents/*.md` 实现真正的 sub-agent 隔离；自动失败回流无原生支持 |
| GitHub Copilot | ⚠️ 可改造 | 已支持 MCP（2025年7月 GA）和 agent mode，但 harness 的 artifact 流水线架构需完整重写适配 |

### 改造到 Cursor

截至 Cursor 2.4（2026年1月 GA），Cursor 通过 `.cursor/agents/*.md` 文件提供了真正的
sub-agent 支持——每个 sub-agent 运行在**独立的 context window** 中，这才是本 harness 的正确迁移目标。

> **重要**：不要用 `.cursor/rules/*.mdc` 来定义 agent——那是注入到共享 context 的 prompt 模板，
> 而非隔离的 sub-agent。

大致迁移路径：

1. 将每个流水线阶段定义为 `.cursor/agents/*.md` 文件，使用 YAML frontmatter（`name`、
   `description`、`model`、`readonly`、`is_background`）加 prompt 正文。
   每个 sub-agent 有独立的 context window，只接收 orchestrator 显式传入的内容，看不到完整对话历史。
2. MCP Playwright 配置推荐放在**项目级** `.cursor/mcp.json`（全局 `~/.cursor/mcp.json`
   有已知可靠性问题，可能被静默忽略）。
3. orchestrator 可通过 LLM 驱动的意图匹配自动委派给 sub-agent，无需手动触发委派本身。
   `/tmp/tc_*.md` artifact 协议物理上可行，但必须在每个 agent 的 prompt 里明确指示写入和读取正确的路径。
4. **自动失败回流无原生支持。** 如果 runner 失败需要回到 architect，这必须是人工决定——
   没有内置机制让失败的 sub-agent 自动重触发更早的阶段。

与 Claude Code 相比失去的：确定性流水线路由、自动失败迭代，以及可靠的 per-stage 模型切换
（Cursor 2.4 有已知 bug：sub-agent 会继承父模型而非使用各自指定的模型）。

### 改造到 Copilot

截至 2026 年，GitHub Copilot 支持通过 `.github/agents/*.agent.md` 文件定义具名 agent
（VS Code 和 Visual Studio 2026+ 支持），支持 MCP（含 Playwright MCP），以及共享文件系统访问。
技术上可以迁移，但 harness 的自动编排模式原生不支持。

大致迁移路径：

1. 将每个流水线阶段定义为 `.github/agents/*.agent.md` 文件，使用 YAML frontmatter（`name`、
   `description`、`model`、`tools`、`mcp-servers`）加 prompt 正文。
2. 配置 MCP Playwright。`/tmp/tc_*.md` artifact 协议物理上可行——共享文件系统允许 agent 读写
   文件——但必须在每个 agent 的 prompt 里明确指示它写入正确的 artifact 路径。
3. 用 `handoffs` frontmatter 属性实现阶段跳转。注意 handoff **需要用户在 UI 点击按钮触发**，
   orchestrator 无法自主调度下一个 agent。
4. 失败回流（如 runner 失败后回到 architect）不是自动的，需要人工判断并手动重触发对应阶段。

与 Claude Code 相比失去的：自动阶段路由、自动失败迭代、保证的阶段间 context 隔离、per-stage 模型切换。

---

## 自定义

- **模型策略** —— 修改 `.claude/agents/add-test.md` 顶部的表格，调整每个阶段使用 Sonnet 还是 Haiku。这是质量与成本之间的权衡。
- **迭代上限** —— `test-runner` 默认最多迭代 5 次。可在 `add-test.md` 的 Step 4 中修改。
- **代码风格** —— agent 会读取目标项目的 `.claude/context/coding-rules.md`。你可以在那里（或你项目的 `CLAUDE.md` 中）写规则，用来教会 harness 你的约定。
- **目录结构** —— architect 会通过 glob 自动发现 `tests/**`、`pages/**`、`e2e/**` 等目录，无需修改任何硬编码路径。

---

## 已知限制

- **仅支持 Linux / macOS** —— artifacts 使用 `/tmp/`。Windows 用户需要自行修改各 agent 中的路径。
- **仅支持 TypeScript Playwright** —— 默认产物是 `*.spec.ts`、`.ts` Page Object 和 `expect()` 断言。JavaScript 项目也能使用，但生成结果仍然是 TS 语法。
- **Selector 验证依赖 MCP** —— 没有 MCP Playwright server 时，architect 只能从现有代码中推断 selector，准确率会明显下降。

---

## 仓库文件

```text
.claude/agents/              6 个 agent（编排者 + 5 个流水线阶段）
.claude/skills/              skill 模板（可复用操作模板——业务流程或技术模式）
.claude/context/coding-rules.md         coding-rules 参考模板（供目标项目复制和改造）
.claude/context/project-facts.md        （由 summarizer 运行时写入）团队共享的项目级事实
scripts/preflight.sh         初次安装后运行一次，检查项目是否满足 harness 依赖
scripts/test-quick.sh        runner 调用：运行单条测试，不执行全局 setup
scripts/typecheck.sh         coder 调用：`tsc --noEmit` gate
scripts/lint-patterns.sh     coder 调用：禁用模式扫描
scripts/cleanup-artifacts.sh 会话结束后清理 /tmp/tc_*.md
CLAUDE.md                    修改 *harness 本身* 时给 Claude 看的说明
README.md                    English README
README.zh-CN.md              简体中文说明
```
