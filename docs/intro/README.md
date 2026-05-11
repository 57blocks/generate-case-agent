# Intro Slides

分享会用的 Slidev 演示文稿，介绍 Playwright Test Harness 的设计思路和使用方法。

## 文件结构

```
docs/intro/
├── slides.md          # 演示文稿源文件（直接编辑这个）
├── assets/
│   └── agent-harness.jpeg
└── README.md          # 本文件
```

## 安装 Slidev

在 `docs/intro/` 目录下初始化并安装依赖：

```bash
cd docs/intro
npm init -y
npm install @slidev/cli @slidev/theme-seriph
```

> 只需要安装一次。`node_modules/` 已加入 `.gitignore`，不会提交到仓库。

## 启动演示

```bash
cd docs/intro
npx slidev slides.md --open
```

浏览器会自动打开 http://localhost:3030。

| 地址 | 用途 |
|---|---|
| http://localhost:3030/ | 演示模式 |
| http://localhost:3030/presenter/ | 演讲者视图（推荐，有备注和下一页预览） |
| http://localhost:3030/overview/ | 总览所有页，方便跳转 |

## 热更新

直接编辑 `slides.md`，**保存即生效**，浏览器自动刷新，不需要重启。

## 导出

```bash
# 导出为 PDF
npx slidev export slides.md

# 导出为静态网站（可部署分享）
npx slidev build slides.md
```

## 常用快捷键

| 按键 | 功能 |
|---|---|
| `→` / `Space` | 下一页 |
| `←` | 上一页 |
| `o` | 总览所有页 |
| `f` | 全屏 |
| `d` | 深色 / 浅色切换 |

## 注意事项

**不要让 IDE 的 Markdown 格式化插件自动格式化 `slides.md`**。

Slidev 用 `---` 分隔每一页，每页的 `layout:` 配置必须写在这样的 frontmatter 块里：

```
---
layout: section
---

# 标题
```

某些 Markdown linter 会把它改成 `## layout: section`，导致 layout 失效。如果出现这种情况，在项目根目录运行以下命令一键修复：

```bash
perl -0777 -i -pe '
  s/---\n\n## layout: section\n\n# /---\nlayout: section\n---\n\n# /g;
  s/---\n\n## layout: center\n\n## /---\nlayout: center\n---\n\n## /g;
  s/---\n\n## layout: end\n\n# /---\nlayout: end\n---\n\n# /g;
' docs/intro/slides.md
```
