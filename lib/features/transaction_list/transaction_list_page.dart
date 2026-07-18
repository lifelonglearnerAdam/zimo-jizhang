import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../add_transaction/add_transaction_dialog.dart';

/// 全部交易明细：桌面端和移动端共用，所有记录都支持编辑与删除。
class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  final _searchCtrl = TextEditingController();
  String _selectedMonth = _monthKey(DateTime.now());
  String _typeFilter = 'all';

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _applyFilters());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref
        .read(transactionListNotifierProvider.notifier)
        .applyFilters(
          yearMonth: _selectedMonth,
          type: _typeFilter,
          keyword: _searchCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListNotifierProvider);
    final allCats =
        ref.watch(allCategoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(state),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
              ? _ErrorState(message: state.error!, onRetry: _applyFilters)
              : state.transactions.isEmpty
              ? _EmptyState(hasSearch: _searchCtrl.text.isNotEmpty)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => _applyFilters(),
                  child: _buildGroupedList(state.transactions, allCats, isDark),
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(TransactionListState state) {
    final months = List.generate(12, (index) {
      final date = DateTime(
        DateTime.now().year,
        DateTime.now().month - index,
        1,
      );
      return (_monthKey(date), date);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '交易明细',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '每一笔都清清楚楚',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${state.transactions.length} 笔',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: '搜索备注或交易对方',
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applyFilters();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: months.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, index) {
                      final (key, date) = months[index];
                      final selected = key == _selectedMonth;
                      return ChoiceChip(
                        label: Text('${date.month}月'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedMonth = key);
                          _applyFilters();
                        },
                        selectedColor: AppColors.primaryLightest,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('全部')),
                  ButtonSegment(value: 'expense', label: Text('支出')),
                  ButtonSegment(value: 'income', label: Text('收入')),
                ],
                selected: {_typeFilter},
                onSelectionChanged: (value) {
                  setState(() => _typeFilter = value.first);
                  _applyFilters();
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(
    List<TransactionModel> txs,
    List<CategoryModel> cats,
    bool isDark,
  ) {
    final groups = <String, List<TransactionModel>>{};
    for (final tx in txs) {
      groups.putIfAbsent(tx.transactionDate, () => []).add(tx);
    }
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: dates.length,
      itemBuilder: (_, index) {
        final date = dates[index];
        final dayTxs = groups[date]!;
        final expense = dayTxs
            .where((tx) => tx.type == 'expense')
            .fold<int>(0, (sum, tx) => sum + tx.amountFen);
        final income = dayTxs
            .where((tx) => tx.type == 'income')
            .fold<int>(0, (sum, tx) => sum + tx.amountFen);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 7),
              child: Row(
                children: [
                  Text(
                    AppDateUtils.toDisplayWithWeekday(date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (expense > 0)
                    Text(
                      '支出 ${MoneyUtils.fenToYuan(expense)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.expense,
                      ),
                    ),
                  if (income > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '收入 ${MoneyUtils.fenToYuan(income)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...dayTxs.map((tx) => _buildTransactionTile(tx, cats, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionTile(
    TransactionModel tx,
    List<CategoryModel> cats,
    bool isDark,
  ) {
    final cat = cats.where((item) => item.id == tx.categoryId).firstOrNull;
    final accent = tx.type == 'income' ? AppColors.income : AppColors.expense;
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(tx),
      onDismissed: (_) => _deleteWithUndo(tx),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _editTransaction(tx),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    cat?.icon ?? '📌',
                    style: const TextStyle(fontSize: 19),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat?.name ?? '未分类',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (tx.description != null && tx.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            tx.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${tx.type == 'income' ? '+' : '-'}${MoneyUtils.fenToYuan(tx.amountFen)}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '记录操作',
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') _editTransaction(tx);
                    if (value == 'delete') _deleteFromMenu(tx);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('编辑记录'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                        ),
                        title: Text('删除记录'),
                        contentPadding: EdgeInsets.zero,
                      ),
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

  Future<bool> _confirmDelete(TransactionModel tx) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除这笔记录？'),
            content: Text(
              '${MoneyUtils.fenToYuan(tx.amountFen)} · ${tx.description?.isNotEmpty == true ? tx.description : '删除后可在提示中撤销'}',
            ),
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
  }

  Future<void> _deleteFromMenu(TransactionModel tx) async {
    if (await _confirmDelete(tx)) _deleteWithUndo(tx);
  }

  void _deleteWithUndo(TransactionModel tx) {
    ref.read(transactionListNotifierProvider.notifier).deleteTransaction(tx.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('记录已删除'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => ref
              .read(transactionListNotifierProvider.notifier)
              .restoreTransaction(tx.id),
        ),
      ),
    );
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
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.receipt_long_outlined,
            size: 52,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch ? '没有找到匹配的记录' : '这个月还没有记录',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch ? '换个关键词试试' : '点击右下角“记一笔”开始',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 42,
          color: AppColors.textHint,
        ),
        const SizedBox(height: 10),
        const Text('记录加载失败'),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
        if (message.isNotEmpty)
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
      ],
    ),
  );
}
