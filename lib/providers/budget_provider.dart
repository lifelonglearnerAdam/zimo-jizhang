import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';

/// 某月预算（分）
final budgetProvider = FutureProvider.family<int?, String>((
  ref,
  yearMonth,
) async {
  final dao = BudgetDao();
  return dao.getBudget(yearMonth: yearMonth);
});

/// 某月所有预算（含分类预算）
final allBudgetsProvider = FutureProvider.family<Map<int?, int>, String>((
  ref,
  yearMonth,
) async {
  final dao = BudgetDao();
  return dao.getAllBudgets(yearMonth);
});

/// 预算管理 Notifier
final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<Map<int?, int>>>((ref) {
      return BudgetNotifier(ref);
    });

class BudgetNotifier extends StateNotifier<AsyncValue<Map<int?, int>>> {
  final Ref _ref;
  String _yearMonth = '';

  BudgetNotifier(this._ref) : super(const AsyncValue.loading()) {
    final now = DateTime.now();
    _yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    loadBudgets();
  }

  Future<void> loadBudgets() async {
    state = const AsyncValue.loading();
    try {
      final dao = BudgetDao();
      final budgets = await dao.getAllBudgets(_yearMonth);
      state = AsyncValue.data(budgets);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setBudget({int? categoryId, required int amountFen}) async {
    final dao = BudgetDao();
    await dao.setBudget(
      categoryId: categoryId,
      amountFen: amountFen,
      yearMonth: _yearMonth,
    );
    // 刷新预算列表 provider
    _ref.invalidate(allBudgetsProvider(_yearMonth));
    await loadBudgets();
  }

  Future<void> deleteBudget({int? categoryId}) async {
    final dao = BudgetDao();
    await dao.deleteBudget(categoryId: categoryId, yearMonth: _yearMonth);
    // 刷新预算列表 provider
    _ref.invalidate(allBudgetsProvider(_yearMonth));
    await loadBudgets();
  }
}
