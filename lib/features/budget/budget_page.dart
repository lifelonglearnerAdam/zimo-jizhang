import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';

/// 预算管理页面
class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  String _yearMonth = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(allBudgetsProvider(_yearMonth));
    final categoryExpenses = ref.watch(categoryExpensesProvider);
    final monthTotal = ref.watch(monthTotalProvider);
    final parents = ref.watch(parentCategoriesProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('预算管理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(_yearMonth, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 20),

        // 月总预算卡片
        budgetsAsync.when(
          data: (budgets) => monthTotal.when(
            data: (total) {
              final monthBudget = budgets[null];
              return _buildBudgetCard('📊 月度总预算', monthBudget, total, () => _showSetBudgetDialog(null, monthBudget));
            },
            loading: () => const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
            error: (_, __) => const SizedBox.shrink(),
          ),
          loading: () => const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 20),
        Text('分类预算', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 12),

        // 分类预算列表
        budgetsAsync.when(
          data: (budgets) => categoryExpenses.when(
            data: (expenses) {
              // 只显示支出大类
              final expenseParents = parents.where((p) => p.name != '收入').toList();
              if (expenseParents.isEmpty) {
                return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无分类', style: TextStyle(color: AppColors.textHint)))));
              }

              return Column(
                children: expenseParents.map((parent) {
                  // 汇总该大类下所有小类支出
                  final catTotal = expenses
                      .where((e) => e.categoryId == parent.id || false)
                      .fold<int>(0, (s, e) => s + e.totalFen);
                  // Actually we need to match by parent name
                  final matched = expenses.where((e) => e.categoryName == parent.name).firstOrNull;
                  final actualTotal = matched?.totalFen ?? catTotal;

                  final catBudget = budgets[parent.id];
                  return _buildBudgetCard('${parent.icon ?? ''} ${parent.name}', catBudget, actualTotal, () => _showSetBudgetDialog(parent.id, catBudget));
                }).toList(),
              );
            },
            loading: () => const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
            error: (_, __) => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _buildBudgetCard(String title, int? budget, int spent, VoidCallback onTap) {
    final hasBudget = budget != null && budget > 0;
    final ratio = hasBudget ? (spent / budget!).clamp(0.0, 1.0) : 0.0;
    final isOver = ratio >= 1.0;
    final isWarning = ratio >= 0.8 && ratio < 1.0;
    final color = isOver ? AppColors.expense : (isWarning ? Colors.orange : AppColors.primary);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (hasBudget)
                Text('${MoneyUtils.fenToYuan(spent)} / ${MoneyUtils.fenToYuan(budget!)}',
                    style: TextStyle(fontSize: 13, color: isOver ? AppColors.expense : AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ]),
            if (hasBudget) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: ratio, backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8),
              ),
              const SizedBox(height: 6),
              Text(
                isOver ? '⚠️ 已超预算 ${MoneyUtils.fenToYuan(spent - budget)}' : '剩余 ${MoneyUtils.fenToYuan(budget! - spent)} (${(ratio * 100).toStringAsFixed(0)}%)',
                style: TextStyle(fontSize: 12, color: isOver ? AppColors.expense : AppColors.textSecondary),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('点击设置预算', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              ),
          ]),
        ),
      ),
    );
  }

  void _showSetBudgetDialog(int? categoryId, int? currentBudget) {
    final controller = TextEditingController(
      text: currentBudget != null ? (currentBudget / 100).toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(categoryId == null ? '设置月度总预算' : '设置分类预算'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '预算金额（元）',
            prefixText: '¥ ',
            hintText: '例如：5000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (currentBudget != null) {
                ref.read(budgetNotifierProvider.notifier).deleteBudget(categoryId: categoryId);
              }
              Navigator.pop(ctx);
            },
            child: Text(currentBudget != null ? '清除预算' : '取消', style: const TextStyle(color: AppColors.expense)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                ref.read(budgetNotifierProvider.notifier).setBudget(categoryId: categoryId, amountFen: (amount * 100).round());
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
