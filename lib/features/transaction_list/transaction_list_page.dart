import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/amount_display.dart';

/// 交易列表 v2
class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});
  @override
  ConsumerState<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  final _searchCtrl = TextEditingController();
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    Future.microtask(() => ref.read(transactionListNotifierProvider.notifier).loadByMonth(_selectedMonth!));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListNotifierProvider);
    final allCats = ref.watch(allCategoriesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(children: [
      // 搜索 + 月份
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '搜索备注或交易对方...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _searchCtrl.clear(); _applyFilter(); }) : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF334155) : AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => v.isNotEmpty ? ref.read(transactionListNotifierProvider.notifier).search(v) : _applyFilter(),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: _buildMonthChips())),
        ]),
      ),

      // 列表
      Expanded(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.transactions.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('📝', style: TextStyle(fontSize: 48)), const SizedBox(height: 12), const Text('暂无记录', style: TextStyle(fontSize: 16, color: AppColors.textSecondary))])))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      _applyFilter();
                      await Future.delayed(const Duration(milliseconds: 200));
                    },
                    child: _buildGroupedList(state.transactions, allCats),
                  ),
      ),
    ]);
  }

  List<Widget> _buildMonthChips() {
    final now = DateTime.now();
    final chips = <Widget>[];
    for (var i = 0; i < 12; i++) {
      final m = DateTime(now.year, now.month - i, 1);
      final ms = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      final sel = _selectedMonth == ms;
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text('${m.month}月', style: const TextStyle(fontSize: 12)), selected: sel, onSelected: (_) { setState(() => _selectedMonth = ms); _applyFilter(); },
          selectedColor: AppColors.primaryLightest,
          labelStyle: TextStyle(color: sel ? AppColors.primary : AppColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
          visualDensity: VisualDensity.compact, side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ));
    }
    return chips;
  }

  void _applyFilter() {
    if (_selectedMonth != null) ref.read(transactionListNotifierProvider.notifier).loadByMonth(_selectedMonth!);
  }

  Widget _buildGroupedList(List<TransactionModel> txs, List<CategoryModel> cats) {
    final groups = <String, List<TransactionModel>>{};
    for (final tx in txs) {
      groups.putIfAbsent(tx.transactionDate, () => []).add(tx);
    }
    final dates = groups.keys.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date = dates[i];
        final dayTxs = groups[date]!;
        final dayTotal = dayTxs.fold<int>(0, (s, tx) => s + tx.amountFen);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(AppDateUtils.toDisplayWithWeekday(date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
              Text('支出 ${MoneyUtils.fenToYuan(dayTotal)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ]),
          ),
          ...dayTxs.map((tx) {
            final cat = cats.where((c) => c.id == tx.categoryId).firstOrNull;
            return Dismissible(
              key: Key(tx.id),
              direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3), child: const Icon(Icons.delete_rounded, color: Colors.white)),
              confirmDismiss: (_) async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('确认删除'), content: const Text('删除后无法恢复'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppColors.expense)))])),
              onDismissed: (_) => ref.read(transactionListNotifierProvider.notifier).deleteTransaction(tx.id),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF0F0F3)),
                ),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: tx.type == 'income' ? AppColors.incomeLight : AppColors.expenseLight, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(cat?.icon ?? '📌', style: const TextStyle(fontSize: 18))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat?.name ?? '未分类', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (tx.description != null && tx.description!.isNotEmpty) Text(tx.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  AmountDisplay(amountFen: tx.amountFen, size: AmountSize.small, type: tx.type),
                ]),
              ),
            );
          }),
        ]);
      },
    );
  }
}
