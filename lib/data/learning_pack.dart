import 'dart:convert';

import 'package:http/http.dart' as http;

import 'database.dart';
import 'learning_content.dart';

/// Parse / import / remote-refresh for zimo learning content packs.
class LearningPackService {
  static const formatId = 'zimo-learning-pack';
  static const supportedVersion = 1;
  static const packUrlKey = 'learning_pack_url';
  static const lastPackIdKey = 'learning_last_pack_id';
  static const lastSyncedAtKey = 'learning_last_synced_at';
  static const lastCheckAtKey = 'learning_last_check_at';
  static const autoCheckKey = 'learning_auto_check_enabled';
  static const dailyPinPrefix = 'learning_daily_pin_';

  /// Skip repeated remote checks within this window.
  static const autoCheckInterval = Duration(hours: 6);

  final LearningArticleDao _articleDao = LearningArticleDao();
  final AppKvDao _kv = AppKvDao();

  Future<String?> getPackUrl() => _kv.get(packUrlKey);

  Future<void> setPackUrl(String? url) => _kv.set(packUrlKey, url);

  Future<String?> getLastPackId() => _kv.get(lastPackIdKey);

  Future<String?> getLastSyncedAt() => _kv.get(lastSyncedAtKey);

  Future<String?> getLastCheckAt() => _kv.get(lastCheckAtKey);

  Future<bool> isAutoCheckEnabled() async {
    final raw = await _kv.get(autoCheckKey);
    if (raw == null) return true; // default on
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  Future<void> setAutoCheckEnabled(bool enabled) {
    return _kv.set(autoCheckKey, enabled ? '1' : '0');
  }

  Future<bool> shouldAutoCheck({DateTime? now}) async {
    if (!await isAutoCheckEnabled()) return false;
    final url = (await getPackUrl())?.trim();
    if (url == null || url.isEmpty) return false;
    final last = await getLastCheckAt();
    if (last == null || last.isEmpty) return true;
    final lastAt = DateTime.tryParse(last);
    if (lastAt == null) return true;
    final current = now ?? DateTime.now();
    return current.difference(lastAt) >= autoCheckInterval;
  }

  Future<void> markCheckedAt([DateTime? at]) {
    return _kv.set(
      lastCheckAtKey,
      (at ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<String?> getDailyPin(DateTime date) {
    return _kv.get('$dailyPinPrefix${_dayKey(date)}');
  }

  Future<void> setDailyPin(DateTime date, String articleId) {
    return _kv.set('$dailyPinPrefix${_dayKey(date)}', articleId);
  }

  String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<LearningPackImportResult> importJsonString(
    String jsonStr, {
    String source = 'import',
  }) async {
    final articles = parsePackJson(jsonStr);
    final result = await _articleDao.upsertAll(articles, source: source);
    final packId = _tryReadPackId(jsonStr);
    if (packId != null) {
      await _kv.set(lastPackIdKey, packId);
    }
    await _kv.set(lastSyncedAtKey, DateTime.now().toIso8601String());
    return result;
  }

  Future<LearningPackImportResult> importJsonBytes(
    List<int> bytes, {
    String source = 'import',
  }) {
    return importJsonString(utf8.decode(bytes), source: source);
  }

  Future<LearningPackImportResult> refreshFromUrl(String url) async {
    final uri = Uri.parse(url.trim());
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('下载失败：HTTP ${response.statusCode}');
    }
    return importJsonString(response.body, source: 'remote');
  }

  static String? _tryReadPackId(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      if (data is Map) {
        return Map<String, dynamic>.from(data)['pack_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static List<LearningArticle> parsePackJson(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) {
      throw const FormatException('内容包必须是 JSON 对象');
    }
    final root = Map<String, dynamic>.from(decoded);
    final format = root['format'] as String? ?? '';
    if (format != formatId && format != 'zimo.learning.pack') {
      throw FormatException('不支持的内容包格式: $format');
    }
    final version =
        (root['version'] as num?)?.toInt() ??
        (root['format_version'] as num?)?.toInt() ??
        0;
    if (version != supportedVersion) {
      throw FormatException('不支持的内容包版本: $version');
    }
    final packId = root['pack_id'] as String? ?? 'unknown-pack';
    final rawArticles = root['articles'];
    if (rawArticles is! List || rawArticles.isEmpty) {
      throw const FormatException('内容包缺少 articles');
    }

    final articles = <LearningArticle>[];
    for (final item in rawArticles) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = (map['id'] as String?)?.trim();
      final title = (map['title'] as String?)?.trim();
      if (id == null || id.isEmpty || title == null || title.isEmpty) {
        continue;
      }
      final keyPoints = _asStringList(map['key_points'] ?? map['keyPoints']);
      final tags = _asStringList(map['tags']);
      final body =
          (map['body_md'] as String?) ??
          (map['body'] as String?) ??
          (map['content'] as String?) ??
          '';
      articles.add(
        LearningArticle(
          id: id,
          title: title,
          category: (map['category'] as String?)?.trim().isNotEmpty == true
              ? (map['category'] as String).trim()
              : '未分类',
          icon: (map['icon'] as String?)?.trim().isNotEmpty == true
              ? (map['icon'] as String).trim()
              : '📘',
          minutes: (map['minutes'] as num?)?.toInt() ?? 15,
          summary: map['summary'] as String? ?? '',
          keyPoints: keyPoints,
          actionTip:
              map['action_tip'] as String? ?? map['actionTip'] as String? ?? '',
          bodyMd: body,
          tags: tags,
          source: 'import',
          packId: packId,
          publishedAt:
              map['published_at'] as String? ?? map['publishedAt'] as String?,
          updatedAt:
              map['updated_at'] as String? ??
              map['updatedAt'] as String? ??
              map['published_at'] as String?,
          priority:
              (map['priority'] as num?)?.toInt() ??
              (map['weight'] as num?)?.toInt() ??
              100,
          isActive: map['is_active'] == false || map['status'] == 'archived'
              ? false
              : true,
        ),
      );
    }
    if (articles.isEmpty) {
      throw const FormatException('内容包没有可导入的有效文章');
    }
    return articles;
  }

  static List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
