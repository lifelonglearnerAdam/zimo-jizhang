# 子墨记账 — 产品文档

## 项目概述

**子墨记账** 是一款面向中国个人用户的记账应用，支持 Windows、Mac、iOS、Android 全平台。用户可以快速记录每一笔人民币花销，通过多级分类管理收支，并通过图表直观了解消费习惯。

### 核心价值

- 📝 **3 秒记账** — 打开即记，最少操作完成一笔记录
- 📊 **消费洞察** — 饼图、趋势图直观展示钱花在哪
- 🔒 **数据私有** — 所有数据存储在本地，无需网络，不上传任何服务器
- 🎨 **赏心悦目** — 墨绿色系，温暖克制，不像是"财务软件"
- 📥 **账单导入** — 支持微信、支付宝、银行 CSV 账单导入

---

## 技术栈

| 层面 | 选型 | 说明 |
|------|------|------|
| 框架 | **Flutter 3.x** | Google 出品，一套 Dart 代码编译到 Windows/Mac/iOS/Android |
| 数据库 | **drift (SQLite)** | Flutter 生态最强的 SQLite ORM，类型安全，支持迁移 |
| 状态管理 | **Riverpod** | Flutter 社区首选，类型安全，易测试 |
| 图表 | **fl_chart** | Flutter 原生图表库，支持饼图、折线图、柱状图 |
| 路由 | **go_router** | Flutter 官方推荐的路由方案 |
| CSV 解析 | **csv** | 纯 Dart 实现，无原生依赖 |
| 编码检测 | **universal_io** + 手动检测 | GBK/UTF-8 自动识别 |
| 桌面增强 | **window_manager** + **system_tray** | 窗口管理、系统托盘 |

### 为什么选 Flutter？

1. 用户明确要求覆盖手机端和桌面端，Flutter 是唯一一套代码做到四个平台都原生级体验的方案
2. Skia 自绘引擎保证 UI 在所有平台上像素级一致
3. 用户选定的方案，且对移动端扩展最为友好

### 平台适配矩阵

| 平台 | 布局 | 导航 | 特殊功能 |
|------|------|------|----------|
| Windows | 宽屏双栏 | 左侧 NavigationRail | 系统托盘常驻 |
| Mac | 宽屏双栏 | 左侧 NavigationRail | 菜单栏集成 |
| iOS | 窄屏单列 | 底部 NavigationBar (Cupertino) | Haptic 反馈 |
| Android | 窄屏单列 | 底部 NavigationBar (Material 3) | 返回手势 |

---

## 产品功能规划

### v1.0 — MVP（最小可用版本）

| 模块 | 功能 | 优先级 |
|------|------|:--:|
| 记一笔 | 金额、分类、日期、备注，3 秒内完成 | P0 |
| 分类管理 | 查看/新增/编辑/删除分类，两级联动 | P0 |
| 今日总览 | 今日支出合计、笔数 | P0 |
| 月度总览 | 本月支出、日均、环比上月 | P0 |
| 支出构成 | 大类饼图，可点击钻取小类 | P0 |
| 交易列表 | 时间倒序、按月筛选、搜索 | P0 |
| CSV 导出 | 导出账单为 CSV（Excel 可打开） | P0 |
| 深色模式 | 浅色/深色/跟随系统 | P1 |

### v1.5 — 账单导入

| 模块 | 功能 |
|------|------|
| 微信账单导入 | 解析微信导出的 CSV，自动映射列 |
| 支付宝账单导入 | 解析支付宝 CSV，处理 GBK 编码 |
| 银行账单导入 | 工商银行、招商银行 CSV 模板 |
| 智能去重 | 同日期+同金额+同描述自动跳过 |
| 自动分类 | 根据交易描述关键词匹配分类 |

### v2.0 — 进阶功能

| 模块 | 功能 |
|------|------|
| 预算管理 | 月度总预算 + 大类预算，超额提醒 |
| 多账户 | 现金/微信/支付宝/银行卡/信用卡 |
| 收入记录 | 工资、奖金、理财收益等 |
| 数据备份 | 一键备份/恢复数据库文件 |

### v3.0 — 智能化（远期）

| 模块 | 功能 |
|------|------|
| 智能报表 | 年度消费报告、趋势分析 |
| 语音记账 | 语音输入 → 自动识别金额和分类 |
| 云同步 | WebDAV 同步（加密传输，不经过第三方） |

---

## 分类体系

### 完整分类树（10 大类，52 小类）

```
🍽️ 餐饮美食
  ├── 一日三餐      （早餐店、食堂、家常饭菜）
  ├── 外卖外送      （美团、饿了么）
  ├── 零食饮料      （超市零食、便利店饮料）
  ├── 水果生鲜      （水果店、买菜）
  ├── 咖啡奶茶      （星巴克、喜茶、瑞幸、蜜雪冰城）
  └── 聚餐聚会      （朋友聚餐、同事聚餐、请客吃饭）

🚗 交通出行
  ├── 公交地铁      （公交卡充值、地铁扫码）
  ├── 打车网约      （滴滴、高德打车、花小猪）
  ├── 加油充电      （加油站、充电桩）
  ├── 停车费        （商场停车、路边停车）
  ├── 火车高铁      （12306）
  ├── 飞机出行      （机票）
  └── 汽车养护      （洗车、保养、年检、保险）

🛒 购物消费
  ├── 服饰鞋包      （衣服、鞋子、包包）
  ├── 数码产品      （手机、电脑、耳机、配件）
  ├── 个护美妆      （护肤品、化妆品、理发）
  ├── 日用百货      （纸巾、洗衣液、厨房用品）
  ├── 家居好物      （收纳、装饰、小家电）
  └── 运动户外      （球鞋、健身器材、露营装备）

🏠 居家生活
  ├── 房租          （每月房租）
  ├── 房贷          （按揭月供）
  ├── 水费          （自来水）
  ├── 电费          （电费账单）
  ├── 燃气费        （天然气）
  ├── 网费话费      （宽带、手机话费）
  ├── 物业费        （小区物业）
  └── 维修修缮      （水管、电器维修）

🎮 休闲娱乐
  ├── 游戏充值      （手游、Steam、Switch）
  ├── 视频会员      （爱奇艺、腾讯视频、B站大会员）
  ├── 音乐会员      （QQ音乐、网易云音乐）
  ├── 电影演出      （电影票、演唱会、话剧）
  ├── 运动健身      （健身房、游泳、瑜伽）
  ├── 旅行度假      （酒店、景点门票、旅行团）
  └── 书籍阅读      （实体书、Kindle电子书）

🏥 医疗健康
  ├── 门诊看病      （挂号、诊疗）
  ├── 药品购买      （处方药、常备药）
  ├── 牙科口腔      （洗牙、补牙、正畸）
  ├── 体检检查      （年度体检、专项检查）
  └── 保健品        （维生素、蛋白粉）

📚 教育学习
  ├── 课程培训      （网课、线下培训班）
  ├── 考试报名      （雅思、考研、考公）
  ├── 书本教材      （教材、教辅、文具）
  └── 知识付费      （得到、知识星球、付费专栏）

🧧 人情往来
  ├── 红包礼金      （微信红包、结婚份子钱）
  ├── 孝敬长辈      （给父母的钱、礼物）
  ├── 请客送礼      （请客吃饭、节日礼物）
  └── 小孩相关      （压岁钱、儿童礼物）

🛡️ 金融保险
  ├── 保险保费      （医疗险、重疾险、车险）
  ├── 手续费        （转账费、提现费）
  ├── 贷款利息      （消费贷、信用卡分期利息）
  └── 税费          （个税补缴、契税）

📦 其他支出
  ├── 快递邮政      （快递费、邮寄）
  ├── 宠物花销      （猫粮狗粮、疫苗、美容）
  ├── 捐赠公益      （水滴筹、腾讯公益）
  └── 杂项          （以上都不属于）
```

### 分类规则

- **大类**：`parent_id IS NULL`，10 个固定大类不可删除，可编辑名称和图标
- **小类**：`parent_id` 指向大类，用户可自由增删改
- **颜色**：每个大类有默认颜色，用于饼图和分类标记
- **图标**：使用 emoji 作为分类图标，无需额外图标库
- **排序**：`sort_order` 控制展示顺序，支持拖拽调整

---

## 数据库设计

### 金额存储约定

**所有金额以「分」为单位，用 INTEGER 存储。**

| 实际金额 | 存储值 | 说明 |
|----------|:------|------|
| ¥35.80 | `3580` | 35.80 × 100 |
| ¥1,280.00 | `128000` | 1280 × 100 |
| ¥0.01 | `1` | 最小单位 |

这避免了 JavaScript/Dart 浮点数精度问题（如 `0.1 + 0.2 ≠ 0.3`），也是支付宝、微信支付等金融系统的标准做法。

### 表结构

```sql
-- 分类表
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  parent_id INTEGER NULL REFERENCES categories(id),
  icon TEXT,                           -- emoji 字符
  color TEXT,                          -- hex 色值
  sort_order INTEGER DEFAULT 0,
  is_default INTEGER DEFAULT 0,       -- 1=系统预设，不可删除
  is_active INTEGER DEFAULT 1,        -- 软删除
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- 交易记录表（核心）
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,                 -- UUID v4
  amount_fen INTEGER NOT NULL,         -- 金额（分）
  type TEXT NOT NULL DEFAULT 'expense' CHECK(type IN ('expense','income')),
  category_id INTEGER REFERENCES categories(id),
  transaction_date TEXT NOT NULL,      -- YYYY-MM-DD
  description TEXT,                    -- 备注
  counterparty TEXT,                   -- 交易对方（导入时提取）
  payment_method TEXT,                 -- wechat/alipay/cash/bank_card/credit_card
  source TEXT DEFAULT 'manual' CHECK(source IN ('manual','import')),
  import_batch_id TEXT,
  external_id TEXT,                    -- 外部交易单号，用于去重
  is_deleted INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- 索引
CREATE INDEX idx_tx_date ON transactions(transaction_date);
CREATE INDEX idx_tx_category ON transactions(category_id);
CREATE INDEX idx_tx_type ON transactions(type);

-- 导入批次表
CREATE TABLE import_batches (
  id TEXT PRIMARY KEY,                 -- UUID
  source TEXT NOT NULL,                -- wechat/alipay/icbc/cmb/generic_csv
  file_name TEXT NOT NULL,
  file_hash TEXT,                      -- SHA256，检测重复导入
  total_count INTEGER DEFAULT 0,
  imported_count INTEGER DEFAULT 0,
  skipped_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending','processing','completed','failed')),
  error_message TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

-- 自动分类规则表（v1.5）
CREATE TABLE auto_category_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  keyword TEXT NOT NULL,               -- 如「美团」
  category_id INTEGER NOT NULL REFERENCES categories(id),
  match_field TEXT DEFAULT 'description' CHECK(match_field IN ('description','counterparty','both')),
  priority INTEGER DEFAULT 0,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT (datetime('now'))
);

-- 应用设置（键值对）
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now'))
);
```

---

## UI/UX 设计规范

### 设计哲学

**克制、温暖、呼吸感**

- 每屏只突出一件事，不给用户压迫感
- 不是冰冷的财务软件，是陪伴理清生活的伙伴
- 大量留白、大圆角、柔和阴影

### 色彩系统

| 角色 | 色值 | 用途 |
|------|------|------|
| Primary | `#2D6A4F` 深松绿 | 按钮、选中态、关键数字 |
| Primary Light | `#52B788` 薄荷绿 | 悬停态、次要强调 |
| Background | `#F7F8F9` 极浅灰 | 全局背景 |
| Surface | `#FFFFFF` 纯白 | 卡片、弹窗 |
| Expense | `#E76F51` 陶土橙 | 支出金额（不用红色，避免负面情绪） |
| Income | `#2D6A4F` 松绿 | 收入金额 |
| Text Primary | `#1A1A2E` 深墨色 | 标题、正文 |
| Text Secondary | `#8E8E93` 灰色 | 辅助说明、时间 |
| Divider | `#E5E5EA` 浅灰 | 列表分隔 |

> **为什么支出不用红色？** 红色在人类心理中 = 警报/错误/亏损，长期看红色数字会积累负面情绪。陶土橙更温暖，同时仍有视觉辨识度。

### 字体

```css
/* 简体中文无衬线字体栈 */
font-family: "PingFang SC", "Microsoft YaHei UI", "Hiragino Sans GB", sans-serif;

/* 数字/金额使用等宽数字字体 */
font-feature-settings: "tnum";
```

### 圆角系统

| 尺寸 | 值 | 用途 |
|------|-----|------|
| Small | 8px | 按钮、标签、输入框 |
| Medium | 12px | 卡片 |
| Large | 16px | 弹窗、大卡片 |
| Full | 999px | 药丸按钮 |

### 间距系统（8px 基准）

`4, 8, 12, 16, 20, 24, 32, 40, 48, 64`

### 布局：桌面端 vs 手机端

```
桌面端 (>800px)                  手机端 (<800px)
┌──────┬──────────────────┐      ┌──────────────────┐
│ 侧边栏 │   主内容区       │      │                  │
│ 240px │                  │      │   主内容区       │
│      │  ┌卡片─────┐     │      │   (滚动)        │
│ 导航  │  │        │     │      │                  │
│      │  └─────────┘     │      │  ┌卡片──┐       │
│      │                  │      │  └──────┘       │
│      │  ┌饼图─────┐    │      │  ┌卡片──┐       │
│      │  │         │    │      │  └──────┘       │
└──────┴──────────────────┘      ├──────────────────┤
                                 │ 底部导航栏       │
                                 └──────────────────┘
```

### 关键交互

1. **记一笔** — 桌面端 `Ctrl+N`，手机端底部中间大按钮，弹窗式输入
2. **金额输入** — 自动聚焦，大号数字键盘，输入 `3580` 自动显示 `35.80`
3. **分类选择** — 最近使用置顶，两级联动
4. **空状态** — 温和插画 + 引导文案，不显示空白页面
5. **动画** — 添加记录后金额弹跳、删除时卡片缩小消失

---

## 项目文件结构

```
子墨记账/
├── CLAUDE.md                    # 本文档
├── README.md                    # 项目简介
├── pubspec.yaml                 # Flutter 依赖配置
├── lib/
│   ├── main.dart                # 应用入口
│   ├── app.dart                 # MaterialApp 配置、主题、路由
│   ├── core/
│   │   ├── theme.dart           # 色彩、字体、圆角、间距常量
│   │   ├── constants.dart       # 全局常量
│   │   └── utils.dart           # 工具函数（金额格式化等）
│   ├── data/
│   │   ├── database.dart        # Drift 数据库定义
│   │   ├── database.g.dart      # Drift 自动生成（gitignore）
│   │   ├── tables.dart          # 表定义
│   │   ├── daos/                # 数据访问对象
│   │   │   ├── category_dao.dart
│   │   │   ├── transaction_dao.dart
│   │   │   └── settings_dao.dart
│   │   └── seed_data.dart       # 默认分类种子数据
│   ├── models/                  # 业务模型（如需要）
│   ├── providers/               # Riverpod 状态管理
│   │   ├── category_provider.dart
│   │   ├── transaction_provider.dart
│   │   └── dashboard_provider.dart
│   ├── features/
│   │   ├── dashboard/           # 首页总览
│   │   ├── add_transaction/     # 记一笔
│   │   ├── transaction_list/    # 交易列表
│   │   ├── statistics/          # 统计分析
│   │   ├── categories/          # 分类管理
│   │   ├── import/              # 账单导入 (v1.5)
│   │   └── settings/            # 设置
│   └── widgets/                 # 通用组件
│       ├── amount_display.dart  # 金额展示组件
│       ├── category_picker.dart # 分类选择器
│       ├── empty_state.dart     # 空状态组件
│       └── responsive_layout.dart # 响应式布局
├── assets/
│   └── images/                  # 图片资源
├── test/                        # 测试
└── windows/                     # Windows 原生配置
    └── runner/
```

---

## 开发约定

### 1. 与项目所有者沟通规则（最重要！）

**项目所有者（用户）不懂编程技术。** 在整个开发过程中必须遵守：

- ✅ 需要技术决策时，列出 2-3 个方案，用通俗语言解释每个方案的优劣
- ✅ 推荐一个方案并说明理由，但最终由用户决定
- ✅ 涉及用户体验的选择（颜色、布局、交互方式），给出可视化描述
- ❌ 不要假设用户理解技术术语（如"状态管理""ORM""响应式"等）
- ❌ 不要直接问"用 Riverpod 还是 Provider？"这种问题

### 2. 代码风格

- 使用 Dart 3 的 records、patterns、sealed classes 等现代特性
- 文件名：`snake_case.dart`
- 类名：`PascalCase`
- 变量/函数：`camelCase`
- 常量：`camelCase`（Dart 惯例，不使用 SCREAMING_SNAKE）
- Widget 使用 `const` 构造函数（性能优化）

### 3. 金额处理

- 存储一律用 `int`（单位：分）
- 展示时用工具函数 `fenToYuan(int fen) → String` 格式化
- 输入时将用户输入转为分存储

### 4. 数据库迁移

- 使用 drift 的 schema migration 机制
- 每次修改表结构必须写 migration
- 不允许直接修改旧 migration（已发布给用户的版本不能改）

### 5. 国际化

- v1.0 仅支持简体中文
- 但所有面向用户的字符串用 Flutter 的 `AppLocalizations` 或至少集中管理
- 为后续多语言预留条件

---

## 开发环境要求

### 用户电脑需要安装

1. **Flutter SDK** (>=3.22) — [安装指南](https://docs.flutter.dev/get-started/install)
2. **Visual Studio 2022** (Windows) — 用于 C++ 编译桌面应用
3. **Xcode** (Mac) — 用于编译 macOS/iOS 应用
4. **Android Studio** — 用于 Android 模拟器和 SDK

### 初始化项目命令

```bash
flutter create --org com.zimo --project-name zimo_jizhang .
flutter pub add drift drift_flutter sqlite3_flutter_libs path_provider path
flutter pub add flutter_riverpod riverpod_annotation go_router
flutter pub add fl_chart csv window_manager system_tray
flutter pub add --dev drift_dev build_runner riverpod_generator
```

---

## 版本历史

| 版本 | 日期 | 内容 |
|------|------|------|
| v0.1 | 2026-07 | 项目初始化，产品文档创建 |
