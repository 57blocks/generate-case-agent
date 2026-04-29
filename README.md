# Playwright Test Harness

> 一张测试用例截图 + 一句关键词，自动生成可运行的 Playwright 测试。

一套基于 Claude Code 的 agent harness。把它装到你的 Playwright 项目里，丢一张
CSV / 表格 / 文档形式的测试用例截图（或者一段自然语言描述），它会自动完成
**需求拆解 → 架构设计 → MCP 验证 → 代码生成 → 自动调试 → 知识沉淀** 全流程，
最终在你仓库里产出一条通过的测试。

---

## 快速开始

```bash
# 1. 在你的 Playwright 项目根目录下，把 harness 拷进来
git clone <this-repo> /tmp/playwright-test-harness
cp -r /tmp/playwright-test-harness/.claude/agents .claude/
cp -r /tmp/playwright-test-harness/.claude/skills .claude/
cp -r /tmp/playwright-test-harness/scripts .
chmod +x scripts/*.sh

# 2. 跑 preflight 检查项目是否具备 harness 需要的基础设施
bash scripts/preflight.sh
```

preflight 会扫描你的项目，逐项告诉你：哪些必备东西已有、哪些缺失、哪些虽然不
是必需但缺了会降低生成质量。**先把 ❌ 错误项修掉、再看 ⚠️ 警告项要不要补**。
具体每项缺失会影响什么、怎么补，往下看
[「占位符与项目契约」](#占位符与项目契约-agent-从你项目的哪里取数)。

```bash
# 3. preflight 通过后，在 Claude Code 会话里触发 harness
#    丢一张测试用例截图，加一句关键词，例如：
#       增加 SA-001 用例
#       add test for TC-050
#       更新 TC-050 用例
```

编排者 agent 会自动把流水线跑起来。失败时会自己迭代修复，最多 5 次。

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
                                              + CLAUDE.md 里沉淀下来的经验
```

---

## 为什么做这个

手写 Playwright 测试是个重复劳动：解析用例 → 找或写 Page Object → 在真实
UI 上验证 selector → 写 spec → 调试不可避免的 timing 问题。这套 harness 把
每一步交给一个专职 agent，再用一个轻量的文件协议把它们串起来，于是你可以：

- 丢一张截图，拿到一条能跑的测试。
- agent 会**自己迭代调试**失败 —— selector 漂移、spinner 等待、虚拟滚动的怪
  脾气。
- 这次跑出来学到的经验会被自动写回你项目的 `CLAUDE.md`，下一条用例就能受益。

---

## 架构

6 个 agent：1 个编排者 + 5 个流水线阶段。每个流水线阶段把产物写到
`/tmp/tc_{case_id}_{stage}.md`；下一个阶段**只读这个文件**，不读上一阶段的
聊天输出。这样每个 agent 的上下文都很干净。

```
[1] test-analyst     →  /tmp/tc_{id}_requirement.md
[2] test-architect   →  /tmp/tc_{id}_design.md         （用 MCP Playwright 验证 selector）
[3] test-coder       →  写 spec + Page Object 文件
[4] test-runner      →  /tmp/tc_{id}_run_report.md     （失败时迭代；可回到第 1 / 2 阶段）
[5] test-summarizer  →  把经验更新回你仓库的 CLAUDE.md / agent / memory
```

| Agent             | 职责                                                       | 模型   |
|-------------------|-----------------------------------------------------------|--------|
| `add-test`        | 编排者 —— 在阶段间路由、把守 artifact                     | sonnet |
| `test-analyst`    | 读截图、必要时澄清、把用例拆成原子单元                    | sonnet |
| `test-architect`  | 选 Page Object，用 MCP 验证新 selector                    | sonnet |
| `test-coder`      | 只写代码；不开浏览器、不发明 selector                     | haiku  |
| `test-runner`     | 跑测试、按 stack trace 分类失败、自己修或上抛             | haiku  |
| `test-summarizer` | 跑通后审计并更新项目知识库                                | sonnet |

---

## 用法

### 触发短语

编排者（`add-test` agent）能识别中文 / 英文的多种自然触发：

| 短语                              | 动作                          |
|-----------------------------------|-------------------------------|
| 增加 SA-001 用例                  | 新增一条测试，ID = SA-001     |
| add test for TC-050               | 新增一条测试，ID = TC-050     |
| 更新 TC-050 用例                  | 更新一条已有测试              |
| update test TC-050                | 更新一条已有测试              |
| 在 supioadmin 文件夹下增加用例    | 新增到指定目录                |
| add a new test file               | 新增（暂时没具体 case ID）    |

把测试用例的截图（CSV / 表格 / 文档都行，能看清就行）丢进对话，加一句触发
短语。编排者会一路跑下去。如果截图没说清楚 role / environment / 测试数据，
analyst 会主动问你。

### 你会看到什么

- analyst 的**澄清问题**（仅在必要时）
- architect 的**破坏性变更警告**（仅在新方法和已有代码冲突时）
- runner 的**迭代信息**（"Iteration 2: 修 selector 问题…"）
- 最后一份**会话总结** —— 实现了什么、复用了什么、向 `CLAUDE.md` 沉淀了什么

### 自动迭代

测试失败时，`test-runner` 读 stack trace，给失败分类，然后：

- 自己改 selector / timing / 断言，或
- 上抛给 `test-architect`（设计问题）或 `test-analyst`（需求问题）

最多迭代 5 次，超过就停下来汇报。

---

## 项目知识应该放哪里

harness 把项目知识切成 4 类，每类有自己的归属。**不要把它们混在一起。**

| 类别 | 例子 | 应该放在哪 |
|---|---|---|
| **A. 通用 Playwright / MCP 规则** | "不要用 `isVisible()` 门控点击"；MCP 验证流程 | harness 的 `docs/coding-rules.md` 模板（用户复制到自己项目） |
| **B. 项目专属编码风格** | "Files tab 断言不带扩展名"；"等 `.ant-spin-spinning` 消失" | **目标项目自己的** `CLAUDE.md` 和/或 `docs/coding-rules.md` |
| **C. 业务流程的代码模板** | "怎么登录 + 创建记录 + 验证"；"怎么上传文件 + 等 AI 处理 + 发布" | **目标项目自己的** `.claude/skills/*.md`（harness 只给一个 `example-flow.md` 作参考）|
| **D. 真实可跑的代码示例** | 一条通过的 spec + 它的 Page Object | 你项目里现有的 `tests/` 和 `pages/` —— architect 会自己 grep 并参考 |

> harness 仓库只携带 **A**（模板）和 **C**（一个示例）。**B** 完全是你项目自己
> 的事；**D** 直接读你项目代码就好，不需要单独搬出来。

### Skill 的定位（C 类）

`example-flow.md` 是一份**模板**，演示了一个 skill 该长什么样：当某类业务流
程被多条测试反复使用（比如 "登录 → 创建 → 校验"），把这个流程的**真实代码片
段、命名约定、参数解析**写成一个 skill 文件。`test-architect` 在设计新测试
前，会扫描目标项目的 `.claude/skills/`，命中关键词时优先使用 skill 里的代
码模板，而不是重新发明。

具体怎么写一个 skill —— 直接看 [`.claude/skills/example-flow.md`](.claude/skills/example-flow.md)。

---

## 占位符与项目契约（agent 从你项目的哪里取数）

打开 `.claude/agents/test-coder.md`，你会看到大量类似 `<project-fixtures-import>`、
`{ROLE}`、`{fixture1}` 这样的占位符。**这些不是你手动替换的** —— 它们是给 LLM
agent 看的模板。agent 在执行时会自己去你项目里扫描对应的"参考物"，然后填空。

但前提是：**你项目里得真的有那些参考物**。这就是 preflight 在检查的事。下面
这张表把每个占位符 / 配置项的来源讲清楚，方便你对照修补：

| 占位符 / 配置                           | agent 怎么填                                          | 你项目要准备                                  | 缺了的后果                              |
|----------------------------------------|------------------------------------------------------|---------------------------------------------|----------------------------------------|
| `<project-fixtures-import>`            | 读你项目现有 spec 的 import 路径                     | 至少一个能跑的 `*.spec.ts`                  | coder 不知道怎么 import，会瞎猜路径    |
| `<project-constants-import>`           | 同上                                                 | 同上                                        | 同上                                  |
| `RoleName.{ROLE}`                      | 读 `utils/constants.ts`（或同类）里的 enum           | 项目里有角色枚举文件                        | analyst 会反复问你 role 该填什么       |
| `{fixture1}, {fixture2}`               | 读 `fixtures.ts` 里 export 的 fixture 名             | fixtures 文件存在 + Page Object 通过它注入  | 生成的测试可能直接 `new XxxPage()`     |
| `{module}` (新 spec 文件存放位置)      | glob 你项目 `tests/**` 现有目录结构                  | 至少有一两个已组织好的测试目录              | 新文件可能放到奇怪位置                |
| `{snake_feature_name}`                 | 从用例描述自动生成                                   | 无                                         | -                                     |
| `{CASE_ID}`、`{CASE_NAME}`             | 从你输入的截图 / 文字提取                            | 无                                         | -                                     |
| `<target-app-url>` (architect MCP 用) | 从 ROLE_CONFIG / 环境变量 / 你提供的 URL 提取        | 项目里得有 URL 配置或你直接给 architect     | architect 没法在真实 UI 上验证 selector|
| `MENU.{X}`、`gotoMenu(...)` 这类导航  | 读你 BasePage / 共享 helper 里有什么导航方法         | 推荐有 BasePage + 命名规范的导航 helper     | 生成的测试可能用 `page.goto(url)` 硬跳 |
| 项目编码风格（断言写法、loading 等待） | 读 `docs/coding-rules.md` + `CLAUDE.md`              | 这两份文档至少有一份且写清楚                | architect 用通用默认，可能不符合你项目 |

### 一个项目最少要准备什么

按 preflight 的结果分级看：

**❌ 错误（必须修）**
- `playwright.config.ts` 存在 → 否则 harness 跑不起来
- `scripts/*.sh` 都拷进来且可执行 → 否则 runner / typecheck / lint 全挂

**⚠️ 警告（强烈推荐）**
- `playwright.test-only.config.ts` → 没有的话 runner 每次迭代都跑全量 globalSetup，慢一个数量级
- fixtures 文件 → 没有的话生成的代码风格会和你项目其他测试不一致
- 角色枚举（`utils/constants.ts` 或同类）→ 没有的话每次都要手动告诉 analyst role 是啥
- Page Object 目录 → 没有的话新方法可能放到奇怪地方
- `CLAUDE.md` → 没有的话 architect 缺乏项目上下文，准确率下降明显
- `docs/coding-rules.md` → 没有的话 architect 用通用 Playwright 规则，组件库特定的等待 / 选择器写法都不对
- MCP Playwright server → 没有的话 architect 只能猜 selector，runner 会因为 selector 错误反复迭代

### 我项目里完全没有这些怎么办

可以分两步：

1. **第一次跑** —— 先把 ❌ 修掉就触发一次。让 architect 自己创建 fixtures、
   role 枚举、Page Object 雏形。生成出来的代码就是你后续测试的"种子参考物"。
2. **后续跑** —— 这时候 preflight 应该全绿。再生成新测试，agent 就有"邻居"
   可以学样，风格会一致很多。

---

## 目标项目需要具备什么

必须：

- 一个能跑的 Playwright 配置（`@playwright/test` + 一个 config 文件）
- 一个 `playwright.test-only.config.ts`，能按测试名跑单条测试、不跑全局
  setup/teardown —— `scripts/test-quick.sh` 依赖它

强烈推荐：

- 项目根目录有一份 `CLAUDE.md`，描述你的代码约定
- 一份 `docs/coding-rules.md`（用 harness 里那份做起点 —— 见
  [`docs/coding-rules.md`](docs/coding-rules.md)）
- Page Object 放在能被 glob 找到的位置（`pages/**`、`tests/pageObjects/**`
  之类）
- Playwright fixtures 注入你的 Page Object，让生成的测试能用解构语法：
  `async ({ pageA, pageB }) => { … }`

可选但很有用：

- 在 Claude Code 会话里挂一个 MCP Playwright server —— architect 会用它在
  写 selector 之前去真实 UI 上验证一遍。装法见
  [Anthropic MCP 文档](https://modelcontextprotocol.io)。

---

## IDE 兼容性

这套 harness 是**为 Claude Code 设计的**，依赖三个 Claude Code 专有特性：
sub-agent 编排、MCP Playwright 工具、用 `Agent` 工具在阶段间路由。

| IDE             | 状态          | 说明                                                                       |
|-----------------|---------------|----------------------------------------------------------------------------|
| Claude Code     | ✅ 原生支持   | 完整流水线、自动失败迭代、MCP 验证 selector                                |
| Cursor          | ⚠️ 可改造    | 把每个 `.md` agent 改写成 `.cursor/rules/*.mdc`；手动触发各阶段；失去自动编排 |
| GitHub Copilot  | ❌ 不可行     | 没有 sub-agent，没有 MCP，准确率会大幅下降                                 |

### 改造到 Cursor

Cursor 的 Composer Agent 是 Claude Code 在其他 IDE 里最近的对应物，但
**不支持 sub-agent**。粗略改造方案：

1. 把 `.claude/agents/*.md` 重写成 `.cursor/rules/*.mdc`。去掉 frontmatter，
   保留 prompt 主体。
2. 在 `~/.cursor/mcp.json` 里配 MCP Playwright server，让 architect 的
   selector 验证还能用。
3. 在 Composer 里手动触发：`@analyst` → `@architect` → `@coder` → `@runner`。
   失去**自动失败迭代**，需要你自己重新触发 `@runner`（设计问题就触发
   `@architect`）。
4. 保留 `/tmp/tc_*.md` artifact 协议 —— 任何能访问文件系统的 IDE 都能用。

会失去：自动阶段路由、自动失败迭代、按阶段切换模型（Claude Code 的
`model: haiku` / `model: sonnet`）。

### 改造到 Copilot

不推荐。Copilot Chat 没有 sub-agent 概念，Copilot Workspace 不支持 MCP。
这套流水线的准确率严重依赖 **MCP 实时 selector 验证** —— 没了它，architect
只能从 class 名瞎猜，runner 会卡在那种"没有真正 fix 方案"的 selector 错误
循环里。

如果一定要做：把 5 个阶段的 prompt 合并成一个超长 prompt 喂给 Copilot
Agent，并接受准确率明显下降。

---

## 自定义

- **模型策略** —— 改 `.claude/agents/add-test.md` 顶部那张表，调整每个阶
  段用 Sonnet 还是 Haiku。成本 vs 质量的权衡。
- **迭代上限** —— `test-runner` 默认最多迭代 5 次。改 `add-test.md` 的 Step
  4。
- **代码风格** —— agent 读目标项目的 `docs/coding-rules.md`。在那里（或者
  你项目的 `CLAUDE.md` 里）写规则，就能教会 harness 你的约定。
- **目录结构** —— architect 会自己 glob 发现 `tests/**`、`pages/**`、
  `e2e/**` 等。没有任何硬编码路径要改。

---

## 已知限制

- **仅支持 Linux / macOS** —— artifact 用 `/tmp/`。Windows 用户得自己改每
  个 agent 里的路径。
- **只支持 TypeScript Playwright** —— agent 默认产物是 `*.spec.ts` + `.ts`
  Page Object + `expect()` 断言。JavaScript 项目能用，但生成的是 TS 语法。
- **Selector 验证依赖 MCP** —— 没有 MCP Playwright server 时，architect 只
  能从已有代码里猜 selector，准确率会明显下降。

---

## 仓库文件

```
.claude/agents/        6 个 agent（编排者 + 5 个流水线阶段）
.claude/skills/        skill 模板（业务流程代码示例）
docs/coding-rules.md   coding-rules 参考模板（给目标项目复制改造）
scripts/preflight.sh   首次安装后跑一次，检查项目是否满足 harness 的依赖
scripts/test-quick.sh  runner 调用：跑单条测试、不跑全局 setup
scripts/typecheck.sh   coder 调用：tsc --noEmit gate
scripts/lint-patterns.sh coder 调用：禁用模式扫描
scripts/cleanup-artifacts.sh 一次会话结束后清理 /tmp/tc_*.md
CLAUDE.md              修改 *harness 本身* 时给 Claude 看的指令
README.md              本文件
```
