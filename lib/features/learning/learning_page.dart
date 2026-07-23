import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/learning_content.dart';
import '../../data/models.dart';
import '../../providers/learning_provider.dart';

class LearningPage extends ConsumerStatefulWidget {
  const LearningPage({super.key});

  @override
  ConsumerState<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends ConsumerState<LearningPage> {
  String _filter = 'all';
  bool _busy = false;
  bool _autoChecking = false;
  String? _autoCheckHint;
  bool _autoCheckStarted = false;

  @override
  void initState() {
    super.initState();
    // Fire after first frame so the page paints before network work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoCheck();
    });
  }

  Future<void> _maybeAutoCheck() async {
    if (_autoCheckStarted || !mounted) return;
    _autoCheckStarted = true;
    setState(() {
      _autoChecking = true;
      _autoCheckHint = '正在检查内容更新…';
    });
    try {
      final result = await ref.read(learningActionsProvider).autoCheckOnOpen();
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _autoChecking = false;
          _autoCheckHint = null;
        });
        return;
      }
      final msg = result.touched == 0
          ? '内容已是最新'
          : '自动更新：新增 ${result.inserted}，更新 ${result.updated}';
      setState(() {
        _autoChecking = false;
        _autoCheckHint = msg;
      });
      if (result.touched > 0) {
        _toast(msg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _autoChecking = false;
        _autoCheckHint = '自动检查失败（可稍后手动检查）';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayLearningProvider);
    final catalogAsync = ref.watch(learningCatalogProvider);
    final progressAsync = ref.watch(learningProgressProvider);
    final streak = ref.watch(learningStreakProvider).valueOrNull ?? 0;
    final meta = ref.watch(learningMetaProvider).valueOrNull;
    final progress =
        progressAsync.valueOrNull ?? const <String, LearningProgress>{};
    final completed = progress.values.where((item) => item.completed).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, completed, streak),
                const SizedBox(height: 14),
                _updateBar(context, meta),
                const SizedBox(height: 18),
                todayAsync.when(
                  data: (today) =>
                      _dailyLesson(context, today, progress[today.id]),
                  loading: () => const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _errorBox('每日一课加载失败：$e'),
                ),
                const SizedBox(height: 24),
                const Text(
                  '知识库',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '专栏长文 · 共 ${catalogAsync.valueOrNull?.length ?? 0} 篇 · 不构成投资建议',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _filters(),
                const SizedBox(height: 14),
                catalogAsync.when(
                  data: (catalog) {
                    final articles = _filteredArticles(catalog, progress);
                    if (articles.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: Text('没有符合筛选的文章')),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 820 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: articles.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 154,
                              ),
                          itemBuilder: (context, index) {
                            final article = articles[index];
                            return _articleCard(
                              context,
                              article,
                              progress[article.id],
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _errorBox('知识库加载失败：$e'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text),
    );
  }

  Widget _header(BuildContext context, int completed, int streak) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '财商学习',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '专栏长文，可每日更新 · 把财务选择做得更清楚',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        _statBadge(Icons.local_fire_department_outlined, '$streak 天', '连续学习'),
        const SizedBox(width: 8),
        _statBadge(Icons.task_alt_rounded, '$completed', '已完成'),
      ],
    );
  }

  Widget _statBadge(IconData icon, String value, String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _updateBar(BuildContext context, LearningMeta? meta) {
    final last = meta?.lastSyncedAt;
    final packId = meta?.lastPackId;
    final url = meta?.packUrl;
    final autoOn = meta?.autoCheckEnabled ?? true;
    return Container(
      width: double.infinity,
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
          Text(
            packId == null ? '内容来源：内置种子专栏' : '最近内容包：$packId',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            last == null
                ? '尚未导入或远程更新。可导入 JSON 内容包，或配置 URL 后自动/手动检查更新。'
                : '上次更新：$last'
                      '${url == null || url.isEmpty ? '' : '\n远程：$url'}'
                      '\n打开页面自动检查：${autoOn ? '已开启（约 6 小时一次）' : '已关闭'}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (_autoCheckHint != null) ...[
            const SizedBox(height: 8),
            Text(
              _autoCheckHint!,
              style: TextStyle(
                fontSize: 11,
                color: _autoChecking ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _importPack,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('导入内容包'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _checkUpdate,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('检查更新'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _editPackUrl,
                icon: const Icon(Icons.link, size: 18),
                label: const Text('设置 URL'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await ref
                            .read(learningActionsProvider)
                            .setAutoCheckEnabled(!autoOn);
                        _toast(autoOn ? '已关闭自动检查' : '已开启自动检查');
                      },
                icon: Icon(
                  autoOn
                      ? Icons.sync_disabled_rounded
                      : Icons.sync_rounded,
                  size: 18,
                ),
                label: Text(autoOn ? '关闭自动检查' : '开启自动检查'),
              ),
            ],
          ),
          if (_busy || _autoChecking) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  Future<void> _importPack() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      _toast('无法读取文件内容');
      return;
    }
    setState(() => _busy = true);
    try {
      final report = await ref
          .read(learningActionsProvider)
          .importPackBytes(bytes);
      _toast(
        '导入完成：新增 ${report.inserted}，更新 ${report.updated}，跳过 ${report.skipped}',
      );
    } catch (e) {
      _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkUpdate() async {
    final meta = ref.read(learningMetaProvider).valueOrNull;
    var url = meta?.packUrl;
    if (url == null || url.trim().isEmpty) {
      url = await _promptUrl(initial: url);
      if (url == null) return;
      await ref.read(learningActionsProvider).savePackUrl(url);
    }
    setState(() => _busy = true);
    try {
      final report = await ref
          .read(learningActionsProvider)
          .refreshRemote(url: url);
      _toast(
        '更新完成：新增 ${report.inserted}，更新 ${report.updated}，跳过 ${report.skipped}',
      );
    } catch (e) {
      _toast('更新失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPackUrl() async {
    final meta = ref.read(learningMetaProvider).valueOrNull;
    final url = await _promptUrl(initial: meta?.packUrl);
    if (url == null) return;
    await ref.read(learningActionsProvider).savePackUrl(url);
    _toast(url.trim().isEmpty ? '已清除远程 URL' : '已保存远程 URL');
  }

  Future<String?> _promptUrl({String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('内容包 URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/learning-pack.json',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _dailyLesson(
    BuildContext context,
    LearningArticle article,
    LearningProgress? progress,
  ) {
    final completed = progress?.completed ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF284B3C),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadows.elevated,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD27D),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '每日一课',
                      style: TextStyle(
                        color: Color(0xFF4E3814),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${article.minutes} 分钟 · ${article.category}',
                    style: const TextStyle(
                      color: Color(0xFFB9D6C5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                article.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                article.summary,
                style: const TextStyle(
                  color: Color(0xFFDCEBE2),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                ),
                onPressed: () => context.push('/learn/${article.id}'),
                icon: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.menu_book_rounded,
                ),
                label: Text(completed ? '继续阅读' : '开始学习'),
              ),
            ],
          );
          if (constraints.maxWidth < 700) return copy;
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 28),
              Container(
                width: 150,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(article.icon, style: const TextStyle(fontSize: 68)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters() {
    final filters = const [
      ('all', '全部'),
      ('todo', '未学习'),
      ('done', '已完成'),
      ('saved', '收藏'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: _filter == item.$1,
                onSelected: (_) => setState(() => _filter = item.$1),
              ),
            ),
        ],
      ),
    );
  }

  List<LearningArticle> _filteredArticles(
    List<LearningArticle> catalog,
    Map<String, LearningProgress> progress,
  ) {
    return catalog.where((article) {
      final state = progress[article.id];
      return switch (_filter) {
        'todo' => !(state?.completed ?? false),
        'done' => state?.completed ?? false,
        'saved' => state?.bookmarked ?? false,
        _ => true,
      };
    }).toList();
  }

  Widget _articleCard(
    BuildContext context,
    LearningArticle article,
    LearningProgress? progress,
  ) {
    final completed = progress?.completed ?? false;
    final bookmarked = progress?.bookmarked ?? false;
    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkDivider
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => context.push('/learn/${article.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed
                      ? AppColors.primaryLightest
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(article.icon, style: const TextStyle(fontSize: 23)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            article.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (bookmarked)
                          const Icon(
                            Icons.bookmark_rounded,
                            size: 17,
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${article.category} · ${article.minutes} 分钟'
                          '${article.hasBody ? ' · 长文' : ''}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          completed
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 17,
                          color: completed
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
