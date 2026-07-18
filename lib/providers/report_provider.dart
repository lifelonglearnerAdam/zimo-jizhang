import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../data/models.dart';

/// 当前查看年份
final reportYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// 年度支出
final yearExpenseProvider = FutureProvider.autoDispose.family<int, int>((
  ref,
  year,
) async {
  final dao = TransactionDao();
  return dao.getYearTotalExpense(year);
});

/// 年度收入
final yearIncomeProvider = FutureProvider.autoDispose.family<int, int>((
  ref,
  year,
) async {
  final dao = TransactionDao();
  return dao.getYearTotalIncome(year);
});

/// 年度月支出趋势
final yearMonthlyExpensesProvider = FutureProvider.autoDispose
    .family<List<MonthlyTotal>, int>((ref, year) async {
      final dao = TransactionDao();
      return dao.getYearMonthlyExpenses(year);
    });

/// 年度月收入趋势
final yearMonthlyIncomeProvider = FutureProvider.autoDispose
    .family<List<MonthlyTotal>, int>((ref, year) async {
      final dao = TransactionDao();
      return dao.getYearMonthlyIncome(year);
    });

/// 年度分类汇总
final yearCategoryProvider = FutureProvider.autoDispose
    .family<List<CategoryExpense>, int>((ref, year) async {
      final dao = TransactionDao();
      return dao.getYearCategoryExpenses(year);
    });

/// 年度日均支出
final yearAvgDailyProvider = FutureProvider.autoDispose.family<double, int>((
  ref,
  year,
) async {
  final dao = TransactionDao();
  return dao.getYearAvgDailyExpense(year);
});
