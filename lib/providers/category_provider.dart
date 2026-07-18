import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import 'database_provider.dart';

/// 所有大类
final parentCategoriesProvider = FutureProvider<List<CategoryModel>>((
  ref,
) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getParentCategories();
});

/// 所有小类（含父分类信息）
final allSubCategoriesProvider = FutureProvider<List<CategoryWithParent>>((
  ref,
) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getAllSubCategoriesWithParent();
});

/// 所有活跃分类
final allCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getAllActive();
});

/// 某大类下的小类
final subCategoriesProvider = FutureProvider.family<List<CategoryModel>, int>((
  ref,
  parentId,
) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getSubCategories(parentId);
});

/// 分类管理 Notifier
final categoryListNotifierProvider =
    StateNotifierProvider<
      CategoryListNotifier,
      AsyncValue<List<CategoryModel>>
    >((ref) {
      return CategoryListNotifier(ref);
    });

class CategoryListNotifier
    extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final Ref _ref;

  CategoryListNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final dao = _ref.read(categoryDaoProvider);
      final cats = await dao.getAllActive();
      state = AsyncValue.data(cats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCategory({
    required String name,
    required String icon,
    int? parentId,
    String? color,
  }) async {
    final dao = _ref.read(categoryDaoProvider);
    final current = await dao.getAllActive();
    final maxOrder = current
        .where((c) => c.parentId == parentId)
        .fold<int>(0, (max, c) => c.sortOrder > max ? c.sortOrder : max);

    await dao.insertWithData(
      name: name,
      icon: icon,
      parentId: parentId,
      color: color,
      sortOrder: maxOrder + 1,
    );
    await loadCategories();
    _ref.invalidate(parentCategoriesProvider);
    _ref.invalidate(allSubCategoriesProvider);
    _ref.invalidate(allCategoriesProvider);
    // 刷新对应大类下的小类列表（记一笔弹窗使用）
    if (parentId != null) {
      _ref.invalidate(subCategoriesProvider(parentId));
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    final dao = _ref.read(categoryDaoProvider);
    await dao.update(category);
    await loadCategories();
    _ref.invalidate(parentCategoriesProvider);
    _ref.invalidate(allSubCategoriesProvider);
    _ref.invalidate(allCategoriesProvider);
    // 刷新对应大类下的小类列表
    if (category.parentId != null) {
      _ref.invalidate(subCategoriesProvider(category.parentId!));
    }
  }

  Future<void> deleteCategory(int id) async {
    final dao = _ref.read(categoryDaoProvider);
    // 先查出分类信息，以便后续刷新对应的小类列表
    final cat = await dao.getById(id);
    final parentId = cat?.parentId;
    await dao.softDelete(id);
    await loadCategories();
    _ref.invalidate(parentCategoriesProvider);
    _ref.invalidate(allSubCategoriesProvider);
    _ref.invalidate(allCategoriesProvider);
    // 刷新对应大类下的小类列表
    if (parentId != null) {
      _ref.invalidate(subCategoriesProvider(parentId));
    }
  }
}
