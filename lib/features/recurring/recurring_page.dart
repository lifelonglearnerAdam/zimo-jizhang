import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../providers/category_provider.dart';
import '../../providers/database_provider.dart';

/// 定期记账页面
class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recurringList = ref.watch(_recurringProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('定期记账'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: recurringList.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('📅', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('还没有定期账单', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                const Text('房租、订阅、贷款…设置后到期自动提醒',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加定期账单'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: recurringList.length,
              itemBuilder: (ctx, i) => _buildRecurringCard(recurringList[i], isDark),
            ),
      floatingActionButton: recurringList.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showEditDialog(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildRecurringCard(RecurringTransaction rt, bool isDark) {
    final allCats = ref.watch(allCategoriesProvider).valueOrNull ?? [];
    final cat = allCats.where((c) => c.id == rt.categoryId).firstOrNull;
    final freqLabel = {'daily': '每天', 'weekly': '每周', 'monthly': '每月', 'yearly': '每年'}[rt.frequency] ?? rt.frequency;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: rt.type == 'income' ? AppColors.incomeLight : AppColors.expenseLight,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(cat?.icon ?? (rt.type == 'income' ? '💰' : '💸'), style: const TextStyle(fontSize: 20)),
        ),
        title: Text(rt.description ?? (cat?.name ?? '未分类'),
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${AppDateUtils.toDisplay(rt.nextDueDate)} · $freqLabel · ¥${(rt.amountFen / 100).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textSecondary),
          onPressed: () => ref.read(recurringTransactionDaoProvider).delete(rt.id!),
        ),
      ),
    );
  }

  void _showEditDialog({RecurringTransaction? existing}) {
    final amountCtrl = TextEditingController(
        text: existing != null ? (existing.amountFen / 100).toStringAsFixed(2) : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String freq = existing?.frequency ?? 'monthly';
    String type = existing?.type ?? 'expense';
    DateTime dueDate = existing != null
        ? DateTime.parse(existing.nextDueDate)
        : DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(existing != null ? '编辑定期账单' : '添加定期账单'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '金额', prefixText: '¥'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: '描述（如：房租、Netflix）'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('💸 支出')),
                  DropdownMenuItem(value: 'income', child: Text('💰 收入')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
                decoration: const InputDecoration(labelText: '类型'),
              ),
              DropdownButtonFormField<String>(
                value: freq,
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('每天')),
                  DropdownMenuItem(value: 'weekly', child: Text('每周')),
                  DropdownMenuItem(value: 'monthly', child: Text('每月')),
                  DropdownMenuItem(value: 'yearly', child: Text('每年')),
                ],
                onChanged: (v) => setDialogState(() => freq = v!),
                decoration: const InputDecoration(labelText: '频率'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null) return;
                final dao = ref.read(recurringTransactionDaoProvider);
                final dateStr = '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
                await dao.insert(RecurringTransaction(
                  amountFen: (amount * 100).round(),
                  type: type,
                  frequency: freq,
                  nextDueDate: dateStr,
                  description: descCtrl.text.isNotEmpty ? descCtrl.text : null,
                  createdAt: DateTime.now(),
                ));
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('保存'),
            ),
          ],
        );
      }),
    );
  }
}

/// 定期交易 Provider
final _recurringProvider = FutureProvider<List<RecurringTransaction>>((ref) async {
  final dao = ref.watch(recurringTransactionDaoProvider);
  return dao.getAllActive();
});
