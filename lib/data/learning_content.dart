import 'dart:convert';

/// 财商学习内容模型、内置种子与日课选择算法。
/// 运行时主数据源是 SQLite `learning_articles`。
class LearningArticle {
  final String id;
  final String title;
  final String category;
  final String icon;
  final int minutes;
  final String summary;
  final List<String> keyPoints;
  final String actionTip;
  final String bodyMd;
  final List<String> tags;
  final String source;
  final String? packId;
  final String? publishedAt;
  final String? updatedAt;
  final int priority;
  final bool isActive;

  const LearningArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.minutes,
    required this.summary,
    required this.keyPoints,
    required this.actionTip,
    this.bodyMd = '',
    this.tags = const [],
    this.source = 'seed',
    this.packId,
    this.publishedAt,
    this.updatedAt,
    this.priority = 100,
    this.isActive = true,
  });

  bool get hasBody => bodyMd.trim().isNotEmpty;

  LearningArticle copyWith({
    String? title,
    String? category,
    String? icon,
    int? minutes,
    String? summary,
    List<String>? keyPoints,
    String? actionTip,
    String? bodyMd,
    List<String>? tags,
    String? source,
    String? packId,
    String? publishedAt,
    String? updatedAt,
    int? priority,
    bool? isActive,
  }) {
    return LearningArticle(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      minutes: minutes ?? this.minutes,
      summary: summary ?? this.summary,
      keyPoints: keyPoints ?? this.keyPoints,
      actionTip: actionTip ?? this.actionTip,
      bodyMd: bodyMd ?? this.bodyMd,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      packId: packId ?? this.packId,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'icon': icon,
      'minutes': minutes,
      'summary': summary,
      'key_points_json': jsonEncode(keyPoints),
      'action_tip': actionTip,
      'body_md': bodyMd,
      'tags_json': jsonEncode(tags),
      'source': source,
      'pack_id': packId,
      'published_at': publishedAt,
      'updated_at': updatedAt,
      'priority': priority,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory LearningArticle.fromMap(Map<String, dynamic> map) {
    return LearningArticle(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '未分类',
      icon: map['icon'] as String? ?? '📘',
      minutes: (map['minutes'] as num?)?.toInt() ?? 5,
      summary: map['summary'] as String? ?? '',
      keyPoints: _decodeStringList(map['key_points_json']),
      actionTip: map['action_tip'] as String? ?? '',
      bodyMd: map['body_md'] as String? ?? '',
      tags: _decodeStringList(map['tags_json']),
      source: map['source'] as String? ?? 'seed',
      packId: map['pack_id'] as String?,
      publishedAt: map['published_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      priority: (map['priority'] as num?)?.toInt() ?? 100,
      isActive: (map['is_active'] as num?)?.toInt() != 0,
    );
  }

  static List<String> _decodeStringList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    if (raw is! String || raw.trim().isEmpty) return const [];
    final text = raw.trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded.map((e) => '$e').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class LearningCatalog {
  LearningCatalog._();

  static List<LearningArticle> get articles => seedArticles;

  static List<String> categoriesOf(List<LearningArticle> items) =>
      {for (final article in items) article.category}.toList();

  static List<String> get categories => categoriesOf(seedArticles);

  static LearningArticle articleForDate(
    DateTime date, {
    List<LearningArticle>? catalog,
  }) {
    final items = (catalog ?? seedArticles)
        .where((item) => item.isActive)
        .toList(growable: false);
    if (items.isEmpty) {
      return seedArticles.first;
    }
    final day =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return items[day % items.length];
  }

  static LearningArticle pickDailyArticle({
    required DateTime date,
    required List<LearningArticle> catalog,
    required Set<String> completedIds,
    String? pinnedId,
  }) {
    final active = catalog.where((a) => a.isActive).toList();
    if (active.isEmpty) {
      return articleForDate(date);
    }
    if (pinnedId != null) {
      final pinned = active.where((a) => a.id == pinnedId).toList();
      if (pinned.isNotEmpty) return pinned.first;
    }

    final unfinished =
        active.where((a) => !completedIds.contains(a.id)).toList()
          ..sort((a, b) {
            final byPriority = b.priority.compareTo(a.priority);
            if (byPriority != 0) return byPriority;
            return (b.updatedAt ?? '').compareTo(a.updatedAt ?? '');
          });
    if (unfinished.isNotEmpty) {
      final day =
          DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
      final top = unfinished.take(8).toList();
      return top[day % top.length];
    }

    return articleForDate(date, catalog: active);
  }

  static final List<LearningArticle> seedArticles = [
    _seed(
      id: 'emergency-fund',
      title: '先攒下第一笔应急金',
      category: '财务基础',
      icon: '🛟',
      minutes: 16,
      summary: '应急金不是投资资金，而是面对失业、疾病和意外支出时的缓冲层。',
      keyPoints: const ['先以 1 个月必要支出为第一阶段目标，再逐步提高到 3 至 6 个月。', '放在流动性高、风险低、随时可取用的账户中。', '非紧急消费动用后，应把补回应急金列为下一阶段优先事项。'],
      actionTip: '查看最近一个月必要支出，给自己的应急金设一个可达成的首期目标。',
      tags: const ['应急金', '现金流', '安全垫'],
      body: _body0,
      priority: 100,
    ),
    _seed(
      id: 'cash-flow',
      title: '现金流比高收入更重要',
      category: '财务基础',
      icon: '🌊',
      minutes: 15,
      summary: '收入高不代表财务健康，持续为正的现金流才是积累资产的起点。',
      keyPoints: const ['月现金流等于月收入减去月支出。', '先稳定固定支出，再处理波动较大的可选消费。', '把每月结余自动转入储蓄或长期投资账户，减少意志力消耗。'],
      actionTip: '把本月结余率与上月比较，优先改善一个最容易调整的支出项目。',
      tags: const ['现金流', '结余率'],
      body: _body1,
      priority: 100,
    ),
    _seed(
      id: 'needs-wants',
      title: '分清需要、想要和值得',
      category: '消费决策',
      icon: '⚖️',
      minutes: 14,
      summary: '成熟的消费不是一味节省，而是让支出与真正重视的生活目标一致。',
      keyPoints: const ['需要解决基本生活问题，想要提升体验，值得则取决于长期使用价值。', '高频使用的物品可以关注单次使用成本，而不只看购买价格。', '对非必要大额消费设置 24 小时冷静期，能过滤冲动购买。'],
      actionTip: '回看本月最大的一笔可选消费，判断它是否仍然符合你的优先级。',
      tags: const ['消费', '决策'],
      body: _body2,
      priority: 100,
    ),
    _seed(
      id: 'budget-method',
      title: '预算不是限制，而是提前做决定',
      category: '预算规划',
      icon: '🧭',
      minutes: 16,
      summary: '有效预算不追求每一分钱都完美，而是让重要目标先获得资源。',
      keyPoints: const ['先安排储蓄、固定支出和必要支出，再分配可选消费。', '预算应根据真实账单每月调整，而不是长期使用一个理想数字。', '分类预算只需要覆盖最容易失控的 3 至 5 个类别。'],
      actionTip: '给本月总预算设一个现实数字，再为最大支出类别单独设置上限。',
      tags: const ['预算', '规划'],
      body: _body3,
      priority: 100,
    ),
    _seed(
      id: 'compound-interest',
      title: '复利真正依赖的是时间',
      category: '投资入门',
      icon: '🌱',
      minutes: 18,
      summary: '复利来自收益继续参与增长，长期、持续和低成本通常比短期预测更重要。',
      keyPoints: const ['开始时间越早，后期增长中来自收益再投资的比例越高。', '频繁买卖、较高费用和中断投入都会削弱复利效果。', '任何承诺高收益且低风险的产品都值得额外警惕。'],
      actionTip: '计算一个你能长期坚持的月度投入金额，而不是追求一次投入很多。',
      tags: const ['复利', '长期投资'],
      body: _body4,
      priority: 100,
    ),
    _seed(
      id: 'inflation',
      title: '理解通胀与购买力',
      category: '投资入门',
      icon: '🎈',
      minutes: 15,
      summary: '账户数字没有减少，也可能因为物价上涨而损失实际购买力。',
      keyPoints: const ['短期要用的钱更看重安全和流动性，长期资金才适合承担波动。', '名义收益减去通胀，才更接近真实收益。', '不同家庭的个人通胀率不同，取决于住房、教育、医疗等支出结构。'],
      actionTip: '比较一项你长期购买的商品近两年的价格，感受自己的实际通胀率。',
      tags: const ['通胀', '购买力'],
      body: _body5,
      priority: 100,
    ),
    _seed(
      id: 'risk-return',
      title: '收益背后一定有风险',
      category: '投资入门',
      icon: '🧩',
      minutes: 17,
      summary: '风险不是只有亏损，还包括波动、流动性不足、信用违约和购买力下降。',
      keyPoints: const ['看不懂的产品不投，无法承受的波动不投。', '分散可以减少单一资产风险，但不能消除市场整体波动。', '投资期限越短，越不应依赖高波动资产完成刚性目标。'],
      actionTip: '为每笔投资写下用途、期限和最大可接受亏损，再判断它是否匹配。',
      tags: const ['风险', '收益'],
      body: _body6,
      priority: 100,
    ),
    _seed(
      id: 'index-fund',
      title: '指数基金解决了什么问题',
      category: '投资入门',
      icon: '📈',
      minutes: 18,
      summary: '指数基金用规则持有一篮子资产，主要价值在于分散、透明和较低成本。',
      keyPoints: const ['指数上涨不代表每天上涨，长期投资仍会经历明显回撤。', '费率、跟踪误差和指数编制规则比短期排名更值得关注。', '定投降低择时压力，但不能保证盈利，也不能替代资产配置。'],
      actionTip: '学习一个宽基指数的构成和历史波动，不急着立即购买。',
      tags: const ['指数基金', '定投'],
      body: _body7,
      priority: 100,
    ),
    _seed(
      id: 'credit-card',
      title: '信用卡的核心是结算，不是收入',
      category: '负债管理',
      icon: '💳',
      minutes: 14,
      summary: '信用额度只是短期负债工具，把额度当可支配收入会快速挤压未来现金流。',
      keyPoints: const ['每月全额还款通常比最低还款更能控制利息成本。', '分期应比较实际年化成本，而不是只看每期手续费。', '临近账单日才记账会低估当月真实消费。'],
      actionTip: '把当前未还账单录入负债账户，净资产会比只看银行卡余额更真实。',
      tags: const ['信用卡', '负债'],
      body: _body8,
      priority: 100,
    ),
    _seed(
      id: 'insurance-order',
      title: '保险优先覆盖承受不起的损失',
      category: '风险保障',
      icon: '🛡️',
      minutes: 16,
      summary: '保险的主要作用是转移重大风险，不应只按返还金额判断是否划算。',
      keyPoints: const ['优先关注医疗、意外、寿险等可能冲击家庭现金流的风险。', '先看保障责任、免责条款和保额，再比较价格。', '家庭经济支柱通常比没有收入的家庭成员更需要充足寿险保障。'],
      actionTip: '列出家庭最难承受的三种财务风险，检查是否已有对应保障。',
      tags: const ['保险', '风险'],
      body: _body9,
      priority: 100,
    ),
    _seed(
      id: 'consumer-loan',
      title: '先偿还哪一笔债务',
      category: '负债管理',
      icon: '🧱',
      minutes: 15,
      summary: '债务管理的目标是降低利息、释放现金流，同时保持可以坚持的节奏。',
      keyPoints: const ['利率优先法先还成本最高的债务，总利息通常更低。', '雪球法先还余额最小的债务，更容易获得阶段性反馈。', '无论采用哪种方法，都要先避免新增高成本债务。'],
      actionTip: '列出每笔债务的余额、利率和月供，选定一种顺序并自动执行。',
      tags: const ['还债', '利息'],
      body: _body10,
      priority: 100,
    ),
    _seed(
      id: 'retirement',
      title: '养老规划从未来现金流开始',
      category: '长期规划',
      icon: '🏡',
      minutes: 18,
      summary: '养老目标不是猜一个巨大数字，而是估算未来支出和稳定收入之间的缺口。',
      keyPoints: const ['先估算退休后的必要支出，再考虑医疗和长寿风险。', '社保、年金、房租等稳定收入可以抵消一部分资金缺口。', '长期目标需要定期复盘，不应因为一次市场波动频繁改变计划。'],
      actionTip: '从一个很小但可持续的月度养老储蓄金额开始，并设置年度复盘。',
      tags: const ['养老', '长期规划'],
      body: _body11,
      priority: 100,
    ),
    _seed(
      id: 'sinking-funds',
      title: '用专项基金拆掉“突然的大支出”',
      category: '预算规划',
      icon: '🧰',
      minutes: 14,
      summary: '年费、保险、旅游、家电更换并不突然，只是没有被提前分摊。',
      keyPoints: const ['把可预期的大额支出按月拆进专项账户。', '专项基金用完即停，不必永久占用现金流。', '它比“到时候再说”更接近真正的预算。'],
      actionTip: '列出未来 12 个月三笔确定会发生的大支出，并换算成每月预提金额。',
      tags: const ['专项基金', '预算'],
      body: _body12,
      priority: 90,
    ),
    _seed(
      id: 'net-worth',
      title: '净资产：比月薪更能描述财务位置',
      category: '财务基础',
      icon: '📐',
      minutes: 15,
      summary: '净资产 = 资产 − 负债。它回答的是“你现在站在哪里”，不是“这个月花了多少”。',
      keyPoints: const ['只看银行卡余额会高估财务自由度。', '信用卡应付款、花呗、房贷都会改变真实位置。', '月度记账 + 季度净资产复盘，比每天焦虑汇率更有用。'],
      actionTip: '在财富页核对资产与负债账户，记录本月净资产快照。',
      tags: const ['净资产', '财富'],
      body: _body13,
      priority: 95,
    ),
    _seed(
      id: 'pay-yourself-first',
      title: '先支付给自己：把储蓄变成默认动作',
      category: '财务基础',
      icon: '🏦',
      minutes: 13,
      summary: '先消费再储蓄，结余总是被挤掉；先储蓄再消费，生活方式会围绕目标重建。',
      keyPoints: const ['发薪日自动转账比月底靠意志力更可靠。', '比例可以很小，但必须先发生。', '储蓄账户与日常消费账户物理隔离，能降低挪用概率。'],
      actionTip: '设置一笔发薪后 24 小时内自动转出的金额，哪怕只是收入的 5%。',
      tags: const ['储蓄', '自动化'],
      body: _body14,
      priority: 92,
    ),

  ];

  static LearningArticle _seed({
    required String id,
    required String title,
    required String category,
    required String icon,
    required int minutes,
    required String summary,
    required List<String> keyPoints,
    required String actionTip,
    required List<String> tags,
    required String body,
    int priority = 100,
  }) {
    return LearningArticle(
      id: id,
      title: title,
      category: category,
      icon: icon,
      minutes: minutes,
      summary: summary,
      keyPoints: keyPoints,
      actionTip: actionTip,
      bodyMd: body,
      tags: tags,
      source: 'seed',
      packId: 'builtin-seed',
      publishedAt: '2026-07-23',
      updatedAt: '2026-07-23',
      priority: priority,
    );
  }
}
const String _body0 = r"""
## 导语

很多人一谈理财就想到收益率，却忽略了一个更基础的问题：**生活会不会因为一次意外支出而被迫中断既有计划？**

应急金解决的不是“怎么赚更多”，而是“在最差的一个月里，你是否还有选择权”。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 它到底是什么

应急金是一笔**高流动性、低风险、专门预留给意外的现金或现金等价物**。

它不是旅游基金，不是抄底子弹子弹，也不是可以随手转走的日常活期余额。

## 目标怎么定

一个可执行的阶梯通常是：0 起步（半个月必要支出）→ 1 基础（1 个月）→ 2 稳健（3 个月）→ 3 加强（4–6 个月）。

**必要支出**只算房租/房贷、基础餐饮、交通、水电通讯、保险保费、最低债务还款。

## 计算示例

若必要支出每月 6,000 元：阶段 1 为 6,000，阶段 2 为 18,000，阶段 3 为 24,000–36,000。

如果每月只能结余 1,500，不必一次到位，先设 90 天内存满阶段 1。

## 放在哪里

优先：独立于日常消费的活期/零钱账户；其次货币基金或现金管理工具（确认到账时效）。

不要为了多 0.5% 收益，把应急金放进锁定期或明显回撤的产品。

## 案例

阿宁过去把结余都放进“随时可能买入”的股票账户。一次电脑维修 + 就医两周支出 9,000，只能透支信用卡并在低点卖出股票。

调整后单独开应急账户，发薪日自动转入 1,200 元。五个月后阶段 1 完成，下一次设备损坏没有打断投资计划。

## 常见误区

“我有信用卡，不需要应急金。” 信用额度是负债，费率与规则不由你控制。

“收益率太低，亏了。” 应急金买的是流动性与确定性。

“用掉也没关系，以后再补。” 用后不补等于没有制度。

## 今日行动

打开子墨记账，筛出近 30 天必要支出类别，估算月必要支出。

写下一个 30–90 天内能完成的阶段 1 数字。

若还没有独立账户，今天标记一个“仅应急”用途的账户或标签。

## 延伸阅读

同系列：《现金流比高收入更重要》

同系列：《用专项基金拆掉“突然的大支出”》
""";
const String _body1 = r"""
## 导语

收入像水龙头，支出像下水口。**真正决定你能不能积累资产的，是每个月剩下来并被安排走的那部分水。**

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 一个公式就够开始

**月现金流 = 月收入 − 月支出**

**结余率 = 月现金流 / 月收入**

先建立自己的基线：负值意味着在吃积累或靠负债；10%–20% 有改善空间；20%+ 开始具备系统储蓄与投资能力。

## 为什么高收入也会现金流很差

固定支出被住房、车贷、订阅锁死。

可变支出没有上限。

收入到账后没有“先支付给自己”的规则。

用信用卡把支付时点往后推，造成“这个月好像还行”的错觉。

## 案例

小林税后 18,000，结余只有约 1,500（8%）。他没有全面省钱，只做两件事：餐饮设周上限；社交改成月度预算池。两个月后结余到 3,200。

## 改善现金流的顺序

看见：完整记账至少 30 天。

分类：固定 / 必要可变 / 可选。

先砍可选里最高频的一项。

自动化结余：发薪后转走。

季度复盘。

## 计算示例

收入 15,000，目标结余率 20% → 结余 3,000。若当前 1,200，缺口 1,800，可拆成餐饮 600 + 购物 600 + 订阅/杂项 600。

## 常见误区

只记大额不记小额高频。

把“偶尔”当成不会重复。

用下月收入填补上月透支。

一谈改善就从房租开刀导致放弃。

## 今日行动

在子墨记账对比本月与上月结余率，只选一个类别设定“本周上限”，周末复盘一次。

## 延伸阅读

《先支付给自己》

《预算不是限制，而是提前做决定》
""";
const String _body2 = r"""
## 导语

省钱不是最高目标，**把钱花在真正重要的事情上**才是。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 三个篮子

**需要**：不做会直接影响基本生活或履约。

**想要**：能提升体验，但延后不会立刻崩溃。

**值得**：不一定便宜，但长期使用价值、健康、关键关系或职业能力提升明确。

## 决策框架

这是解决痛点，还是缓解情绪？

若原价 1.5 倍，我还会买吗？

未来 30 天会高频使用吗？

是否挤占了本月更重要的目标？两道以上答不上，进入 24 小时冷静期。

## 单次使用成本

价格 1,200 的鞋，每周穿 3 次、用 2 年，约 300 次，单次约 4 元；99 元只穿两次的衣服，单次接近 50 元。

## 案例

小周一年四次升级耳机，总花费超过 3,000。后来同一品类 18 个月内只允许一次升级，冲动下降，升级更有针对性。

## 常见误区

把社交压力当成“需要”。

用“我值得拥有”跳过预算。

只比较折扣力度，不比较使用频率。

## 今日行动

打开本月最大一笔可选消费，用“需要/想要/值得”重新贴标签。

## 延伸阅读

《预算不是限制，而是提前做决定》

《现金流比高收入更重要》
""";
const String _body3 = r"""
## 导语

预算让人反感，往往因为被理解成“不许花”。更准确的定义是：**在钱被花掉之前，先替未来的自己做分配。**

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 预算的最小可行版本

不要一开始做 20 个分类。先做四层：先储蓄/还债、固定必要、可变必要、可选生活。

只给最容易超的 3–5 个类别设上限。

## 数字从哪来

好预算来自账单，不来自理想人格。导出近 1–3 个月真实支出，去掉极端异常后取中位数，再做 5–15% 收敛。

## 案例

阿琪给自己定餐饮 1,500，真实三个月都在 2,800，第二周破防。改为餐饮必要 2,200 + 外卖可选 400 后，预算第一次可执行。

## 和记账的关系

记账回答“发生了什么”，预算回答“本希望发生什么”。两者一起看才会出现管理动作。

## 常见误区

预算=苦行。

分类过细维护成本过高。

不给娱乐留空间导致报复性消费。

把年度支出忘了。

## 今日行动

在子墨记账为最大的 1 个支出类别设定本月上限，并加一个“可选生活”总池。

## 延伸阅读

《用专项基金拆掉“突然的大支出”》

《先支付给自己》
""";
const String _body4 = r"""
## 导语

复利常被讲成神话。它的内核其实很朴素：**收益继续留在场内，时间足够长，结果会非线性放大。**

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 机制

若本金 P，年化 r，期数 n，则期末约为：`A = P × (1 + r)^n`。

更关键的现实变量是：是否持续追加、中途是否退出、费率与税负、开始得够不够早。

## 计算对照

每月投入 1,000 元、假设长期年化 6%（仅示意，不保证）：5 年累计 6 万约到 7 万级；10 年 12 万约到 16 万级；20 年 24 万约到 46 万级。

精确数字不重要，重要的是时间越长，收益再投资贡献越高。

## 伤害复利的三件事

频繁交易。

高费用。

中断投入，尤其在市场低迷时停下。

## 案例

A 从 25 岁每月 1,000 坚持 10 年后停下；B 从 35 岁每月 1,000 追 20 年。同样示意收益率下，A 往往并不逊色，因为早期份额有更长的时间参与增长。

## 常见误区

把短期高收益外推成长期必然。

忽视回撤。

还没建立应急金就追求最大化复利。

听信稳赚不赔的高收益。

## 今日行动

写出一个你能连续 12 个月执行的自动投入金额。金额可以小，关键是不依赖情绪。

## 延伸阅读

《收益背后一定有风险》

《指数基金解决了什么问题》
""";
const String _body5 = r"""
## 导语

银行账户数字没变，你却觉得东西更贵了——这不是错觉，而是**购买力**在变化。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 名义 vs 实际

名义收益是账户显示的增长率；实际收益粗略等于名义收益减去通胀。

若理财名义 2%，日常成本上涨 3%，购买力其实在下降。

## 个人通胀率

CPI 是统计平均。你的通胀取决于房租、教育医疗、餐饮外卖等结构。

## 资金的时间分层

0–12 个月更看重安全与流动性；1–3 年看稳健；3 年以上才更适合考虑长期实际增长。

## 案例

阿放把结婚预算全放活期“安全感满满”。两年后婚礼成本上升，预算缺口扩大。中期资金需要与期限匹配。

## 常见误区

以为不投资就没有风险。

用长期资金策略配置下个月要花的钱。

只比较收益率数字，不比较期限与波动。

## 今日行动

选 3 样你几乎每月都买的东西，对比两年前价格，粗算自己的体感通胀。

## 延伸阅读

《复利真正依赖的是时间》

《现金流比高收入更重要》
""";
const String _body6 = r"""
## 导语

收益是风险的价格标签之一。看不到风险，不代表风险不存在。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 风险不止是亏钱

市场波动、流动性风险、信用风险、通胀风险、行为风险（追涨杀跌）。

## 匹配三问

这笔钱准备多久不用？

中途最多能接受浮亏多少而不影响生活？

最坏情况发生时，有没有应急金兜底？

## 分散的边界

分散可降低单一主题打击，但不能消除系统性下跌；过度分散也可能变成无重点收集癖。

## 案例

阿凯把半年后要交的学费放进高波动主题基金，三个月回撤 20%，最终低点赎回。问题是期限与风险不匹配。

## 常见误区

高收益承诺 + 低风险叙事。

用过去一年排行榜指导未来。

把“别人都在赚”当成风控结论。

## 今日行动

给现有每笔投资写三行：用途、期限、最大可接受回撤。写不出来的，标记为待清理。

## 延伸阅读

《指数基金解决了什么问题》

《先攒下第一笔应急金》
""";
const String _body7 = r"""
## 导语

指数基金不是圣杯，它解决的是：如何用较低成本、较透明的规则，持有一篮子资产。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 它解决了什么

分散、透明、相对较低成本、减少听消息换仓的频率。

## 它没解决什么

不会消除回撤，不会保证正收益，不会替你完成资产配置，不会免除行为错误。

## 定投的真实作用

把投入动作自动化，降低择时压力，在波动中分批累积份额。定投不是亏损保险。

## 选择时多看这些

跟踪哪个指数；管理费与交易摩擦；跟踪误差；持有期限是否匹配心理准备。

## 案例

小满每次数值回调都想“等更低”，结果空仓半年。改为每月自动定投宽基后，执行第一次稳定下来。

## 常见误区

把短期主题指数当稳稳的幸福。

只看名称里的“指数”。

一边定投一边频繁手动择时。

没有应急金就上高仓位。

## 今日行动

选一个你听得懂的宽基指数，只做研究：成分、历史波动、费率。先写 200 字笔记，不急着下单。

## 延伸阅读

《复利真正依赖的是时间》

《收益背后一定有风险》
""";
const String _body8 = r"""
## 导语

信用卡是高效的支付与结算工具，也是高成本负债的入口。差别只在：你把它当钱包，还是当收入？

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 正确用法

额度 ≠ 可消费收入。

账单日/还款日写入日历。

尽量全额还款。

大额分期前先算真实年化。

消费即时记账。

## 最低还款的代价

最低还款能避免逾期，但剩余本金继续计息，短期舒缓、长期可能很贵。

## 案例

阿蕾每月还能还最低，一年后利息与手续费可观，且失去对真实消费水平的感知。改为全额还款 + 降额度后决策重新清醒。

## 和净资产的关系

只看借记卡余额会高估健康度。未出账应付款、花呗、白条都应计入负债侧。

## 常见误区

用新卡还旧卡。

为积分购买不需要的东西。

把分期当成没花钱。

## 今日行动

在财富/账户里把当前应还款记为负债，并确认本月能否全额覆盖。

## 延伸阅读

《先偿还哪一笔债务》

《净资产：比月薪更能描述财务位置》
""";
const String _body9 = r"""
## 导语

保险不是理财收益比赛，而是**把家庭无法承受的损失转移出去**。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 配置顺序（通用框架）

社保与基础医疗是否到位；重大疾病/高额医疗；意外身故/伤残；经济支柱寿险保额；其他个性化需求。

返还、分红、投资属性应在保障充足后才讨论。

## 保额怎么想

寿险保额常与负债余额、家人数年必要支出、子女教育目标相关。“保费便宜所以先买一点”不等于风险已被覆盖。

## 案例

双职工家庭把预算花在多种返还型产品上，真实医疗与寿险保额不足。复盘后原则变成：先补缺口，再谈满意形态。

## 常见误区

只看返还，不看责任免除。

为孩子买一堆，成人支柱反而不够。

把保险当投资主渠道。

## 今日行动

写下家庭最难承受的 3 种财务风险，检查现有保单是否真的对应它们。

## 延伸阅读

《先攒下第一笔应急金》

《养老规划从未来现金流开始》
""";
const String _body10 = r"""
## 导语

还债策略的目标不是道德完美，而是用可坚持的节奏，降低利息并恢复选择权。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 两种主流顺序

**利率优先**：先打年化成本最高的债务，总利息通常更低。

**雪球法**：先清余额最小的债务，心理反馈强，总利息可能更高。

## 共同前提

先保证最低还款。

停止新增高成本负债。

有小幅应急金。

额外还款来自可重复结余。

## 计算示例

债务 A 8,000 年化 18%；债务 B 2,000 年化 12%；每月额外 1,000。雪球先灭 B；利率优先先攻 A。选你能执行 6 个月以上的。

## 案例

阿峰同时有信用卡、消费贷和借呗，每天焦虑却没有自动计划。做成表格后系统建立，情绪噪音下降。

## 常见误区

边还边借。

只看月供不看利率。

没有记账不知道进度。

## 今日行动

列出全部债务的余额、利率、最低还款，选一种顺序，并设定下个月额外还款金额。

## 延伸阅读

《信用卡的核心是结算，不是收入》

《现金流比高收入更重要》
""";
const String _body11 = r"""
## 导语

养老规划令人头大，是因为目标又远又模糊。把它改写成**未来每年的现金流缺口**，会好做很多。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 三步框架

支出：退休后必要生活成本（今天价格）× 通胀假设。

收入：社保/养老金、租金、年金等较稳定来源。

缺口：支出 − 收入，再考虑可工作年限与波动。

## 为什么要尽早

时间能降低每年需要储蓄的强度；健康与收入能力在中年前通常更有弹性；长期账户更经得起波动。

## 案例

40 岁的阿宁先算希望退休后维持今天 8,000 元/月的生活，稳定收入折合 4,500，月缺口 3,500。焦虑变成了项目。

## 常见误区

只看账户总金额，不看可提取现金流。

完全依赖房价或单一平台。

临近退休仍高波动集中押注。

## 今日行动

写下退休后希望维持的月支出（今天价格）和目前可预期的稳定收入，只求一个粗糙缺口数字。

## 延伸阅读

《复利真正依赖的是时间》

《净资产：比月薪更能描述财务位置》
""";
const String _body12 = r"""
## 导语

“突然要交 3,000 保险/旅行/更换家电”——其中大半并不突然，只是**没有被月度化**。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 什么是专项基金

把未来 3–18 个月内几乎确定的大额支出，按月拆进独立小账户或标签：年度保险、旅行、家电、节日礼物、车辆保养等。

## 算法

月预提 = 目标金额 / 剩余月数。例：11 个月后旅行预算 6,600 → 每月 600。

## 与应急金的区别

应急金应对意外，尽量保持；专项基金应对可预期大项，可以花光，项目结束后可暂停。

## 今日行动

列出未来 12 个月三件几乎肯定要花的事，换算成每月预提，并在预算中单列。

## 延伸阅读

《预算不是限制，而是提前做决定》

《先攒下第一笔应急金》
""";
const String _body13 = r"""
## 导语

月薪描述的是流速，**净资产描述的是水位**。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 定义

**净资产 = 资产 − 负债**。资产包括现金、存款、投资等；负债包括信用卡、消费贷、房贷、亲友借款等。

## 为什么要季度看一次

发现表面有钱、实际很紧；评估还债与投资是否同时改善水位；防止只优化月度结余却忽略负债累积。

## 今日行动

在财富页核对资产账户与负债账户，记录一次净资产快照，并设下季度同一天复盘。

## 延伸阅读

《现金流比高收入更重要》

《信用卡的核心是结算，不是收入》
""";
const String _body14 = r"""
## 导语

如果储蓄总发生在“这个月还剩多少”之后，它就永远排在生活膨胀的后面。

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。任何涉及产品选择的决策，请结合自身情况与持牌机构意见。

## 做法

发薪日 +0～1 天自动转出固定金额或比例。

转入不易触达的账户。

剩余资金才进入日常预算。

涨薪时优先提高自动转出。

## 比例参考（不是教条）

起步 5%；改善 10–20%；冲刺还债/买房可以更高，但需可维持。

## 今日行动

设置一笔下个发薪日自动转出的金额，并在子墨记账中把它记为储蓄目标的一部分。

## 延伸阅读

《现金流比高收入更重要》

《先攒下第一笔应急金》
""";
