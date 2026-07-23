import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/models.dart';
import 'account_provider.dart';

class WealthSummary {
  final int assetsFen;
  final int liabilitiesFen;
  final int netWorthFen;
  final int monthIncomeFen;
  final int monthExpenseFen;
  final int accountCount;

  const WealthSummary({
    required this.assetsFen,
    required this.liabilitiesFen,
    required this.netWorthFen,
    required this.monthIncomeFen,
    required this.monthExpenseFen,
    required this.accountCount,
  });

  int get monthSavingsFen => monthIncomeFen - monthExpenseFen;

  double get savingsRate => monthIncomeFen <= 0
      ? 0
      : (monthSavingsFen / monthIncomeFen).clamp(-1.0, 1.0);
}

final wealthSummaryProvider = FutureProvider<WealthSummary>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final txDao = TransactionDao();
  final monthIncome = await txDao.getMonthTotalIncome();
  final monthExpense = await txDao.getMonthTotalExpense();

  var assets = 0;
  var liabilities = 0;
  for (final account in accounts) {
    if ((account['include_in_net_worth'] as int? ?? 1) != 1) continue;
    final balance = (account['balance_fen'] as num? ?? 0).toInt();
    if (account['type'] == 'credit_card') {
      liabilities += balance.abs();
    } else {
      assets += balance;
    }
  }

  return WealthSummary(
    assetsFen: assets,
    liabilitiesFen: liabilities,
    netWorthFen: assets - liabilities,
    monthIncomeFen: monthIncome,
    monthExpenseFen: monthExpense,
    accountCount: accounts.length,
  );
});

final financialGoalsProvider = FutureProvider<List<FinancialGoal>>((ref) async {
  return FinancialGoalDao().getAll();
});

final wealthActionsProvider = Provider<WealthActions>((ref) {
  return WealthActions(ref);
});

class WealthActions {
  final Ref _ref;

  WealthActions(this._ref);

  Future<void> updateAccount({
    required int id,
    required String name,
    required int balanceFen,
    required bool includeInNetWorth,
  }) async {
    await AccountDao().updateFinancialProfile(
      id: id,
      name: name,
      balanceFen: balanceFen,
      includeInNetWorth: includeInNetWorth,
    );
    _ref.invalidate(accountsProvider);
    _ref.invalidate(wealthSummaryProvider);
  }

  Future<void> addGoal({
    required String name,
    required int targetFen,
    required int currentFen,
    String? targetDate,
    String icon = '🎯',
  }) async {
    final now = DateTime.now();
    await FinancialGoalDao().insert(
      FinancialGoal(
        name: name,
        targetFen: targetFen,
        currentFen: currentFen,
        targetDate: targetDate,
        icon: icon,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _ref.invalidate(financialGoalsProvider);
  }

  Future<void> updateGoalProgress(int id, int currentFen) async {
    await FinancialGoalDao().updateProgress(id, currentFen);
    _ref.invalidate(financialGoalsProvider);
  }

  Future<void> deleteGoal(int id) async {
    await FinancialGoalDao().softDelete(id);
    _ref.invalidate(financialGoalsProvider);
  }
}
