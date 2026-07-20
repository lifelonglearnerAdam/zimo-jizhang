import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/file_saver.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/account_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../categories/categories_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accounts = ref.watch(accountListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 48),
      children: [
        const Text(
          '设置',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          '把应用调整成适合你的样子',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final sections = [
              Expanded(
                child: _appearanceSection(context, ref, themeMode, isDark),
              ),
              Expanded(child: _accountSection(context, ref, accounts, isDark)),
            ];
            return constraints.maxWidth >= 780
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sections[0],
                      const SizedBox(width: 16),
                      sections[1],
                    ],
                  )
                : Column(
                    children: [
                      _appearanceSection(context, ref, themeMode, isDark),
                      _accountSection(context, ref, accounts, isDark),
                    ],
                  );
          },
        ),
        _section(context, '数据与工具', '导入、备份和管理你的账本', [
          _tool(
            context,
            Icons.file_upload_outlined,
            '导入账单',
            '微信、支付宝或通用 CSV',
            () => context.push('/import'),
          ),
          _tool(
            context,
            Icons.repeat_rounded,
            '定期记账',
            '设置固定的房租、订阅等记录',
            () => context.push('/recurring'),
          ),
          _tool(
            context,
            Icons.category_outlined,
            '分类管理',
            '调整大类和小类',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesPage()),
            ),
          ),
          _tool(
            context,
            Icons.download_outlined,
            '导出 CSV',
            '导出全部未删除记录，Excel 可打开',
            () => _exportCSV(context, ref),
          ),
          _tool(
            context,
            Icons.backup_outlined,
            '备份账本',
            '生成一份可在其他设备合并的备份',
            () => _backup(context, ref),
          ),
          _tool(
            context,
            Icons.restore_outlined,
            '恢复备份',
            '只导入备份里尚不存在的记录',
            () => _restoreBackup(context, ref),
          ),
        ]),
        _section(context, '关于子墨记账', '专注于本地、清楚、舒服的记账体验', [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                '墨',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: const Text(
              '子墨记账 2.0',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('本地存储 · 不上传账目 · 版本 2.0.1'),
          ),
        ]),
      ],
    );
  }

  Widget _appearanceSection(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode mode,
    bool isDark,
  ) {
    return _section(context, '外观', '选择你喜欢的显示方式', [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SegmentedButton<AppThemeMode>(
          segments: const [
            ButtonSegment(value: AppThemeMode.light, label: Text('浅色')),
            ButtonSegment(value: AppThemeMode.dark, label: Text('深色')),
            ButtonSegment(value: AppThemeMode.system, label: Text('自动')),
          ],
          selected: {mode},
          onSelectionChanged: (value) =>
              ref.read(themeModeProvider.notifier).setThemeMode(value.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ),
    ]);
  }

  Widget _accountSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> accounts,
    bool isDark,
  ) {
    return _section(context, '支付账户', '仅用于标记交易来源，不会影响已有账目', [
      accounts.when(
        data: (items) => Column(
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '还没有添加账户',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ...items.map(
              (account) => ListTile(
                dense: true,
                leading: Icon(
                  _accountIcon(account['type'] as String? ?? ''),
                  color: AppColors.primary,
                  size: 20,
                ),
                title: Text(
                  account['name'] as String? ?? '未命名账户',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: IconButton(
                  tooltip: '删除账户',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _deleteAccount(context, ref, account),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded, color: AppColors.primary),
              title: const Text(
                '添加账户',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _addAccount(context, ref),
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '账户加载失败',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    ]);
  }

  Widget _section(
    BuildContext context,
    String title,
    String subtitle,
    List<Widget> children,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _tool(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: AppColors.primary, size: 21),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      size: 19,
      color: AppColors.textHint,
    ),
    onTap: onTap,
  );

  IconData _accountIcon(String type) => switch (type) {
    'wechat' => Icons.chat_bubble_outline_rounded,
    'alipay' => Icons.account_balance_wallet_outlined,
    'cash' => Icons.payments_outlined,
    'credit_card' || 'bank_card' => Icons.credit_card_outlined,
    _ => Icons.account_balance_outlined,
  };

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    var type = 'bank_card';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加支付账户'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '账户名称',
                  hintText: '例如：招商银行卡',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: '账户类型'),
                items: const [
                  DropdownMenuItem(value: 'bank_card', child: Text('银行卡')),
                  DropdownMenuItem(value: 'wechat', child: Text('微信')),
                  DropdownMenuItem(value: 'alipay', child: Text('支付宝')),
                  DropdownMenuItem(value: 'cash', child: Text('现金')),
                  DropdownMenuItem(value: 'credit_card', child: Text('信用卡')),
                ],
                onChanged: (value) => setState(() => type = value ?? type),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                ref.read(accountListProvider.notifier).addAccount(name, type);
                Navigator.pop(dialogContext);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> account,
  ) async {
    final name = account['name'] as String? ?? '这个账户';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除支付账户？'),
            content: Text('删除「$name」不会删除已有交易记录。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed)
      ref.read(accountListProvider.notifier).deleteAccount(account['id']);
  }

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _exportCSV(BuildContext context, WidgetRef ref) async {
    try {
      final txs = await ref.read(transactionDaoProvider).getAll();
      if (txs.isEmpty) {
        _snack(context, '暂无可导出的记录');
        return;
      }
      final categories = await ref.read(categoryDaoProvider).getAllActive();
      final names = {
        for (final category in categories)
          category.id: '${category.icon ?? ''}${category.name}',
      };
      final rows = <List<String>>[
        ['日期', '类型', '金额（元）', '分类', '备注', '交易对方', '支付方式'],
        for (final tx in txs)
          [
            tx.transactionDate,
            tx.type == 'expense' ? '支出' : '收入',
            MoneyUtils.fenToYuan(tx.amountFen, showSymbol: false),
            names[tx.categoryId] ?? '未分类',
            tx.description ?? '',
            tx.counterparty ?? '',
            tx.paymentMethod ?? '',
          ],
      ];
      final csv = '\uFEFF${const ListToCsvConverter().convert(rows)}';
      final fileName = '子墨记账_${_dateStamp()}.csv';
      final path = await saveTextFile(fileName, csv);
      _snack(context, path == null ? '已下载 $fileName' : '已导出到 $path');
    } catch (error) {
      _snack(context, '导出失败：$error');
    }
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    try {
      final txs = await ref.read(transactionDaoProvider).getAll();
      if (txs.isEmpty) {
        _snack(context, '暂无可备份的记录');
        return;
      }
      final json = const JsonEncoder.withIndent('  ').convert({
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
        'count': txs.length,
        'transactions': txs
            .map(
              (tx) => {
                'id': tx.id,
                'amount_fen': tx.amountFen,
                'type': tx.type,
                'category_id': tx.categoryId,
                'transaction_date': tx.transactionDate,
                'description': tx.description,
                'counterparty': tx.counterparty,
                'payment_method': tx.paymentMethod,
                'source': tx.source,
                'import_batch_id': tx.importBatchId,
                'external_id': tx.externalId,
                'created_at': tx.createdAt.toIso8601String(),
                'updated_at': tx.updatedAt.toIso8601String(),
              },
            )
            .toList(),
      });
      final fileName = '子墨记账_备份_${_dateStamp()}.json';
      final path = await saveTextFile(fileName, json);
      _snack(context, path == null ? '已下载 $fileName' : '已备份到 $path');
    } catch (error) {
      _snack(context, '备份失败：$error');
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        _snack(context, '无法读取备份文件');
        return;
      }
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final rawRows = decoded['transactions'];
      if (rawRows is! List) {
        _snack(context, '这不是有效的子墨记账备份');
        return;
      }
      final rows = rawRows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final count = await ref.read(transactionDaoProvider).restoreBackup(rows);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(monthTotalProvider);
      ref.invalidate(monthIncomeProvider);
      ref.invalidate(categoryExpensesProvider);
      _snack(context, count == 0 ? '没有新的记录需要恢复' : '已合并 $count 笔新记录，原有记录未改变');
    } catch (error) {
      _snack(context, '恢复失败：请确认文件来自子墨记账');
    }
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
}
