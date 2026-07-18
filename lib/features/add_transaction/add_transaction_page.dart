import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';

/// 记账页面 — 全屏底部弹出式
class AddTransactionPage extends ConsumerStatefulWidget {
  final String? initialType;
  const AddTransactionPage({super.key, this.initialType});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  CategoryModel? _category;
  String _type = 'expense';
  int? _parentId;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'expense';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _amountCtrl.text.isNotEmpty &&
      double.tryParse(_amountCtrl.text) != null &&
      _category != null;

  void _submit() {
    final fen = MoneyUtils.yuanToFen(double.parse(_amountCtrl.text));
    final ds =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    ref
        .read(transactionListNotifierProvider.notifier)
        .addTransaction(
          amountFen: fen,
          categoryId: _category!.id,
          date: ds,
          description: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
          type: _type,
        );
    setState(() => _done = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildSuccess();

    final isExpense = _type == 'expense';
    final accent = isExpense ? AppColors.expense : AppColors.income;
    final parents = ref.watch(parentCategoriesProvider).valueOrNull ?? [];
    final filtered = _type == 'expense'
        ? parents.where((p) => p.name != '收入').toList()
        : parents.where((p) => p.name == '收入').toList();
    final subs = _parentId != null
        ? (ref.watch(subCategoriesProvider(_parentId!)).valueOrNull ?? [])
        : <CategoryModel>[];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('记一笔'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _valid ? _submit : null,
            child: const Text(
              '保存',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ━━ 类型切换 ━━
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'expense';
                        _category = null;
                        _parentId = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isExpense
                              ? AppColors.expense
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '💸 支出',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isExpense
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'income';
                        _category = null;
                        _parentId = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isExpense
                              ? AppColors.income
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '💰 收入',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: !isExpense
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ━━ 金额 ━━
            Center(
              child: TextField(
                controller: _amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHint.withOpacity(0.3),
                    letterSpacing: 0,
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '¥',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ━━ 日期 ━━
            _field(
              icon: Icons.calendar_today_rounded,
              label: AppDateUtils.toDisplayWithWeekday(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  helpText: '选择日期',
                  cancelText: '取消',
                  confirmText: '确定',
                );
                if (p != null) setState(() => _date = p);
              },
            ),

            const SizedBox(height: 20),

            // ━━ 分类 ━━
            Text(
              '选择分类',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              const Text('暂无分类', style: TextStyle(color: AppColors.textHint))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filtered.map((p) {
                  final sel = _parentId == p.id;
                  return ChoiceChip(
                    label: Text(
                      '${p.icon ?? ''} ${p.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? accent : AppColors.textPrimary,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => setState(() {
                      _parentId = p.id;
                      _category = null;
                    }),
                    selectedColor: accent.withOpacity(0.12),
                    side: BorderSide(color: sel ? accent : Colors.transparent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }).toList(),
              ),

            if (_parentId != null && subs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: subs.map((s) {
                  final sel = _category?.id == s.id;
                  return ChoiceChip(
                    label: Text(
                      '${s.icon ?? ''} ${s.name}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? accent : AppColors.textPrimary,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => setState(() => _category = s),
                    selectedColor: accent.withOpacity(0.12),
                    side: BorderSide(color: sel ? accent : Colors.transparent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 20),

            // ━━ 备注 ━━
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: '添加备注（可选）',
                prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, v, __) => Transform.scale(
            scale: v,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _type == 'expense'
                            ? AppColors.expense
                            : AppColors.income,
                        _type == 'expense'
                            ? const Color(0xFFF4A261)
                            : const Color(0xFF52B788),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_type == 'expense'
                                    ? AppColors.expense
                                    : AppColors.income)
                                .withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '已记录',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
