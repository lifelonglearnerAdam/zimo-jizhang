import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/category_provider.dart';

class TransactionDraft {
  final int amountFen;
  final String type;
  final CategoryModel category;
  final String date;
  final String? note;

  const TransactionDraft({
    required this.amountFen,
    required this.type,
    required this.category,
    required this.date,
    this.note,
  });
}

/// 记一笔弹窗 — 使用 Riverpod 自行加载分类数据
class AddTransactionDialog extends ConsumerStatefulWidget {
  final Future<void> Function(TransactionDraft draft) onSubmitted;
  final TransactionModel? transaction;

  const AddTransactionDialog({
    super.key,
    required this.onSubmitted,
    this.transaction,
  });

  @override
  ConsumerState<AddTransactionDialog> createState() =>
      _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  CategoryModel? _selectedCategory;
  String _type = 'expense';
  int? _selectedParentId;

  @override
  void initState() {
    super.initState();
    final existing = widget.transaction;
    if (existing != null) {
      _amountController.text = MoneyUtils.fenToYuan(
        existing.amountFen,
        showSymbol: false,
      );
      _noteController.text = existing.description ?? '';
      _selectedDate =
          DateTime.tryParse(existing.transactionDate) ?? DateTime.now();
      _type = existing.type;
      Future.microtask(_loadExistingCategory);
    }
    // 监听金额输入变化，确保确认按钮实时更新
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _amountController.text.isNotEmpty &&
      (double.tryParse(_amountController.text) ?? 0) > 0 &&
      _selectedCategory != null;

  Future<void> _loadExistingCategory() async {
    final id = widget.transaction?.categoryId;
    if (id == null) return;
    final categories = await ref.read(allCategoriesProvider.future);
    final category = categories.where((item) => item.id == id).firstOrNull;
    if (!mounted || category == null) return;
    setState(() {
      _selectedCategory = category;
      _selectedParentId = category.parentId ?? category.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == 'expense';
    final accentColor = isExpense ? AppColors.expense : AppColors.income;

    // 从 Riverpod 读取分类数据（所有 ref.watch 放在 build 顶层）
    final parentsAsync = ref.watch(parentCategoriesProvider);
    final subsAsync = _selectedParentId != null
        ? ref.watch(subCategoriesProvider(_selectedParentId!))
        : null;

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isExpense
                            ? AppColors.expenseGradient
                            : AppColors.incomeGradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isExpense ? Icons.remove_rounded : Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.transaction == null ? '记一笔' : '编辑记录',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 支出/收入切换
              Row(
                children: [
                  Expanded(
                    child: _buildTypeChip(
                      '支出',
                      'expense',
                      isExpense,
                      accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeChip(
                      '收入',
                      'income',
                      !isExpense,
                      accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 金额输入
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHint.withOpacity(0.4),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '¥',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),

              // 日期选择
              _buildField(
                icon: Icons.calendar_today_rounded,
                text:
                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                onTap: () => _pickDate(),
              ),
              const SizedBox(height: 12),

              // 分类选择 — 使用 AsyncValue 处理加载/数据/错误状态
              parentsAsync.when(
                data: (allParents) {
                  final filteredParents = _type == 'expense'
                      ? allParents.where((p) => p.name != '收入').toList()
                      : allParents.where((p) => p.name == '收入').toList();

                  if (filteredParents.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '暂无分类，请先在设置中添加',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }

                  final subs = subsAsync?.valueOrNull ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '选择大类',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filteredParents.map((p) {
                          final sel = _selectedParentId == p.id;
                          return ChoiceChip(
                            label: Text(
                              '${p.icon ?? ''} ${p.name}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: sel
                                    ? accentColor
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: sel,
                            onSelected: (_) => setState(() {
                              _selectedParentId = p.id;
                              _selectedCategory = null;
                            }),
                            selectedColor: accentColor.withOpacity(0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }).toList(),
                      ),

                      // 小类
                      if (_selectedParentId != null && subs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: subs.map((s) {
                            final sel = _selectedCategory?.id == s.id;
                            return ChoiceChip(
                              label: Text(
                                '${s.icon ?? ''} ${s.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: sel
                                      ? accentColor
                                      : AppColors.textPrimary,
                                ),
                              ),
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = s),
                              selectedColor: accentColor.withOpacity(0.12),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '分类加载失败',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 备注
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: '添加备注...',
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 提交
              ElevatedButton(
                onPressed: _isValid
                    ? () {
                        final amount = MoneyUtils.yuanToFen(
                          double.parse(_amountController.text),
                        );
                        final date =
                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
                        widget.onSubmitted(
                          TransactionDraft(
                            amountFen: amount,
                            type: _type,
                            category: _selectedCategory!,
                            date: date,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.transaction == null
                      ? (isExpense ? '确认支出' : '确认收入')
                      : '保存修改',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    String type,
    bool active,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: () => setState(() {
        _type = type;
        _selectedCategory = null;
        _selectedParentId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? accentColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? accentColor : Colors.grey.shade300,
            width: active ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? accentColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}
