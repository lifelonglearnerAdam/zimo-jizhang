import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import 'database_provider.dart';

/// 今日交易记录
final todayTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getToday();
});

/// 今日支出合计
final todayTotalProvider = FutureProvider<int>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getTodayTotalExpense();
});

/// 本月支出合计
final monthTotalProvider = FutureProvider<int>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getMonthTotalExpense();
});

/// 本月收入合计
final monthIncomeProvider = FutureProvider<int>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getMonthTotalIncome();
});

/// 上月支出合计
final lastMonthTotalProvider = FutureProvider<int>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getLastMonthTotalExpense();
});

/// 本月交易笔数
final monthCountProvider = FutureProvider<int>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getMonthTransactionCount();
});

/// 本月按大类支出汇总
final categoryExpensesProvider = FutureProvider<List<CategoryExpense>>((ref) async {
  final now = DateTime.now();
  final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final dao = ref.watch(transactionDaoProvider);
  return dao.getCategoryExpensesByMonth(yearMonth);
});

/// 某月交易记录
final monthTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, yearMonth) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getByMonth(yearMonth);
});

/// 所有交易记录
final allTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getAll(limit: 100);
});

/// 交易记录管理 Notifier
final transactionListNotifierProvider =
    StateNotifierProvider<TransactionListNotifier, TransactionListState>((ref) {
  return TransactionListNotifier(ref);
});

class TransactionListState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;

  const TransactionListState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  TransactionListState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
  }) {
    return TransactionListState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TransactionListNotifier extends StateNotifier<TransactionListState> {
  final Ref _ref;

  TransactionListNotifier(this._ref) : super(const TransactionListState()) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true);
    try {
      final dao = _ref.read(transactionDaoProvider);
      final txs = await dao.getAll(limit: 100);
      state = TransactionListState(transactions: txs);
    } catch (e) {
      state = TransactionListState(error: e.toString());
    }
  }

  Future<void> addTransaction({
    required int amountFen,
    required int categoryId,
    required String date,
    String? description,
    String? paymentMethod,
    String type = 'expense',
  }) async {
    final dao = _ref.read(transactionDaoProvider);
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    await dao.insertWithData(
      id: id,
      amountFen: amountFen,
      categoryId: categoryId,
      date: date,
      description: description,
      paymentMethod: paymentMethod,
      type: type,
    );

    await loadTransactions();
    _ref.invalidate(todayTransactionsProvider);
    _ref.invalidate(todayTotalProvider);
    _ref.invalidate(monthTotalProvider);
    _ref.invalidate(monthIncomeProvider);
    _ref.invalidate(monthCountProvider);
    _ref.invalidate(categoryExpensesProvider);
  }

  Future<void> deleteTransaction(String id) async {
    final dao = _ref.read(transactionDaoProvider);
    await dao.softDelete(id);
    await loadTransactions();
    _ref.invalidate(todayTransactionsProvider);
    _ref.invalidate(todayTotalProvider);
    _ref.invalidate(monthTotalProvider);
    _ref.invalidate(monthIncomeProvider);
    _ref.invalidate(monthCountProvider);
    _ref.invalidate(categoryExpensesProvider);
  }

  Future<void> search(String keyword) async {
    if (keyword.isEmpty) {
      await loadTransactions();
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final dao = _ref.read(transactionDaoProvider);
      final txs = await dao.search(keyword);
      state = TransactionListState(transactions: txs);
    } catch (e) {
      state = TransactionListState(error: e.toString());
    }
  }

  Future<void> loadByMonth(String yearMonth) async {
    state = state.copyWith(isLoading: true);
    try {
      final dao = _ref.read(transactionDaoProvider);
      final txs = await dao.getByMonth(yearMonth);
      state = TransactionListState(transactions: txs);
    } catch (e) {
      state = TransactionListState(error: e.toString());
    }
  }
}

/// 当前选中的月份
final selectedMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});
