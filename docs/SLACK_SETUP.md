# Slack 通知设置指南

本文档介绍如何为 POC 测试设置 Slack 通知功能,当测试失败时自动通知团队。

## 功能特性

✅ **自动通知**: POC 测试完成后自动发送通知
✅ **详细统计**: 显示通过/失败/跳过/不稳定测试数量
✅ **失败告警**: 测试失败时高亮显示失败率和错误信息
✅ **CI 日志**: 快速访问 GitHub Actions 运行日志
✅ **高性能**: 直接解析 blob 报告,无需浏览器渲染
✅ **精确数据**: 统计数据直接来源于测试执行结果

## 设置步骤

### 1. 创建 Slack App

1. 访问 https://api.slack.com/apps
2. 点击 **"Create New App"**
3. 选择 **"From scratch"**
4. 输入 App 名称(例如: `Portal UI Test Bot`)
5. 选择要安装的 Workspace
6. 点击 **"Create App"**

### 2. 配置 OAuth 权限

1. 在左侧菜单中选择 **"OAuth & Permissions"**
2. 滚动到 **"Scopes"** 部分
3. 在 **"Bot Token Scopes"** 下添加以下权限:
   - `chat:write` - 发送消息到频道
   - `users:read` - 读取用户信息(可选,用于 @提醒)

4. 滚动到页面顶部,点击 **"Install to Workspace"**
5. 授权 App 访问 Workspace
6. 复制 **"Bot User OAuth Token"** (以 `xoxb-` 开头)

### 3. 获取 Channel ID

#### 方法 1: 从 Slack 客户端获取

1. 在 Slack 中打开要接收通知的频道
2. 点击频道名称打开详情
3. 在弹出窗口底部找到 **Channel ID** 并复制

#### 方法 2: 邀请 Bot 后查看

1. 在 Slack 频道中输入: `/invite @Portal UI Test Bot`
2. 在浏览器地址栏中查看 URL,格式类似:
   ```
   https://app.slack.com/client/T01234567/C01234567
   ```
   其中 `C01234567` 就是 Channel ID

### 4. 配置 GitHub Secrets

1. 访问你的 GitHub 仓库
2. 进入 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **"New repository secret"** 添加以下 secrets:

#### SLACK_BOT_TOKEN
- **Name**: `SLACK_BOT_TOKEN`
- **Value**: 粘贴从 Step 2 复制的 Bot Token(以 `xoxb-` 开头)

#### SLACK_CHANNEL_ID
- **Name**: `SLACK_CHANNEL_ID`
- **Value**: 粘贴从 Step 3 复制的 Channel ID(以 `C` 开头)

### 5. 邀请 Bot 到频道

在 Slack 频道中执行:
```
/invite @Portal UI Test Bot
```

## 使用方法

### 自动触发(已配置)

POC 测试每天自动运行时会自动发送 Slack 通知:
- 定时任务: 每天 UTC 04:30 (北京时间 12:30)
- 手动触发: GitHub Actions → Run workflow → 选择 "poc"

### 本地测试

你可以在本地测试 Slack 通知功能:

```bash
# 1. 确保 .env 文件包含 Slack 凭证
echo "SLACK_BOT_TOKEN=xoxb-your-token" >> .env
echo "SLACK_CHANNEL_ID=C01234567" >> .env

# 2. 运行 POC 测试生成 blob 报告
npx playwright test --project=poc --reporter=blob

# 3. 发送测试通知(使用 blob 报告目录)
npx ts-node utils/send-slack-notification.ts ./blob-report poc
```

## 通知示例

### ✅ 成功通知

```
✅ POC TESTS PASSED

Project: POC
Environment: RC Production
Total Tests: 10
Passed: ✅ 10
Failed: ❌ 0
Skipped: ⏭️ 0

🎉 All tests passed successfully!

[View CI Logs]
```

### ❌ 失败通知

```
❌ POC TESTS FAILED

Project: POC
Environment: RC Production
Total Tests: 10
Passed: ✅ 8
Failed: ❌ 2
Skipped: ⏭️ 0
Failure Rate: 20.0%

⚠️ Action Required: 2 test(s) failed. Please investigate to
determine if this indicates a product issue or test environment problem.

[View CI Logs]
```

## 通知配置

### 修改通知频道

如果需要更改接收通知的频道:

1. 获取新频道的 Channel ID
2. 在 GitHub Secrets 中更新 `SLACK_CHANNEL_ID`
3. 在新频道中邀请 Bot: `/invite @Portal UI Test Bot`

### 为其他项目启用通知

当前配置仅为 POC 项目启用通知。如需为其他项目(如 democase, connectors)启用:

编辑 [.github/workflows/playwright.yml](../.github/workflows/playwright.yml):

```yaml
- name: Send Slack Notification
  if: always() && (env.PROJECT_TO_RUN == 'poc' || env.PROJECT_TO_RUN == 'democase')
  # ... 其余配置
```

### 自定义通知内容

通知脚本位于: `utils/send-slack-notification.ts`

可以自定义:
- 消息格式和样式
- 显示的统计信息
- 失败时的 @提醒
- 报告链接格式

## 故障排查

### 问题 1: 通知未发送

**症状**: CI 运行完成但没有收到 Slack 通知

**解决方案**:
1. 检查 GitHub Secrets 是否正确配置
2. 确认 Bot 已被邀请到频道
3. 查看 GitHub Actions 日志中的 "Send Slack Notification" 步骤
4. 验证 Bot Token 未过期

### 问题 2: 权限错误

**错误信息**: `not_in_channel` 或 `channel_not_found`

**解决方案**:
```
/invite @Portal UI Test Bot
```

### 问题 3: Token 无效

**错误信息**: `invalid_auth` 或 `token_revoked`

**解决方案**:
1. 在 Slack App 设置中重新安装 App
2. 生成新的 Bot Token
3. 更新 GitHub Secret `SLACK_BOT_TOKEN`

### 问题 4: 无法读取 blob 报告

**错误信息**: `Blob reports directory not found`

**解决方案**:
- 确认 blob 报告目录存在且包含 .zip 文件
- 检查 CI workflow 中的 artifact 下载步骤
- 验证 blob 报告是否成功上传和合并

## 高级配置

### 环境变量

除了必需的 `SLACK_BOT_TOKEN` 和 `SLACK_CHANNEL_ID`,还支持:

- `GITHUB_PAGES_URL`: 测试报告的 GitHub Pages URL
- `TEST_ENV`: 测试环境名称(默认: "RC Production")
- `GITHUB_SERVER_URL`: GitHub 服务器 URL(自动设置)
- `GITHUB_REPOSITORY`: 仓库名称(自动设置)
- `GITHUB_RUN_ID`: CI 运行 ID(自动设置)

### 批量通知

如需通知多个频道,可以设置多个 Channel ID(用逗号分隔):

```bash
SLACK_CHANNEL_ID=C01234567,C01234568,C01234569
```

然后修改脚本以支持多频道发送。

## 安全最佳实践

1. ✅ **永远不要**将 Slack Token 提交到代码仓库
2. ✅ **使用** GitHub Secrets 存储敏感信息
3. ✅ **定期轮换** Bot Token
4. ✅ **最小权限原则**: 只授予必要的 OAuth 权限
5. ✅ **监控使用**: 定期检查 Slack App 的使用日志

## 相关资源

- [Slack API 文档](https://api.slack.com/docs)
- [Slack Block Kit Builder](https://app.slack.com/block-kit-builder) - 设计消息格式
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [项目 README](../README.md)

## 支持

如有问题或建议,请:
1. 查看本文档的故障排查部分
2. 检查 GitHub Actions 日志
3. 创建 GitHub Issue
4. 联系测试团队
