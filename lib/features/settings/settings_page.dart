import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/file_saver.dart';
import '../../providers/database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/account_provider.dart';
import '../categories/categories_page.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tm = ref.watch(themeModeProvider);
    final accounts = ref.watch(accountListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 20),
      _sec(isDark, '外观', [
        _radio(Icons.light_mode, '浅色', AppThemeMode.light, tm, ref),
        _radio(Icons.dark_mode, '深色', AppThemeMode.dark, tm, ref),
        _radio(Icons.settings_brightness, '跟随系统', AppThemeMode.system, tm, ref),
      ]),
      _sec(isDark, '支付账户', [
        accounts.when(
          data: (list) => Column(children: [
            ...list.map((a) => ListTile(leading: Icon(_acIcon(a['type']), color: AppColors.primary, size: 20), title: Text(a['name'], style: const TextStyle(fontSize: 14)), trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.expense), onPressed: () => ref.read(accountListProvider.notifier).deleteAccount(a['id'])))),
            _link(Icons.add, '添加账户', () => _addAccount(context, ref)),
          ]),
          loading: () => const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => const Text('加载失败'),
        ),
      ]),
      _sec(isDark, '功能', [
        _link(Icons.file_download_rounded, '导入账单', () => GoRouter.of(context).push('/import')),
        _link(Icons.cloud_sync_rounded, '数据同步', () => GoRouter.of(context).push('/sync')),
        _link(Icons.keyboard_voice_rounded, '语音记账', () => GoRouter.of(context).push('/voice')),
        _link(Icons.receipt_long_rounded, '截图识别', () => GoRouter.of(context).push('/ocr')),
        _link(Icons.repeat_rounded, '定期记账', () => GoRouter.of(context).push('/recurring')),
        _link(Icons.category_rounded, '分类管理', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesPage()))),
        _link(Icons.download_rounded, '导出 CSV', () => _exportCSV(context, ref)),
        _link(Icons.backup_rounded, '备份数据库', () => _backup(context, ref)),
      ]),
      _sec(isDark, '关于', [
        ListTile(leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: const Text('墨', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))), title: const Text('子墨记账'), subtitle: const Text('版本 1.0')),
      ]),
      const SizedBox(height: 40),
    ]);
  }
  Widget _sec(bool isDark, String t, List<Widget> c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E8ED))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))), ...c, const SizedBox(height: 4)])));
  Widget _radio(IconData i, String l, AppThemeMode v, AppThemeMode g, WidgetRef ref) => ListTile(leading: Icon(i, color: AppColors.primary, size: 20), title: Text(l, style: const TextStyle(fontSize: 14)), trailing: Radio<AppThemeMode>(value: v, groupValue: g, onChanged: (x) => ref.read(themeModeProvider.notifier).setThemeMode(x!)), onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(v));
  Widget _link(IconData i, String l, VoidCallback t) => ListTile(leading: Icon(i, color: AppColors.primary, size: 20), title: Text(l, style: const TextStyle(fontSize: 14)), trailing: const Icon(Icons.chevron_right, size: 18), onTap: t);
  IconData _acIcon(String t) => switch (t) { 'wechat' => Icons.chat, 'alipay' => Icons.account_balance_wallet, 'cash' => Icons.money, 'bank_card' => Icons.credit_card, 'credit_card' => Icons.credit_card, _ => Icons.account_balance };
  void _addAccount(BuildContext ctx, WidgetRef ref) { final ctrl = TextEditingController(); var t = 'bank_card'; showDialog(context: ctx, builder: (c) => StatefulBuilder(builder: (c, s) => AlertDialog(title: const Text('添加账户'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: ctrl, decoration: const InputDecoration(labelText: '名称'), autofocus: true), const SizedBox(height: 12), DropdownButtonFormField(value: t, items: const [DropdownMenuItem(value: 'bank_card', child: Text('银行卡')), DropdownMenuItem(value: 'wechat', child: Text('微信')), DropdownMenuItem(value: 'alipay', child: Text('支付宝')), DropdownMenuItem(value: 'cash', child: Text('现金')), DropdownMenuItem(value: 'credit_card', child: Text('信用卡'))], onChanged: (v) => s(() => t = v!))]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')), ElevatedButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { ref.read(accountListProvider.notifier).addAccount(ctrl.text.trim(), t); Navigator.pop(c); } }, child: const Text('添加'))]))); }
  void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _exportCSV(BuildContext c, WidgetRef ref) async {
    try {
      final txs = await ref.read(transactionDaoProvider).getAll();
      if (txs.isEmpty) { _snack(c, '暂无数据'); return; }
      final rows = <List<String>>[['日期','类型','金额','分类ID','备注','交易对方']];
      for (final t in txs) {
        rows.add([t.transactionDate, t.type == 'expense' ? '支出' : '收入', MoneyUtils.fenToYuan(t.amountFen, showSymbol: false), t.categoryId?.toString() ?? '', t.description ?? '', t.counterparty ?? '']);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final fn = '子墨记账_${_dateStamp()}.csv';
      final path = await saveTextFile(fn, csv);
      _snack(c, path != null ? '已导出: $path' : '已下载: $fn');
    } catch (e) { _snack(c, '导出失败: $e'); }
  }

  Future<void> _backup(BuildContext c, WidgetRef ref) async {
    try {
      final txs = await ref.read(transactionDaoProvider).getAll();
      if (txs.isEmpty) { _snack(c, '暂无数据'); return; }
      final data = txs.map((t) => {
        'id': t.id, 'amount_fen': t.amountFen, 'type': t.type,
        'category_id': t.categoryId, 'transaction_date': t.transactionDate,
        'description': t.description, 'counterparty': t.counterparty,
        'payment_method': t.paymentMethod, 'source': t.source,
        'updated_at': t.updatedAt.toIso8601String(),
      }).toList();
      final encoder = JsonEncoder.withIndent('  ');
      final json = '${encoder.convert({
        'version': 1, 'exported_at': DateTime.now().toIso8601String(),
        'count': txs.length, 'transactions': data,
      })}';
      final fn = '子墨记账_备份_${_dateStamp()}.json';
      final path = await saveTextFile(fn, json);
      _snack(c, path != null ? '已备份: $path' : '已下载: $fn');
    } catch (e) { _snack(c, '备份失败: $e'); }
  }

  String _dateStamp() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2,'0')}${n.day.toString().padLeft(2,'0')}';
  }
}
