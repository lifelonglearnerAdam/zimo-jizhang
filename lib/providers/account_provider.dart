import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';

/// 所有账户
final accountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dao = AccountDao();
  return dao.getAll();
});

/// 账户管理 Notifier
final accountListProvider = StateNotifierProvider<AccountNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return AccountNotifier();
});

class AccountNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  AccountNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final dao = AccountDao();
      await dao.seedDefaults();
      final accounts = await dao.getAll();
      state = AsyncValue.data(accounts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAccount(String name, String type) async {
    final dao = AccountDao();
    await dao.insert(name, type);
    await load();
  }

  Future<void> updateAccount(int id, String name) async {
    final dao = AccountDao();
    await dao.update(id, name);
    await load();
  }

  Future<void> deleteAccount(int id) async {
    final dao = AccountDao();
    await dao.softDelete(id);
    await load();
  }
}
