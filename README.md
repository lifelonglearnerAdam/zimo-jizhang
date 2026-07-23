# 子墨记账

子墨记账是一款本地优先的个人记账应用，使用 Flutter 构建，主力支持 Windows，同时适配 macOS、iOS、Android 和 Web。

## 2.2 重点

- 财商学习升级为**专栏长文**（Markdown 全页阅读）
- 支持**内容包导入**与**远程 URL 更新**；打开学习页可自动检查更新
- 内置长文种子 + 仓库附带可导入专栏包与生成管线
- 财富中心：资产、负债、净资产、储蓄目标
- 消费分析：月份切换、关键指标、每日趋势、分类结构
- 主导航：总览 / 明细 / 分析 / 财富 / 学习

## 2.0 基础能力

- 独立交易明细页，支持月份、收支类型和关键词组合筛选
- 记录可编辑、删除、滑动删除与误删撤销
- Windows `Ctrl+N` 快速记账
- 微信、支付宝及通用 CSV 账单导入
- 预算、收入、分类和支付账户管理
- CSV 导出支持 Excel 中文显示
- 账本备份与合并恢复（只增不覆盖）
- 所有账目保存在本地，不上传服务器

## 财商内容更新

### App 内

1. 打开「学习」
2. 导入 `content/dist/learning-pack-*.json`
3. 或设置远程内容包 URL；之后打开学习页会按约 6 小时节流自动检查

### 生成/打包（开发者）

```powershell
python tools/learning_pipeline/batch_expand_articles.py
python tools/learning_pipeline/generate_daily.py pack
python tools/learning_pipeline/generate_daily.py scaffold --id my-topic --title "标题"
```

可选：配置 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` 后使用

```powershell
python tools/learning_pipeline/generate_daily.py generate --topic "应急金进阶"
```

## 数据安全

金额统一以“分”为单位存储，避免小数误差。升级不会重建数据库，也不会修改或删除已有交易记录。备份恢复采用合并模式：记录 ID 已存在时会跳过。

学习正文存于本地 SQLite `learning_articles`；进度在 `learning_progress`。远程更新只拉取教育内容包，不上传账本。

## 开发与构建

```powershell
flutter pub get
flutter test
flutter analyze
flutter build windows --release
flutter build web --release
flutter build apk --release
```

Windows 发布文件位于 `build/windows/x64/runner/Release/`，Android 安装包位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 技术栈

Flutter、Riverpod、SQLite（sqflite）、go_router、fl_chart、flutter_markdown。

## 版本

当前版本：`2.2.0+6`
