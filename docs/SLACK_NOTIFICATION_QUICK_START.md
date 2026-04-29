# Slack 通知快速启动指南

5 分钟完成 POC 测试 Slack 通知配置!

## 快速配置清单

### ☑️ Step 1: 创建 Slack App (2 分钟)

1. 访问 https://api.slack.com/apps → **Create New App** → **From scratch**
2. 输入名称: `Portal UI Test Bot`
3. 选择你的 Workspace → **Create App**

### ☑️ Step 2: 添加权限 (1 分钟)

1. 左侧菜单 → **OAuth & Permissions**
2. 在 **Bot Token Scopes** 添加:
   - ✅ `chat:write`
3. 页面顶部 → **Install to Workspace** → 授权
4. **复制 Bot User OAuth Token** (以 `xoxb-` 开头)

### ☑️ Step 3: 获取 Channel ID (30 秒)

1. 打开 Slack 频道
2. 点击频道名称 → 下方显示 **Channel ID** → 复制

### ☑️ Step 4: 配置 GitHub Secrets (1 分钟)

GitHub 仓库 → Settings → Secrets and variables → Actions → New repository secret

添加 2 个 secrets:
1. **Name**: `SLACK_BOT_TOKEN`
   **Value**: `xoxb-你的token`

2. **Name**: `SLACK_CHANNEL_ID`
   **Value**: `C你的频道ID`

### ☑️ Step 5: 邀请 Bot (10 秒)

在 Slack 频道输入:
```
/invite @Portal UI Test Bot
```

## ✅ 完成!

下次 POC 测试运行时(每天 UTC 04:30 或手动触发),你将在 Slack 频道收到通知!

## 测试配置

### 本地测试

```bash
# 添加环境变量到 .env
echo "SLACK_BOT_TOKEN=xoxb-your-token" >> .env
echo "SLACK_CHANNEL_ID=C01234567" >> .env

# 运行测试生成 blob 报告
npx playwright test --project=poc --reporter=blob

# 运行通知脚本(使用 blob 报告目录)
npx ts-node utils/send-slack-notification.ts ./blob-report poc
```

### 触发 CI 测试

GitHub → Actions → Playwright Tests → Run workflow
- 选择 project: **poc**
- 点击 **Run workflow**

大约 15-20 分钟后,你将收到 Slack 通知!

## 通知内容预览

### 成功时 ✅
```
✅ POC TESTS PASSED

Total Tests: 10
Passed: ✅ 10
Failed: ❌ 0

🎉 All tests passed successfully!

[View CI Logs]
```

### 失败时 ❌
```
❌ POC TESTS FAILED

Total Tests: 10
Passed: ✅ 8
Failed: ❌ 2
Failure Rate: 20.0%

⚠️ Action Required: Please investigate test failures

[View CI Logs]
```

## 常见问题

**Q: 没有收到通知?**
- ✅ 检查 GitHub Secrets 是否正确配置
- ✅ 确认 Bot 已被邀请到频道(`/invite @Portal UI Test Bot`)
- ✅ 查看 GitHub Actions 日志中的 "Send Slack Notification" 步骤

**Q: 显示 "not_in_channel" 错误?**
- 在频道中执行: `/invite @Portal UI Test Bot`

**Q: 想为其他项目启用通知?**
- 查看完整文档: [docs/SLACK_SETUP.md](./SLACK_SETUP.md)

## 详细文档

更多配置选项和故障排查,请参考: [完整 Slack 设置指南](./SLACK_SETUP.md)
