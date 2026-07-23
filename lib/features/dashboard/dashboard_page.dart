import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/learning_content.dart';
import '../../data/models.dart';
import '../../providers/learning_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/wealth_provider.dart';
import '../../widgets/amount_display.dart';
import '../add_transaction/add_transaction_dialog.dart';

/// 首页 — 总览 + 按天交易列表
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final monthTotal = ref.watch(monthTotalProvider);
    final monthIncome = ref.watch(monthIncomeProvider);
    final recent = ref.watch(recentTransactionsProvider);
    final wealth = ref.watch(wealthSummaryProvider);
    final todayLessonAsync = ref.watch(todayLearningProvider);
    final learningProgress = ref.watch(learningProgressProvider).valueOrNull;
    final allCats = ref.watch(allCategoriesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayLesson = todayLessonAsync.valueOrNull;
    final todayProgress =
        todayLesson == null ? null : learningProgress?[todayLesson.id];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(monthTotalProvider);
        ref.invalidate(monthIncomeProvider);
        ref.invalidate(todayTransactionsProvider);
        ref.invalidate(categoryExpensesProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(wealthSummaryProvider);
        ref.invalidate(learningProgressProvider);
        ref.invalidate(learningCatalogProvider);
        ref.invalidate(todayLearningProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 12),
          _buildSummaryCard(monthIncome, monthTotal),
          const SizedBox(height: 10),
          _buildInsightCards(
            wealth,
            todayLessonAsync,
            todayProgress,
          ),
          const SizedBox(height: 10),
          _buildBudgetBar(),
          const SizedBox(height: 12),
          _buildCategoryPreview(),
          const SizedBox(height: 16),
          _sectionTitle(
            '近期记录（最近 ${recent.valueOrNull?.length ?? 12} 笔）',
            action: () => context.go('/transactions'),
            actionLabel: '全部明细',
          ),
          recent.when(
            data: (transactions) => transactions.isEmpty
                ? _emptyHint()
                : Column(
                    children: _buildDailyList(transactions, allCats, isDark),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '记录加载失败',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final g = hour < 6
        ? '夜深了 🌙'
        : hour < 12
        ? '早上好 ☀️'
        : hour < 18
        ? '下午好 🌤️'
        : '晚上好 🌆';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '墨',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                AppDateUtils.currentMonth(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(AsyncValue<int> inc, AsyncValue<int> exp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF40916C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D6A4F).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _amountCol('本月支出', exp, Colors.white70, Colors.white),
                ),
                Container(width: 1, height: 44, color: Colors.white24),
                Expanded(
                  child: _amountCol('本月收入', inc, Colors.white70, Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            inc.when(
              data: (i) => exp.when(
                data: (e) {
                  final b = i - e;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '结余 ${b >= 0 ? '+' : '-'}${MoneyUtils.fenToYuan(b.abs(), showSymbol: true)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
                loading: () => sz,
                error: (_, __) => sz,
              ),
              loading: () => sz,
              error: (_, __) => sz,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountCol(String label, AsyncValue<int> val, Color lc, Color vc) {
    return Column(
      children: [
        val.when(
          data: (v) => Text(
            MoneyUtils.fenToShort(v),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: vc,
              letterSpacing: 0,
            ),
          ),
          loading: () => const SizedBox(
            height: 28,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
          error: (_, __) => const Text(
            '--',
            style: TextStyle(color: Colors.white54, fontSize: 24),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: lc)),
      ],
    );
  }

  Widget get sz => const SizedBox.shrink();

  Widget _buildInsightCards(
    AsyncValue<WealthSummary> wealth,
    AsyncValue<LearningArticle> todayLesson,
    LearningProgress? progress,
  ) {
    final article = todayLesson.valueOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _insightCard(
              color: AppColors.primaryLightest,
              iconColor: AppColors.primary,
              icon: Icons.account_balance_wallet_outlined,
              label: '净资产',
              value: wealth.when(
                data: (summary) => MoneyUtils.fenToShort(summary.netWorthFen),
                loading: () => '计算中',
                error: (_, __) => '--',
              ),
              actionLabel: '财富中心',
              onTap: () => context.go('/wealth'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _insightCard(
              color: AppColors.warningLight,
              iconColor: AppColors.warning,
              icon: progress?.completed == true
                  ? Icons.check_circle_outline_rounded
                  : Icons.auto_stories_outlined,
              label: article == null
                  ? '每日一课'
                  : '每日一课 · ${article.minutes} 分钟',
              value: todayLesson.when(
                data: (item) => item.title,
                loading: () => '加载中…',
                error: (_, __) => '暂时不可用',
              ),
              actionLabel: progress?.completed == true ? '今日已学' : '开始学习',
              onTap: () {
                if (article != null) {
                  context.push('/learn/${article.id}');
                } else {
                  context.go('/learn');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard({
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String label,
    required String value,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          height: 116,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: iconColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetBar() {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final budget = ref.watch(allBudgetsProvider(ym)).valueOrNull?[null];
    final total = ref.watch(monthTotalProvider).valueOrNull ?? 0;
    if (budget == null || budget <= 0) return const SizedBox.shrink();
    final ratio = (total / budget).clamp(0.0, 1.0);
    final over = ratio >= 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '预算 ${MoneyUtils.fenToShort(total)}/${MoneyUtils.fenToShort(budget)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            over ? '超支!' : '${(ratio * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: over ? AppColors.danger : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(
                  over ? AppColors.danger : AppColors.primary,
                ),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPreview() {
    final data = ref.watch(categoryExpensesProvider).valueOrNull ?? [];
    if (data.isEmpty) return const SizedBox.shrink();
    final total = data.fold<int>(0, (s, c) => s + c.totalFen);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 85,
              height: 85,
              child: PieChart(
                PieChartData(
                  sections: data
                      .take(5)
                      .map(
                        (c) => PieChartSectionData(
                          value: c.totalFen.toDouble(),
                          color: _pc(c.color),
                          title: '',
                          radius: 26,
                        ),
                      )
                      .toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: data.take(4).map((c) {
                  final pct = total > 0
                      ? (c.totalFen / total * 100).toStringAsFixed(1)
                      : '0';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _pc(c.color),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${c.icon}', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            c.categoryName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title, {
    VoidCallback? action,
    String actionLabel = '查看全部',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (action != null)
            TextButton.icon(
              onPressed: action,
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _emptyHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Text('📝', style: TextStyle(fontSize: 44)),
            SizedBox(height: 8),
            Text(
              '还没有记录',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDailyList(
    List<TransactionModel> txs,
    List<CategoryModel> cats,
    bool isDark,
  ) {
    final g = <String, List<TransactionModel>>{};
    for (final t in txs) {
      g.putIfAbsent(t.transactionDate, () => []).add(t);
    }
    final dates = g.keys.toList()..sort((a, b) => b.compareTo(a));
    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    final widgets = <Widget>[];
    for (final date in dates) {
      final dayTxs = g[date]!;
      final dayExp = dayTxs
          .where((t) => t.type == 'expense')
          .fold<int>(0, (s, t) => s + t.amountFen);
      final isToday = date == today;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: Row(
            children: [
              if (isToday) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '今天',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                AppDateUtils.toDisplayWithWeekday(date),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isToday ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (dayExp > 0)
                Text(
                  '支出 ¥${(dayExp / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      );

      for (final tx in dayTxs) {
        final cat = cats.where((c) => c.id == tx.categoryId).firstOrNull;
        widgets.add(
          Dismissible(
            key: Key(tx.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            confirmDismiss: (_) async => await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('删除'),
                content: const Text('确定删除这条记录？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text(
                      '删除',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
            onDismissed: (_) => _deleteWithUndo(tx),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editTransaction(tx),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tx.type == 'income'
                              ? AppColors.incomeLight
                              : AppColors.expenseLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat?.icon ?? '📌',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat?.name ?? '未分类',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (tx.description != null &&
                                tx.description!.isNotEmpty)
                              Text(
                                tx.description!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      AmountDisplay(
                        amountFen: tx.amountFen,
                        size: AmountSize.small,
                        type: tx.type,
                      ),
                      PopupMenuButton<String>(
                        tooltip: '记录操作',
                        icon: const Icon(Icons.more_vert_rounded, size: 19),
                        onSelected: (value) {
                          if (value == 'edit') _editTransaction(tx);
                          if (value == 'delete') _deleteFromMenu(tx);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑记录')),
                          PopupMenuItem(value: 'delete', child: Text('删除记录')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Color _pc(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Future<void> _editTransaction(TransactionModel tx) async {
    final notifier = ref.read(transactionListNotifierProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (_) => AddTransactionDialog(
        transaction: tx,
        onSubmitted: (draft) => notifier.updateTransaction(
          tx.copyWith(
            amountFen: draft.amountFen,
            type: draft.type,
            categoryId: draft.category.id,
            transactionDate: draft.date,
            description: draft.note,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteFromMenu(TransactionModel tx) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除这笔记录？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) _deleteWithUndo(tx);
  }

  void _deleteWithUndo(TransactionModel tx) {
    ref.read(transactionListNotifierProvider.notifier).deleteTransaction(tx.id);
    ref.invalidate(recentTransactionsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('记录已删除'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            ref
                .read(transactionListNotifierProvider.notifier)
                .restoreTransaction(tx.id);
            ref.invalidate(recentTransactionsProvider);
          },
        ),
      ),
    );
  }
}
