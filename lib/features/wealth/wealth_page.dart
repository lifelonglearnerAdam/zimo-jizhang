import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../providers/account_provider.dart';
import '../../providers/wealth_provider.dart';

class WealthPage extends ConsumerWidget {
  const WealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(wealthSummaryProvider);
    final accounts = ref.watch(accountsProvider);
    final goals = ref.watch(financialGoalsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeader(context),
                const SizedBox(height: 18),
                summary.when(
                  data: (value) => _summaryBand(context, value),
                  loading: () => const SizedBox(
                    height: 190,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => _errorBand('财富数据加载失败'),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final accountSection = _accountsSection(
                      context,
                      ref,
                      accounts,
                    );
                    final goalSection = _goalsSection(context, ref, goals);
                    if (constraints.maxWidth >= 860) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: accountSection),
                          const SizedBox(width: 18),
                          Expanded(flex: 5, child: goalSection),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        accountSection,
                        const SizedBox(height: 22),
                        goalSection,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _budgetBand(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pageHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '财富中心',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '看清资产、负债与目标',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '账户设置',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }

  Widget _summaryBand(BuildContext context, WealthSummary value) {
    final rate = (value.savingsRate * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadows.elevated,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final netWorth = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFFB9D6C5),
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Text(
                    '当前净资产',
                    style: TextStyle(
                      color: Color(0xFFDCEBE2),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  MoneyUtils.fenToYuan(value.netWorthFen),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                value.accountCount == 0
                    ? '添加账户余额后开始追踪'
                    : '已纳入 ${value.accountCount} 个账户',
                style: const TextStyle(color: Color(0xFFB9D6C5), fontSize: 12),
              ),
            ],
          );
          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('资产', value.assetsFen, const Color(0xFF9CC7FF)),
              _metric('负债', value.liabilitiesFen, const Color(0xFFFFC1A9)),
              _metricText(
                '本月储蓄率',
                value.monthIncomeFen == 0 ? '--' : '$rate%',
                const Color(0xFFFFD27D),
              ),
            ],
          );
          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(flex: 4, child: netWorth),
                const SizedBox(width: 30),
                Expanded(flex: 6, child: metrics),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [netWorth, const SizedBox(height: 20), metrics],
          );
        },
      ),
    );
  }

  Widget _metric(String label, int fen, Color color) {
    return _metricText(label, MoneyUtils.fenToShort(fen), color);
  }

  Widget _metricText(String label, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFB9D6C5))),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> accounts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: '账户', subtitle: '填写当前余额，信用卡按待还金额计算'),
        const SizedBox(height: 10),
        accounts.when(
          data: (items) => Column(
            children: [
              for (final account in items) _accountTile(context, ref, account),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _errorBand('账户加载失败'),
        ),
      ],
    );
  }

  Widget _accountTile(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> account,
  ) {
    final type = account['type'] as String? ?? 'other';
    final balance = (account['balance_fen'] as num? ?? 0).toInt();
    final liability = type == 'credit_card';
    final included = (account['include_in_net_worth'] as int? ?? 1) == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkDivider
              : AppColors.divider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: liability
                ? AppColors.expenseLight
                : AppColors.primaryLightest,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            _accountIcon(type),
            size: 20,
            color: liability ? AppColors.expense : AppColors.primary,
          ),
        ),
        title: Text(
          account['name'] as String? ?? '未命名账户',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          included ? _accountType(type) : '${_accountType(type)} · 未计入净资产',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              liability && balance > 0
                  ? '-${MoneyUtils.fenToYuan(balance)}'
                  : MoneyUtils.fenToYuan(balance),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: liability ? AppColors.expense : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
        onTap: () => _editAccount(context, ref, account),
      ),
    );
  }

  Widget _goalsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<FinancialGoal>> goals,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '储蓄目标',
          subtitle: '把长期目标拆成看得见的进度',
          action: IconButton(
            tooltip: '添加目标',
            onPressed: () => _addGoal(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ),
        const SizedBox(height: 10),
        goals.when(
          data: (items) {
            if (items.isEmpty) return _emptyGoal(context, ref);
            return Column(
              children: [
                for (final goal in items) _goalTile(context, ref, goal),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _errorBand('目标加载失败'),
        ),
      ],
    );
  }

  Widget _goalTile(BuildContext context, WidgetRef ref, FinancialGoal goal) {
    final color = _parseColor(goal.color);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkDivider
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  goal.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '目标操作',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'progress') {
                    _updateGoal(context, ref, goal);
                  } else if (value == 'delete' && goal.id != null) {
                    ref.read(wealthActionsProvider).deleteGoal(goal.id!);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'progress', child: Text('更新进度')),
                  PopupMenuItem(value: 'delete', child: Text('删除目标')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceAlt,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${MoneyUtils.fenToShort(goal.currentFen)} / ${MoneyUtils.fenToShort(goal.targetFen)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${(goal.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyGoal(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, size: 30, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text('还没有储蓄目标'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _addGoal(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('创建目标'),
          ),
        ],
      ),
    );
  }

  Widget _budgetBand(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFFF0D49A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预算是财富计划的护栏',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  '设置月度和分类上限，及时发现超支',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/budget'),
            child: const Text('管理预算'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAccount(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> account,
  ) async {
    final name = TextEditingController(text: account['name'] as String? ?? '');
    final balance = TextEditingController(
      text: ((account['balance_fen'] as num? ?? 0).toInt() / 100)
          .toStringAsFixed(2),
    );
    var included = (account['include_in_net_worth'] as int? ?? 1) == 1;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('更新账户'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '账户名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: account['type'] == 'credit_card'
                        ? '当前待还金额'
                        : '当前余额',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('计入净资产'),
                  value: included,
                  onChanged: (value) => setState(() => included = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      final yuan = double.tryParse(balance.text.trim()) ?? 0;
      await ref
          .read(wealthActionsProvider)
          .updateAccount(
            id: account['id'] as int,
            name: name.text.trim().isEmpty ? '未命名账户' : name.text.trim(),
            balanceFen: MoneyUtils.yuanToFen(yuan.abs()),
            includeInNetWorth: included,
          );
    }
    name.dispose();
    balance.dispose();
  }

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final current = TextEditingController(text: '0');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建储蓄目标'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '目标名称',
                  hintText: '例如：应急金',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '目标金额',
                  prefixText: '¥ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: current,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '已经存下',
                  prefixText: '¥ ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    final targetFen = MoneyUtils.yuanToFen(double.tryParse(target.text) ?? 0);
    if (saved == true && name.text.trim().isNotEmpty && targetFen > 0) {
      await ref
          .read(wealthActionsProvider)
          .addGoal(
            name: name.text.trim(),
            targetFen: targetFen,
            currentFen: MoneyUtils.yuanToFen(
              double.tryParse(current.text) ?? 0,
            ),
          );
    }
    name.dispose();
    target.dispose();
    current.dispose();
  }

  Future<void> _updateGoal(
    BuildContext context,
    WidgetRef ref,
    FinancialGoal goal,
  ) async {
    final controller = TextEditingController(
      text: (goal.currentFen / 100).toStringAsFixed(2),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('更新「${goal.name}」'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '已经存下',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true && goal.id != null) {
      final fen = MoneyUtils.yuanToFen(double.tryParse(controller.text) ?? 0);
      await ref
          .read(wealthActionsProvider)
          .updateGoalProgress(goal.id!, fen.clamp(0, goal.targetFen));
    }
    controller.dispose();
  }

  Widget _errorBand(String message) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.expenseLight,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(message),
  );

  IconData _accountIcon(String type) => switch (type) {
    'wechat' => Icons.chat_bubble_outline_rounded,
    'alipay' => Icons.account_balance_wallet_outlined,
    'cash' => Icons.payments_outlined,
    'credit_card' => Icons.credit_card_rounded,
    'bank_card' => Icons.account_balance_outlined,
    _ => Icons.savings_outlined,
  };

  String _accountType(String type) => switch (type) {
    'wechat' => '微信',
    'alipay' => '支付宝',
    'cash' => '现金',
    'credit_card' => '信用卡负债',
    'bank_card' => '银行卡',
    _ => '其他资产',
  };

  Color _parseColor(String value) {
    try {
      return Color(int.parse('FF${value.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
      if (action != null) action!,
    ],
  );
}
