import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'features/add_transaction/add_transaction_dialog.dart';
import 'features/budget/budget_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/import/import_page.dart';
import 'features/learning/article_detail_page.dart';
import 'features/learning/learning_page.dart';
import 'features/ocr/ocr_page.dart';
import 'features/recurring/recurring_page.dart';
import 'features/statistics/statistics_page.dart';
import 'features/sync/sync_page.dart';
import 'features/transaction_list/transaction_list_page.dart';
import 'features/settings/settings_page.dart';
import 'features/wealth/wealth_page.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
          GoRoute(
            path: '/transactions',
            builder: (_, __) => const TransactionListPage(),
          ),
          GoRoute(path: '/stats', builder: (_, __) => const StatisticsPage()),
          GoRoute(path: '/wealth', builder: (_, __) => const WealthPage()),
          GoRoute(path: '/learn', builder: (_, __) => const LearningPage()),
          GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        ],
      ),
      GoRoute(
        path: '/learn/:id',
        builder: (_, state) =>
            ArticleDetailPage(articleId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(path: '/import', builder: (_, __) => const ImportPage()),
      GoRoute(path: '/sync', builder: (_, __) => const SyncPage()),
      GoRoute(path: '/recurring', builder: (_, __) => const RecurringPage()),
      GoRoute(path: '/ocr', builder: (_, __) => const OcrPage()),
    ],
  );
});

class ZimoJizhangApp extends ConsumerWidget {
  const ZimoJizhangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode == AppThemeMode.light
          ? ThemeMode.light
          : themeMode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, '总览', '/'),
    (
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      '明细',
      '/transactions',
    ),
    (Icons.insights_outlined, Icons.insights_rounded, '分析', '/stats'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      '财富',
      '/wealth',
    ),
    (Icons.school_outlined, Icons.school_rounded, '学习', '/learn'),
  ];

  int get _selectedIndex {
    final path = GoRouterState.of(context).uri.path;
    if (path == '/budget') return 3;
    if (path.startsWith('/learn')) return 4;
    final index = _destinations.indexWhere((item) => item.$4 == path);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.breakpointWidth;
    final selectedIndex = _selectedIndex;
    final path = GoRouterState.of(context).uri.path;
    final pageTitle = path == '/settings'
        ? '设置'
        : path == '/budget'
        ? '预算'
        : _destinations[selectedIndex].$3;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _openAddDialog,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: isDesktop
              ? null
              : AppBar(
                  title: Row(
                    children: [
                      _BrandMark(size: 30),
                      const SizedBox(width: 9),
                      Text(pageTitle),
                    ],
                  ),
                  actions: [
                    if (path != '/settings')
                      IconButton(
                        tooltip: '设置',
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    IconButton(
                      tooltip: '记一笔',
                      onPressed: _openAddDialog,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
          body: isDesktop
              ? Row(
                  children: [
                    _DesktopSidebar(
                      selectedIndex: selectedIndex,
                      onAdd: _openAddDialog,
                    ),
                    Expanded(child: widget.child),
                  ],
                )
              : widget.child,
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      context.go(_destinations[index].$4),
                  destinations: [
                    for (final item in _destinations)
                      NavigationDestination(
                        icon: Icon(item.$1),
                        selectedIcon: Icon(item.$2),
                        label: item.$3,
                      ),
                  ],
                ),
          floatingActionButton:
              isDesktop || (path != '/' && path != '/transactions')
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openAddDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('记一笔'),
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final notifier = ref.read(transactionListNotifierProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (_) => AddTransactionDialog(
        onSubmitted: (draft) => notifier.addTransaction(
          amountFen: draft.amountFen,
          categoryId: draft.category.id,
          date: draft.date,
          description: draft.note,
          type: draft.type,
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onAdd;
  const _DesktopSidebar({required this.selectedIndex, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 22),
            child: Row(
              children: [
                _BrandMark(size: 38),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '子墨记账',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '把生活记得明白',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('记一笔'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '工作台',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_AppShellState._destinations.length, (index) {
            final item = _AppShellState._destinations[index];
            final selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                selected: selected,
                selectedTileColor: AppColors.primaryLightest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                leading: Icon(
                  selected ? item.$2 : item.$1,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                title: Text(
                  item.$3,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                onTap: () => context.go(item.$4),
              ),
            );
          }),
          const Spacer(),
          ListTile(
            dense: true,
            selected: GoRouterState.of(context).uri.path == '/settings',
            selectedTileColor: AppColors.primaryLightest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            leading: const Icon(Icons.settings_outlined, size: 20),
            title: const Text('设置', style: TextStyle(fontSize: 14)),
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '数据只保存在这台设备',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '版本 2.1.0',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: Text(
      '墨',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.43,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
