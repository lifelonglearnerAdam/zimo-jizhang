# 子墨记账

子墨记账是一款本地优先的个人记账应用，使用 Flutter 构建，主力支持 Windows，同时适配 macOS、iOS、Android 和 Web。

## 2.0 重点

- 新增独立交易明细页，支持月份、收支类型和关键词组合筛选
- 每条记录都可点击编辑，也可通过菜单删除；手机端支持左滑删除
- 删除后可立即撤销，避免误操作
- Windows 支持 `Ctrl+N` 快速记账
- 首页、侧栏和手机底部导航重新设计
- 支持微信、支付宝及通用 CSV 账单导入
- 支持预算、收入、分类和支付账户管理
- CSV 导出支持 Excel 中文显示
- 账本备份与合并恢复，恢复时不覆盖已有记录
- 所有账目保存在本地，不上传服务器

## 数据安全

金额统一以“分”为单位存储，避免小数误差。升级到 2.0 不会重建数据库，也不会修改或删除已有交易记录。备份恢复采用合并模式：记录 ID 已存在时会跳过。

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

Flutter、Riverpod、SQLite（sqflite）、go_router、fl_chart。

## 版本

当前版本：`2.0.0+3`
