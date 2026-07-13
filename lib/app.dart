import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'providers/theme_provider.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/statistics/statistics_page.dart';
import 'features/budget/budget_page.dart';
import 'features/settings/settings_page.dart';
import 'core/utils.dart';
import 'data/models.dart';
import 'providers/transaction_provider.dart';
import 'providers/category_provider.dart';
import 'features/add_transaction/add_transaction_dialog.dart';
import 'features/import/import_page.dart';
import 'features/sync/sync_page.dart';
import 'features/voice/voice_input_page.dart';
import 'features/recurring/recurring_page.dart';
import 'features/ocr/ocr_page.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(initialLocation: '/', routes: [
    ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
      GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
      GoRoute(path: '/stats', builder: (_, __) => const StatisticsPage()),
      GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    ]),
    GoRoute(path: '/import', builder: (_, __) => const ImportPage()),
    GoRoute(path: '/sync', builder: (_, __) => const SyncPage()),
    GoRoute(path: '/voice', builder: (_, __) => const VoiceInputPage()),
    GoRoute(path: '/recurring', builder: (_, __) => const RecurringPage()),
    GoRoute(path: '/ocr', builder: (_, __) => const OcrPage()),
  ]);
});

class ZimoJizhangApp extends ConsumerWidget {
  const ZimoJizhangApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final tm = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '子墨记账', theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme,
      themeMode: tm == AppThemeMode.light ? ThemeMode.light : tm == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.system,
      routerConfig: router, debugShowCheckedModeBanner: false,
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
  static const _routes = ['/', '/stats', '/budget', '/settings'];
  static const _titles = ['子墨记账', '统计分析', '预算管理', '设置'];
  static const _icons = [Icons.dashboard_rounded, Icons.pie_chart_rounded, Icons.savings_rounded, Icons.settings_rounded];
  static const _labels = ['总览', '统计', '预算', '设置'];

  int get _idx {
    final uri = GoRouterState.of(context).uri.toString();
    final i = _routes.indexOf(uri);
    return i >= 0 ? i : 0;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= AppConstants.breakpointWidth;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx = _idx;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F4F7),
      appBar: isDesktop ? null : AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(7)), alignment: Alignment.center, child: const Text('墨', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8), Text(_titles[idx]),
        ]),
      ),
      body: isDesktop ? Row(children: [
        Container(width: 200, color: isDark ? const Color(0xFF1E293B) : Colors.white, child: Column(children: [
          const SizedBox(height: 28),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)), alignment: Alignment.center, child: const Text('墨', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(width: 10), const Text('子墨记账', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(height: 20),
          ...List.generate(4, (i) { final sel = idx == i; return Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: Material(color: sel ? AppColors.primaryLightest.withOpacity(0.5) : Colors.transparent, borderRadius: BorderRadius.circular(10), child: InkWell(onTap: () => GoRouter.of(context).go(_routes[i]), borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [Icon(_icons[i], size: 21, color: sel ? AppColors.primary : AppColors.textSecondary), const SizedBox(width: 10), Text(_labels[i], style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.normal, color: sel ? AppColors.primary : AppColors.textSecondary))]))))); }),
        ])),
        const VerticalDivider(width: 1), Expanded(child: widget.child),
      ]) : widget.child,
      bottomNavigationBar: isDesktop ? null : NavigationBar(
        selectedIndex: idx, onDestinationSelected: (i) => GoRouter.of(context).go(_routes[i]),
        animationDuration: const Duration(milliseconds: 300),
        destinations: List.generate(4, (i) => NavigationDestination(icon: Icon(_icons[i]), label: _labels[i])),
      ),
      floatingActionButton: idx == 0 ? Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 6))]),
        child: FloatingActionButton.extended(
          onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AddTransactionDialog(
                    onSubmitted: (type, category, amount, note, date) {
                      final fen = MoneyUtils.yuanToFen(double.parse(amount));
                      ref.read(transactionListNotifierProvider.notifier).addTransaction(
                        amountFen: fen,
                        categoryId: category.id,
                        date: date,
                        description: note.isNotEmpty ? note : null,
                        type: type,
                      );
                    },
                  ),
                );
              },
          icon: const Icon(Icons.add_rounded, size: 28), label: Text('记一笔', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
