import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../core/theme.dart';
import '../providers/category_provider.dart';

/// 分类选择器 — 两级联动
class CategoryPicker extends ConsumerStatefulWidget {
  final int? selectedSubCategoryId;
  final ValueChanged<CategoryModel> onSelected;

  const CategoryPicker({
    super.key,
    this.selectedSubCategoryId,
    required this.onSelected,
  });

  @override
  ConsumerState<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<CategoryPicker> {
  int? _selectedParentId;
  CategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadInitialSelection();
  }

  Future<void> _loadInitialSelection() async {
    if (widget.selectedSubCategoryId == null) return;
    await Future.delayed(const Duration(milliseconds: 100));
    final allSubs = ref.read(allSubCategoriesProvider).valueOrNull ?? [];
    for (final sc in allSubs) {
      if (sc.category.id == widget.selectedSubCategoryId) {
        setState(() {
          _selectedParentId = sc.parentId;
          _selectedCategory = sc.category;
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentCategoriesProvider);
    final subsAsync = _selectedParentId != null
        ? ref.watch(subCategoriesProvider(_selectedParentId!))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '选择分类',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        parentsAsync.when(
          data: (parents) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: parents.map((p) {
              final isSelected = _selectedParentId == p.id;
              return ChoiceChip(
                label: Text('${p.icon ?? ''} ${p.name}'),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedParentId = p.id;
                    _selectedCategory = null;
                  });
                  ref.invalidate(subCategoriesProvider(p.id));
                },
                selectedColor: AppColors.primaryLightest,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载分类失败: $e'),
        ),

        if (_selectedParentId != null && subsAsync != null) ...[
          const SizedBox(height: 16),
          Text(
            '选择小类',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          subsAsync.when(
            data: (subs) {
              if (subs.isEmpty) {
                return Text(
                  '该分类下暂无小类',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subs.map((s) {
                  final isSelected = _selectedCategory?.id == s.id;
                  return ChoiceChip(
                    label: Text('${s.icon ?? ''} ${s.name}'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = s);
                      widget.onSelected(s);
                    },
                    selectedColor: AppColors.primaryLightest,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text('加载小类失败'),
          ),
        ],
      ],
    );
  }
}
