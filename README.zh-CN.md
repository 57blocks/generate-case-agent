# Playwright 测试 Harness

> One test case screenshot + one short keyword, automatically generates a runnable Playwright test.

这是一套基于 Claude Code 的 agent harness。把它安装到你的 Playwright 项目中，提供一张
CSV / 表格 / 文档形式的测试用例截图（或者一段自然语言描述），它会自动完成
**需求拆解 → 架构设计 → MCP 验证 → 代码生成 → 自动调试 → 知识沉淀** 的完整流程，
最终在你的仓库中产出一条通过的测试。

---

## 快速开始

```bash
# 1. 在你的 Playwright 项目根目录下，把 harness 拷进来
git clone <this-repo> /tmp/playwright-test-harness
cp -r /tmp/playwright-test-harness/.claude/agents .claude/
cp -r /tmp/playwright-test-harness/.claude/skills .claude/
cp -r /tmp/playwright-test-harness/scripts .
chmod +x scripts/*.sh

# 2. 运行 preflight 检查，确认项目是否具备 harness 需要的基础设施
bash scripts/preflight.sh
```

preflight 会扫描你的项目，并逐项告诉你：哪些必备项已经具备、哪些缺失、哪些虽然不是必需但缺少后会降低生成质量。**先修复 ❌ 错误项，再决定是否补齐 ⚠️ 警告项**。
关于每一项缺失会带来什么影响、以及如何补齐，请继续阅读
[“占位符与项目契约”](#占位符与项目契约agent-从你项目的哪里取数)。

```bash
# 3. preflight 通过后，在 Claude Code 会话里触发 harness
#    丢一张测试用例截图，再加一句关键词，例如：
#       增加 SA-001 用例
#       add test for TC-050
#       更新 TC-050 用例
```

编排者 agent 会自动运行整条流水线。失败时会自行迭代修复，最多 5 次。

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
                                              你仓库里的一条通过测试
                                              + CLAUDE.md 中沉淀下来的经验
```

---

## 为什么做这个

手写 Playwright 测试是一种重复劳动：解析用例 → 找到或编写 Page Object → 在真实
UI 上验证 selector → 编写 spec → 调试不可避免的 timing 问题。这套 harness 将
每一步交给一个专职 agent，再用一个轻量的文件协议把它们串联起来，于是你可以：

- 丢一张截图，就拿到一条能运行的测试。
- agent 会**自行迭代调试**失败——例如 selector 漂移、spinner 等待、虚拟滚动的怪脾气。
- 本次运行学到的经验会被自动写回你项目的 `CLAUDE.md`，让下一条用例也能受益。

---

## 架构

共有 6 个 agent：1 个编排者 + 5 个流水线阶段。每个流水线阶段会把产物写到
`/tmp/tc_{case_id}_{stage}.md`；下一个阶段**只读取这个文件**，而不读取上一阶段的
聊天输出。这样每个 agent 的上下文都非常干净。

```
[1] test-analyst     →  /tmp/tc_{id}_requirement.md
[2] test-architect   →  /tmp/tc_{id}_design.md         （使用 MCP Playwright 验证 selector）
[3] test-coder       →  编写 spec + Page Object 文件
[4] test-runner      →  /tmp/tc_{id}_run_report.md     （失败时迭代；可回退到第 1 / 2 阶段）
[5] test-summarizer  →  将经验更新回你仓库的 CLAUDE.md / agent / memory
```

| Agent             | 职责                                                       | 模型   |
|-------------------|-----------------------------------------------------------|--------|
| `add-test`        | 编排者——在各阶段之间路由，并守护 artifact                 | sonnet |
| `test-analyst`    | 阅读截图、必要时澄清、将用例拆解为原子单元                | sonnet |
| `test-architect`  | 选择 Page Object，用 MCP 验证新 selector                  | sonnet |
| `test-coder`      | 只写代码；不开浏览器、不发明 selector                     | haiku  |
| `test-runner`     | 运行测试、按 stack trace 分类失败、自己修复或上抛         | haiku  |
| `test-summarizer` | 运行通过后审计并更新项目知识库                            | sonnet |

---

## 用法

### 触发短语

编排者（`add-test` agent）能识别中文 / 英文的多种自然触发方式：

| 短语                              | 动作                          |
|-----------------------------------|-------------------------------|
| 增加 SA-001 用例                  | 新增一条测试，ID = SA-001     |
| add test for TC-050               | 新增一条测试，ID = TC-050     |
| 更新 TC-050 用例                  | 更新一条已有测试              |
| update test TC-050                | 更新一条已有测试              |
| 在 supioadmin 文件夹下增加用例    | 新增到指定目录                |
| add a new test file               | 新增（暂时没有具体 case ID）  |

将测试用例截图（CSV / 表格 / 文档都可以，只要内容清晰）丢进对话，再附上一句触发
短语。编排者会沿着流水线一路执行下去。如果截图没有说明清楚 role / environment / 测试数据，
analyst 会主动向你提问。

### 你会看到什么

- analyst 的**澄清问题**（仅在必要时）
- architect 的**破坏性变更警告**（仅当新方法与已有代码冲突时）
- runner 的**迭代信息**（例如："Iteration 2: 修复 selector 问题…"）
- 最后一份**会话总结**——实现了什么、复用了什么、向 `CLAUDE.md` 沉淀了什么

### 自动迭代

测试失败时，`test-runner` 会读取 stack trace，对失败进行分类，然后：

- 自己修复 selector / timing / 断言，或
- 上抛给 `test-architect`（设计问题）或 `test-analyst`（需求问题）

最多迭代 5 次，超过后会停止并汇报。

---

## 项目知识应该放在哪里

harness 将项目知识拆分为 4 类，每一类都有自己的归属。**不要把它们混在一起。**

| 类别 | 例子 | 应该放在哪里 |
|---|---|---|
| **A. 通用 Playwright / MCP 规则** | “不要用 `isVisible()` 来门控点击”；MCP 验证流程 | harness 的 `docs/coding-rules.md` 模板（由用户复制到自己的项目中） |
| **B. 项目专属编码风格** | “Files tab 断言不带扩展名”；“等待 `.ant-spin-spinning` 消失” | **目标项目自己的** `CLAUDE.md` 和/或 `docs/coding-rules.md` |
| **C. 业务流程代码模板** | “如何登录 + 创建记录 + 验证”；“如何上传文件 + 等待 AI 处理 + 发布” | **目标项目自己的** `.claude/skills/*.md`（harness 只提供一个示例） |
| **D. 真实可运行的代码示例** | 一条通过的 spec + 它的 Page Object | 你项目中现有的 `tests/` 和 `pages/` —— architect 会自己 grep 并参考 |

> harness 仓库只携带 **A**（模板）和 **C**（一个示例）。**B** 完全属于你的项目；
> **D** 直接读取你项目代码即可，不需要额外迁移出来。

### Skill 的定位（C 类）

`example-flow.md` 是一份**模板**，用来演示一个 skill 应该长什么样：当某类业务流
程被多条测试重复使用（例如“登录 → 创建 → 校验”），就把这段流程中的**真实代码片段、
命名约定、参数解析**写成一个 skill 文件。`test-architect` 在设计新测试之前，会扫描目标
项目的 `.claude/skills/`，命中关键词时优先使用 skill 中的代码模板，而不是重新发明。

如何编写 skill —— 直接查看 [`.claude/skills/example-flow.md`](.claude/skills/example-flow.md)。

---

## 占位符与项目契约（agent 从你项目的哪里取数）

打开 `.claude/agents/test-coder.md`，你会看到大量类似 `<project-fixtures-import>`、
`{ROLE}`、`{fixture1}` 这样的占位符。**这些不是让你手动替换的**——它们是给 LLM
agent 看的模板。agent 在执行时会自己去你项目中扫描对应的“参考物”，然后自动填空。

但前提是：**你的项目里必须真的存在这些参考物**。这正是 preflight 在检查的内容。
下面这张表解释了每个占位符 / 配置项的来源，方便你逐项补齐：

| 占位符 / 配置                           | agent 如何填充                                      | 你的项目需要准备什么                            | 缺失后的后果 |
|----------------------------------------|---------------------------------------------------|-----------------------------------------------|-------------|
| `<project-fixtures-import>`            | 读取你项目现有 spec 的 import 路径                | 至少一个能运行的 `*.spec.ts`                  | coder 不知道该如何 import |
| `<project-constants-import>`           | 同上                                              | 同上                                          | 同上 |
| `RoleName.{ROLE}`                      | 读取 `utils/constants.ts`（或类似文件）中的 enum  | 项目里有角色枚举文件                          | analyst 会反复问你 role 应该填什么 |
| `{fixture1}, {fixture2}`               | 读取 `fixtures.ts` 中导出的 fixture 名称          | fixtures 文件存在，且 Page Object 通过它注入   | 生成的测试可能直接 `new XxxPage(...)` |
| `{module}`（新 spec 文件放置位置）     | glob 你项目 `tests/**` 现有目录结构               | 至少有一两个已经组织好的测试目录              | 新文件可能被放到不合理的位置 |
| `{snake_feature_name}`                 | 从用例描述自动生成                                | 无                                            | - |
| `{CASE_ID}`、`{CASE_NAME}`             | 从你输入的截图 / 文字中提取                       | 无                                            | - |
| `<target-app-url>`（architect MCP 用） | 从 ROLE_CONFIG / 环境变量 / 你提供的 URL 提取     | 项目里需要有 URL 配置，或你直接提供给 architect | architect 无法在真实 UI 上验证 selector |
| `MENU.{X}`、`gotoMenu(...)` 这类导航   | 读取你 BasePage / 共享 helper 中已有的导航方法    | 推荐有 BasePage + 命名规范的导航 helper       | 生成的测试可能使用不一致的导航方式 |
| 项目编码风格（断言写法、loading 等待） | 读取 `docs/coding-rules.md` + `CLAUDE.md`         | 至少有一份文档，并写清楚                      | architect 会退回使用通用规则 |

### 一个项目至少要准备什么

按 preflight 的结果分级来看：

**❌ 错误（必须修复）**
- `playwright.config.ts` 存在 —— 否则 harness 无法运行
- `scripts/*.sh` 都已拷入且可执行 —— 否则 runner / typecheck / lint 都会失败

**⚠️ 警告（强烈推荐）**
- `playwright.test-only.config.ts` —— 没有的话 runner 每次迭代都要运行完整 globalSetup，速度会慢一个数量级
- fixtures 文件 —— 没有的话生成的代码风格会和你项目其他测试不一致
- 角色枚举（`utils/constants.ts` 或类似）—— 没有的话每次都要手动告诉 analyst role 是什么
- Page Object 目录 —— 没有的话新方法可能会被放到奇怪的位置
- `CLAUDE.md` —— 没有的话 architect 缺少项目上下文，准确率会明显下降
- `docs/coding-rules.md` —— 没有的话 architect 会使用通用 Playwright 规则，组件库特定的等待 / selector 写法就不对
- MCP Playwright server —— 没有的话 architect 只能猜 selector，runner 会因为 selector 错误反复迭代

### 如果我的项目里完全没有这些怎么办

可以分两步来做：

1. **第一次运行** —— 先把 ❌ 项修好，然后先触发一次。让 architect 自己创建 fixtures、
   role 枚举、Page Object 雏形。生成出来的代码就是你后续测试的“���子参考物”。
2. **后续运行** —— 此时 preflight 应该已经全绿。再继续生成新测试时，agent 就有“邻居”
   可以参考，风格会统一很多。

---

## 目标项目需要具备什么

必须具备：

- 一个可运行的 Playwright 配置（`@playwright/test` + 一个 config 文件）
- 一个 `playwright.test-only.config.ts`，能够按测试名运行单条测试，且不运行全局
  setup/teardown —— `scripts/test-quick.sh` 依赖它

强烈推荐：

- 项目根目录有一份 `CLAUDE.md`，描述你的代码约定
- 一份 `docs/coding-rules.md`（可用 harness 中那份作为起点 —— 见
  [`docs/coding-rules.md`](docs/coding-rules.md)）
- 将 Page Object 放在能被 glob 找到的位置（如 `pages/**`、`tests/pageObjects/**` 等）
- Playwright fixtures 注入你的 Page Object，让生成的测试能够使用解构语法：
  `async ({ pageA, pageB }) => { … }`

可选但非常有用：

- 在 Claude Code 会话中挂一个 MCP Playwright server —— architect 会在编写 selector
  之前先去真实 UI 上验证一遍。安装方式见
  [Anthropic MCP 文档](https://modelcontextprotocol.io)。

---

## IDE 兼容性

这套 harness **专为 Claude Code 设计**，依赖三个 Claude Code 特有能力：
sub-agent 编排、MCP Playwright 工具、以及通过 `Agent` 工具在阶段之间路由。

| IDE             | 状态          | 说明 |
|-----------------|---------------|------|
| Claude Code     | ✅ 原生支持   | 完整流水线、自动失败迭代、MCP 验证 selector |
| Cursor          | ⚠️ 可改造    | 把每个 `.md` agent 改写成 `.cursor/rules/*.mdc`；手动触发各阶段；会失去自动编排 |
| GitHub Copilot  | ❌ 不可行     | 没有 sub-agent，没有 MCP，准确率会大幅下降 |

### 改造到 Cursor

Cursor 的 Composer Agent 是 Claude Code 在其他 IDE 中最接近的对应物，但
**不支持 sub-agent**。一个粗略的改造方案是：

1. 将 `.claude/agents/*.md` 重写为 `.cursor/rules/*.mdc`。去掉 frontmatter，
   保留 prompt 主体。
2. 在 `~/.cursor/mcp.json` 中配置 MCP Playwright server，让 architect 的
   selector 验证仍然可用。
3. 在 Composer 中手动触发：`@analyst` → `@architect` → `@coder` → `@runner`。
   这样会失去**自动失败迭代**，需要你自己重新触发 `@runner`（如果是设计问题，则改为触发
   `@architect`）。
4. 保留 `/tmp/tc_*.md` artifact 协议 —— 任何能访问文件系统的 IDE 都能使用。

会失去的能力包括：自动阶段路由、自动失败迭代、按阶段切换模型（Claude Code 中的
`model: haiku` / `model: sonnet`）。

### 改造到 Copilot

不推荐。Copilot Chat 没有 sub-agent 概念，Copilot Workspace 也不支持 MCP。
这套流水线的准确率严重依赖 **MCP 实时 selector 验证**——没有它，architect
只能从 class 名“猜” selector，runner 会卡在那种“没有真正 fix 方案”的 selector
错误循环中。

如果一定要尝试：把 5 个阶段的 prompt 合并成一个超长 prompt 喂给 Copilot
Agent，并接受准确率明显下降这一事实。

---

## 自定义

- **模型策略** —— 修改 `.claude/agents/add-test.md` 顶部那张表，调整每个阶段使用 Sonnet 还是 Haiku。这是成本与质量之间的权衡。
- **迭代上限** —— `test-runner` 默认最多迭代 5 次。修改 `add-test.md` 的 Step 4。
- **代码风格** —— agent 会读取目标项目的 `docs/coding-rules.md`。你可以在那里（或
  你项目的 `CLAUDE.md` 中）写规则，以教会 harness 你的约定。
- **目录结构** —— architect 会自己 glob 发现 `tests/**`、`pages/**`、
  `e2e/**` 等。无需修改任何硬编码路径。

---

## 已知限制

- **仅支持 Linux / macOS** —— artifact 使用 `/tmp/`。Windows 用户需要自己修改每个 agent 中的路径。
- **只支持 TypeScript Playwright** —— agent 默认生成 `*.spec.ts` + `.ts`
  Page Object + `expect()` 断言。JavaScript 项目也能用，但生成结果仍会是 TS 语法。
- **Selector 验证依赖 MCP** —— 没有 MCP Playwright server 时，architect 只能从已有代码中猜 selector，准确率会明显下降。

---

## 仓库文件

```
.claude/agents/        6 个 agent（编排者 + 5 个流水线阶段）
.claude/skills/        skill 模板（业务流程代码示例）
docs/coding-rules.md   coding-rules 参考模板（供目标项目复制和改造）
scripts/preflight.sh   初次安装后运行一次，检查项目是否满足 harness 依赖
scripts/test-quick.sh  runner 调用：运行单条测试，不跑全局 setup
scripts/typecheck.sh   coder 调用：`tsc --noEmit` gate
scripts/lint-patterns.sh coder 调用：禁用模式扫描
scripts/cleanup-artifacts.sh 会话结束后清理 /tmp/tc_*.md
CLAUDE.md              修改 *harness 本身* 时给 Claude 看的指令
README.md              本文件
```
