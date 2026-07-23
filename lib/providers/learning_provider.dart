import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/learning_content.dart';
import '../data/learning_pack.dart';
import '../data/models.dart';

final learningProgressProvider = FutureProvider<Map<String, LearningProgress>>((
  ref,
) async {
  final rows = await LearningProgressDao().getAll();
  return {for (final row in rows) row.articleId: row};
});

final learningCatalogProvider = FutureProvider<List<LearningArticle>>((
  ref,
) async {
  return LearningArticleDao().getActive();
});

final learningMetaProvider = FutureProvider<LearningMeta>((ref) async {
  final pack = LearningPackService();
  return LearningMeta(
    packUrl: await pack.getPackUrl(),
    lastPackId: await pack.getLastPackId(),
    lastSyncedAt: await pack.getLastSyncedAt(),
    lastCheckAt: await pack.getLastCheckAt(),
    autoCheckEnabled: await pack.isAutoCheckEnabled(),
  );
});

class LearningMeta {
  final String? packUrl;
  final String? lastPackId;
  final String? lastSyncedAt;
  final String? lastCheckAt;
  final bool autoCheckEnabled;

  const LearningMeta({
    this.packUrl,
    this.lastPackId,
    this.lastSyncedAt,
    this.lastCheckAt,
    this.autoCheckEnabled = true,
  });
}

final todayLearningProvider = FutureProvider<LearningArticle>((ref) async {
  final catalog = await ref.watch(learningCatalogProvider.future);
  final progress = await ref.watch(learningProgressProvider.future);
  final completedIds = progress.values
      .where((item) => item.completed)
      .map((item) => item.articleId)
      .toSet();
  final now = DateTime.now();
  final pack = LearningPackService();
  final pinned = await pack.getDailyPin(now);
  final picked = LearningCatalog.pickDailyArticle(
    date: now,
    catalog: catalog,
    completedIds: completedIds,
    pinnedId: pinned,
  );
  if (pinned != picked.id) {
    await pack.setDailyPin(now, picked.id);
  }
  return picked;
});

final learningArticleProvider =
    FutureProvider.family<LearningArticle?, String>((ref, id) async {
      final catalog = await ref.watch(learningCatalogProvider.future);
      for (final article in catalog) {
        if (article.id == id) return article;
      }
      return LearningArticleDao().getById(id);
    });

final learningStreakProvider = FutureProvider<int>((ref) async {
  final progress = await ref.watch(learningProgressProvider.future);
  final completedDates = progress.values
      .where((item) => item.completed && item.completedAt != null)
      .map((item) {
        final date = item.completedAt!;
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      })
      .toSet();

  var streak = 0;
  var cursor = DateTime.now();
  while (completedDates.contains(_dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final learningActionsProvider = Provider<LearningActions>((ref) {
  return LearningActions(ref);
});

class LearningActions {
  final Ref _ref;

  LearningActions(this._ref);

  Future<void> open(String articleId) async {
    await LearningProgressDao().markOpened(articleId);
    _ref.invalidate(learningProgressProvider);
  }

  Future<void> complete(String articleId, bool value) async {
    await LearningProgressDao().setCompleted(articleId, value);
    _ref.invalidate(learningProgressProvider);
    _ref.invalidate(learningStreakProvider);
  }

  Future<void> bookmark(String articleId, bool value) async {
    await LearningProgressDao().setBookmarked(articleId, value);
    _ref.invalidate(learningProgressProvider);
  }

  Future<LearningPackImportResult> importPackBytes(List<int> bytes) async {
    final result = await LearningPackService().importJsonBytes(bytes);
    _ref.invalidate(learningCatalogProvider);
    _ref.invalidate(todayLearningProvider);
    _ref.invalidate(learningMetaProvider);
    return result;
  }

  Future<LearningPackImportResult> refreshRemote({String? url}) async {
    final service = LearningPackService();
    final target = (url ?? await service.getPackUrl())?.trim();
    if (target == null || target.isEmpty) {
      throw StateError('请先设置内容包 URL');
    }
    if (url != null && url.trim().isNotEmpty) {
      await service.setPackUrl(url.trim());
    }
    try {
      final result = await service.refreshFromUrl(target);
      await service.markCheckedAt();
      _ref.invalidate(learningCatalogProvider);
      _ref.invalidate(todayLearningProvider);
      _ref.invalidate(learningMetaProvider);
      return result;
    } catch (e) {
      // Still record check time so a flaky network does not hammer the endpoint.
      await service.markCheckedAt();
      _ref.invalidate(learningMetaProvider);
      rethrow;
    }
  }

  /// Silent background refresh used when opening the learning page.
  /// Returns null when skipped (no URL / throttled / disabled).
  Future<LearningPackImportResult?> autoCheckOnOpen() async {
    final service = LearningPackService();
    if (!await service.shouldAutoCheck()) {
      return null;
    }
    return refreshRemote();
  }

  Future<void> savePackUrl(String? url) async {
    await LearningPackService().setPackUrl(
      (url == null || url.trim().isEmpty) ? null : url.trim(),
    );
    _ref.invalidate(learningMetaProvider);
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    await LearningPackService().setAutoCheckEnabled(enabled);
    _ref.invalidate(learningMetaProvider);
  }
}
