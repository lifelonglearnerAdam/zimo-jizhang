import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';

/// 分类 DAO Provider
final categoryDaoProvider = Provider<CategoryDao>((ref) {
  return CategoryDao();
});

/// 交易 DAO Provider
final transactionDaoProvider = Provider<TransactionDao>((ref) {
  return TransactionDao();
});

/// 预算 DAO Provider
final budgetDaoProvider = Provider<BudgetDao>((ref) {
  return BudgetDao();
});

/// 账户 DAO Provider
final accountDaoProvider = Provider<AccountDao>((ref) {
  return AccountDao();
});

/// 导入批次 DAO Provider
final importBatchDaoProvider = Provider<ImportBatchDao>((ref) {
  return ImportBatchDao();
});

/// 导入规则 DAO Provider
final importRuleDaoProvider = Provider<ImportRuleDao>((ref) {
  return ImportRuleDao();
});

/// 定期交易 DAO Provider
final recurringTransactionDaoProvider = Provider<RecurringTransactionDao>((ref) {
  return RecurringTransactionDao();
});
