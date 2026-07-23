import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/learning_content.dart';
import '../../providers/learning_provider.dart';

class ArticleDetailPage extends ConsumerWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(learningArticleProvider(articleId));

    return articleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('学习详情')),
        body: Center(child: Text('加载失败：$error')),
      ),
      data: (article) {
        if (article == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('学习详情')),
            body: const Center(child: Text('未找到这篇文章')),
          );
        }
        return _ArticleDetailBody(article: article);
      },
    );
  }
}

class _ArticleDetailBody extends ConsumerStatefulWidget {
  final LearningArticle article;

  const _ArticleDetailBody({required this.article});

  @override
  ConsumerState<_ArticleDetailBody> createState() => _ArticleDetailBodyState();
}

class _ArticleDetailBodyState extends ConsumerState<_ArticleDetailBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(learningActionsProvider).open(widget.article.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final progress = ref
        .watch(learningProgressProvider)
        .valueOrNull?[article.id];
    final completed = progress?.completed ?? false;
    final bookmarked = progress?.bookmarked ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(article.category),
        actions: [
          IconButton(
            tooltip: bookmarked ? '取消收藏' : '收藏',
            onPressed: () {
              ref
                  .read(learningActionsProvider)
                  .bookmark(article.id, !bookmarked);
            },
            icon: Icon(
              bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.icon, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${article.minutes} 分钟阅读 · ${article.category}'
                          '${article.packId == null ? '' : ' · ${article.packId}'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                article.summary,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.7,
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF334155),
                ),
              ),
              if (article.keyPoints.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  '先记住这几件事',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < article.keyPoints.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLightest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            article.keyPoints[i],
                            style: const TextStyle(fontSize: 14, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (article.actionTip.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.warning),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          article.actionTip,
                          style: const TextStyle(fontSize: 13, height: 1.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 8),
              if (article.hasBody)
                MarkdownBody(
                  data: article.bodyMd,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: const TextStyle(fontSize: 15.5, height: 1.75),
                        h1: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                        h2: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                        h3: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                        blockquote: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        listBullet: const TextStyle(
                          fontSize: 15.5,
                          height: 1.7,
                        ),
                        tableHead: const TextStyle(fontWeight: FontWeight.w700),
                        tableBody: const TextStyle(fontSize: 13.5, height: 1.5),
                      ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '这篇文章还没有正文。可通过「导入内容包」或「检查更新」获取专栏长文。',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/learn');
                    }
                  },
                  child: const Text('返回列表'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(learningActionsProvider)
                        .complete(article.id, !completed);
                  },
                  icon: Icon(
                    completed ? Icons.replay_rounded : Icons.check_rounded,
                  ),
                  label: Text(completed ? '标记为未完成' : '完成学习'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
