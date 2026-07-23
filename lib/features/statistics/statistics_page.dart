import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/transaction_provider.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  String get _yearMonth =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(monthTransactionsProvider(_yearMonth));
    final categories = ref.watch(monthCategoryExpensesProvider(_yearMonth));
    final daily = ref.watch(monthDailyExpensesProvider(_yearMonth));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: 18),
                transactions.when(
                  data: (items) {
                    final expense = items
                        .where((item) => item.type == 'expense')
                        .fold<int>(0, (sum, item) => sum + item.amountFen);
                    final income = items
                        .where((item) => item.type == 'income')
                        .fold<int>(0, (sum, item) => sum + item.amountFen);
                    final savingsRate = income <= 0
                        ? 0.0
                        : ((income - expense) / income).clamp(-1.0, 1.0);
                    return Column(
                      children: [
                        _kpis(expense, income, savingsRate, items.length),
                        const SizedBox(height: 18),
                        _trendPanel(daily),
                        const SizedBox(height: 18),
                        _categoryPanel(categories),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => _emptyPanel('统计数据加载失败'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '消费分析',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '用趋势和结构理解每一笔支出',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '上个月',
          onPressed: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          AppDateUtils.toMonthLabel('$_yearMonth-01'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        IconButton(
          tooltip: '下个月',
          onPressed: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _kpis(int expense, int income, double savingsRate, int count) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 30) / 4
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpi(
              '本月支出',
              MoneyUtils.fenToShort(expense),
              AppColors.expense,
              width,
            ),
            _kpi(
              '本月收入',
              MoneyUtils.fenToShort(income),
              AppColors.income,
              width,
            ),
            _kpi(
              '储蓄率',
              income == 0 ? '--' : '${(savingsRate * 100).toStringAsFixed(0)}%',
              AppColors.warning,
              width,
            ),
            _kpi('记录笔数', '$count 笔', AppColors.primary, width),
          ],
        );
      },
    );
  }

  Widget _kpi(String label, String value, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 11),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendPanel(AsyncValue<List<DailyExpense>> daily) {
    return _panel(
      title: '每日支出',
      subtitle: '观察高支出日，找到可以提前规划的波动',
      child: daily.when(
        data: (items) {
          if (items.isEmpty) return _emptyPanel('这个月还没有支出');
          final points = [
            for (final item in items)
              FlSpot(
                int.parse(item.date.substring(8)).toDouble(),
                item.amountFen / 100,
              ),
          ];
          final maxY = points
              .map((point) => point.y)
              .fold<double>(0, (m, v) => v > m ? v : m);
          return SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: points.first.x,
                maxX: points.last.x,
                minY: 0,
                maxY: maxY <= 0 ? 10 : maxY * 1.25,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 0 ? 5 : maxY / 3,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.divider, strokeWidth: 0.7),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: points.length > 10 ? 5 : 1,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${value.toInt()}日',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    isCurved: true,
                    barWidth: 3,
                    color: AppColors.expense,
                    dotData: FlDotData(show: points.length < 12),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.expense.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => _emptyPanel('趋势加载失败'),
      ),
    );
  }

  Widget _categoryPanel(AsyncValue<List<CategoryExpense>> categories) {
    return _panel(
      title: '支出结构',
      subtitle: '按大类查看钱花在哪里',
      child: categories.when(
        data: (items) {
          if (items.isEmpty) return _emptyPanel('这个月还没有分类支出');
          final total = items.fold<int>(0, (sum, item) => sum + item.totalFen);
          return LayoutBuilder(
            builder: (context, constraints) {
              final chart = SizedBox(
                height: 240,
                width: constraints.maxWidth >= 700 ? 300 : double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: items.take(8).map((item) {
                          final color = _parseColor(item.color);
                          return PieChartSectionData(
                            value: item.totalFen.toDouble(),
                            color: color,
                            title: '',
                            radius: 72,
                          );
                        }).toList(),
                        sectionsSpace: 3,
                        centerSpaceRadius: 48,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          MoneyUtils.fenToShort(total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          '总支出',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              final ranking = Column(
                children: [
                  for (final item in items.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(item.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              item.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            MoneyUtils.fenToShort(item.totalFen),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
              if (constraints.maxWidth >= 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    chart,
                    const SizedBox(width: 30),
                    Expanded(child: ranking),
                  ],
                );
              }
              return Column(children: [chart, ranking]);
            },
          );
        },
        loading: () => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => _emptyPanel('分类加载失败'),
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _emptyPanel(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34),
    child: Center(
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    ),
  );

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
