import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers/category_provider.dart';

/// 分类管理页面
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentCategoriesProvider);
    final subsAsync = ref.watch(allSubCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('分类管理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: () => _showAddDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增分类'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: parentsAsync.when(
            data: (parents) {
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: parents.length,
                itemBuilder: (context, index) => _buildCategoryGroup(parents[index], subsAsync),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGroup(CategoryModel parent, AsyncValue<List<CategoryWithParent>> subsAsync) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        leading: Text(parent.icon ?? '📁', style: const TextStyle(fontSize: 24)),
        title: Text(parent.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!parent.isDefault)
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.expense), onPressed: () => _confirmDelete(parent)),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showEditDialog(parent)),
          ],
        ),
        children: [
          subsAsync.when(
            data: (allSubs) {
              final subs = allSubs.where((s) => s.parentId == parent.id).toList();
              if (subs.isEmpty) {
                return const Padding(padding: EdgeInsets.all(16), child: Text('暂无小类', style: TextStyle(color: AppColors.textHint)));
              }
              return Column(
                children: [
                  const Divider(height: 1),
                  ...subs.map((sc) => ListTile(
                        leading: Text(sc.category.icon ?? '📌', style: const TextStyle(fontSize: 20)),
                        title: Text(sc.category.name, style: const TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showEditDialog(sc.category)),
                            if (!sc.category.isDefault)
                              IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.expense), onPressed: () => _confirmDelete(sc.category)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddDialog(parent),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加小类'),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => const Padding(padding: EdgeInsets.all(16), child: Text('加载失败')),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(CategoryModel? parent) {
    final nameController = TextEditingController();
    final iconController = TextEditingController(text: '📌');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(parent == null ? '新增大类' : '新增小类（${parent.name}）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '分类名称'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: iconController, decoration: const InputDecoration(labelText: '图标（emoji）', hintText: '输入一个emoji，如 🍚')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                ref.read(categoryListNotifierProvider.notifier).addCategory(
                      name: nameController.text.trim(),
                      icon: iconController.text.trim(),
                      parentId: parent?.id,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(CategoryModel category) {
    final nameController = TextEditingController(text: category.name);
    final iconController = TextEditingController(text: category.icon ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '分类名称')),
            const SizedBox(height: 12),
            TextField(controller: iconController, decoration: const InputDecoration(labelText: '图标（emoji）', hintText: '输入一个emoji')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final updated = CategoryModel(
                  id: category.id,
                  name: nameController.text.trim(),
                  icon: iconController.text.trim(),
                  parentId: category.parentId,
                  color: category.color,
                  sortOrder: category.sortOrder,
                  isDefault: category.isDefault,
                  createdAt: category.createdAt,
                  updatedAt: DateTime.now(),
                );
                ref.read(categoryListNotifierProvider.notifier).updateCategory(updated);
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${category.name}」吗？\n该分类下的交易记录不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(categoryListNotifierProvider.notifier).deleteCategory(category.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
