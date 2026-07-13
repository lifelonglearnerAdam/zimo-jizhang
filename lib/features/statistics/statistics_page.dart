import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/transaction_provider.dart';

/// 统计分析页面 v2
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryExpenses = ref.watch(categoryExpensesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.glow),
            alignment: Alignment.center,
            child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('支出分析', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 24),

        categoryExpenses.when(
          data: (data) {
            if (data.isEmpty) return Center(child: Padding(padding: const EdgeInsets.only(top: 60), child: Column(children: [Text('📊', style: TextStyle(fontSize: 48)), const SizedBox(height: 12), const Text('暂无统计数据', style: TextStyle(fontSize: 16, color: AppColors.textSecondary))])));
            final totalFen = data.fold<int>(0, (s, c) => s + c.totalFen);
            return Column(children: [
              // 饼图
              _glassCard(
                isDark,
                child: Column(children: [
                  const Text('支出构成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: Stack(alignment: Alignment.center, children: [
                      PieChart(PieChartData(
                        sections: data.map((ce) => PieChartSectionData(value: ce.totalFen.toDouble(), color: _parseColor(ce.color), title: '', radius: 80)).toList(),
                        sectionsSpace: 3,
                        centerSpaceRadius: 50,
                      )),
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${data.length}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textPrimary)),
                        Text('个分类', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // 排行
              _glassCard(
                isDark,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('分类排行', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ...data.map((ce) {
                    final pct = totalFen > 0 ? ce.totalFen / totalFen * 100 : 0.0;
                    final color = _parseColor(ce.color);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(children: [
                        Row(children: [
                          Text('${ce.icon}', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ce.categoryName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                          Text(MoneyUtils.fenToShort(ce.totalFen), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: pct / 100),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => LinearProgressIndicator(value: v, backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 7),
                          ),
                        ),
                      ]),
                    );
                  }),
                ]),
              ),
            ]);
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.only(top: 60), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ]),
    );
  }

  Widget _glassCard(bool isDark, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF0F0F3)),
        boxShadow: [BoxShadow(color: (isDark ? Colors.black : const Color(0xFF2D6A4F)).withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
