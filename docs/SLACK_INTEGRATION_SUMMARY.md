# Slack 通知集成总结

## ✅ 已完成的工作

### 1. Slack 通知脚本
**文件**: `utils/send-slack-notification.ts`

通过解析 Playwright blob 报告提取统计数据并发送 Slack 通知:
- 📊 从 blob 报告(JSONL 格式)直接提取测试统计
- 💬 发送格式化的 Slack 消息
- 🔗 包含 CI 日志链接
- ⚡ 无需浏览器渲染,性能更优

### 2. GitHub Actions 集成
**文件**: `.github/workflows/playwright.yml`

在 `merge-reports` 作业中添加 Slack 通知步骤:
- ✅ 仅在 POC 项目运行时发送通知
- ✅ 使用 GitHub Secrets 安全存储凭证
- ✅ 失败不影响 CI 流程(`continue-on-error: true`)

### 3. 配置文档
- **快速启动**: `docs/SLACK_NOTIFICATION_QUICK_START.md` - 5分钟完成配置
- **完整指南**: `docs/SLACK_SETUP.md` - 详细设置和故障排查

## 🎯 使用方法

### 首次设置

1. 创建 Slack App
2. 添加 OAuth 权限(`chat:write`)
3. 获取 Channel ID
4. 配置 GitHub Secrets (`SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID`)
5. 邀请 Bot 到频道

详细步骤见: [快速启动指南](./SLACK_NOTIFICATION_QUICK_START.md)

### 自动运行

系统会自动在以下时机发送通知:
- ⏰ 每天 UTC 04:30 (POC 定时任务)
- 🔧 手动触发 POC 测试

### 本地测试

```bash
# 设置环境变量
export SLACK_BOT_TOKEN=xoxb-your-token
export SLACK_CHANNEL_ID=C01234567

# 运行测试生成 blob 报告
npx playwright test --project=poc --reporter=blob

# 发送通知
npx ts-node utils/send-slack-notification.ts ./blob-report poc
```

## 📋 通知内容

### 成功通知 ✅
```
✅ POC TESTS PASSED
Total: 10 | Passed: 10 | Failed: 0
🎉 All tests passed successfully!
[View CI Logs]
```

### 失败通知 ❌
```
❌ POC TESTS FAILED
Total: 10 | Passed: 8 | Failed: 2 | Failure Rate: 20%
⚠️ Action Required: Please investigate test failures
[View CI Logs]
```

## 🔧 技术实现

### 环境变量
```bash
# 必需
SLACK_BOT_TOKEN=xoxb-your-token
SLACK_CHANNEL_ID=C01234567

# 自动设置(CI环境)
GITHUB_PAGES_URL=https://codeseals.github.io/portal-ui-automation
GITHUB_SERVER_URL=https://github.com
GITHUB_REPOSITORY=codeseals/portal-ui-automation
GITHUB_RUN_ID=123456789
TEST_ENV=RC Production
```

### 性能优化
- ⚡ 直接解析 blob 报告(ZIP文件中的JSONL),无需浏览器渲染
- 📦 无需安装 Chromium(节省 ~300MB)
- 🚀 更快的执行速度,减少 CI 资源消耗
- 🎯 精确的统计数据,直接来源于测试执行结果

### Blob 报告格式
- **格式**: ZIP 文件包含 `report.jsonl`
- **内容**: 每行一个 JSON 事件(`onTestBegin`, `onTestEnd`, 等)
- **提取**: 解析 `onTestEnd` 事件获取测试状态
- **状态**: `passed`, `failed`, `timedOut`, `interrupted`, `skipped`

## 🚀 扩展配置

### 为其他项目启用通知

编辑 `.github/workflows/playwright.yml`:

```yaml
# 当前: 仅 POC
if: always() && env.PROJECT_TO_RUN == 'poc'

# 扩展: POC + DEMOCASE
if: always() && (env.PROJECT_TO_RUN == 'poc' || env.PROJECT_TO_RUN == 'democase')

# 扩展: 所有项目
if: always()
```

### 多频道通知

修改脚本以循环发送到多个频道:
```typescript
const channelIds = process.env.SLACK_CHANNEL_ID.split(',');
for (const channelId of channelIds) {
  await web.chat.postMessage({ channel: channelId.trim(), ... });
}
```

## 🔒 安全最佳实践

✅ **推荐**:
- Slack Token 存储在 GitHub Secrets
- 使用最小权限(`chat:write`)
- 定期轮换 Token

❌ **禁止**:
- 将 Token 提交到代码仓库
- 在日志中打印 Token
- 授予不必要的权限

## 📚 相关文档

- [快速启动指南](./SLACK_NOTIFICATION_QUICK_START.md) - 5分钟完成配置
- [完整设置指南](./SLACK_SETUP.md) - 详细配置和故障排查
- [Slack API 文档](https://api.slack.com/docs)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

**配置完成后,每次 POC 测试运行后将自动收到 Slack 通知!** 🎊
