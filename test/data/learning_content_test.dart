import 'package:flutter_test/flutter_test.dart';
import 'package:zimo_jizhang/data/learning_content.dart';
import 'package:zimo_jizhang/data/learning_pack.dart';

void main() {
  test('daily lesson is stable for the same calendar day', () {
    final morning = LearningCatalog.articleForDate(DateTime(2026, 7, 22, 8));
    final evening = LearningCatalog.articleForDate(DateTime(2026, 7, 22, 23));
    expect(morning.id, evening.id);
  });

  test('learning article ids are unique and denser than short-tip catalog', () {
    final ids = LearningCatalog.articles.map((article) => article.id).toSet();
    expect(ids.length, LearningCatalog.articles.length);
    expect(LearningCatalog.articles.length, greaterThanOrEqualTo(12));
    expect(LearningCatalog.seedArticles.every((a) => a.bodyMd.trim().isNotEmpty), isTrue);
  });

  test('pickDailyArticle prefers unfinished content', () {
    final catalog = LearningCatalog.seedArticles;
    final completed = catalog.take(catalog.length - 1).map((a) => a.id).toSet();
    final picked = LearningCatalog.pickDailyArticle(
      date: DateTime(2026, 7, 23),
      catalog: catalog,
      completedIds: completed,
    );
    expect(completed.contains(picked.id), isFalse);
  });

  test('pickDailyArticle respects pinned id', () {
    final catalog = LearningCatalog.seedArticles;
    final pinned = catalog.last.id;
    final picked = LearningCatalog.pickDailyArticle(
      date: DateTime(2026, 7, 23),
      catalog: catalog,
      completedIds: {},
      pinnedId: pinned,
    );
    expect(picked.id, pinned);
  });

  test('article map roundtrip keeps body and key points', () {
    final original = LearningCatalog.seedArticles.first;
    final restored = LearningArticle.fromMap(original.toMap());
    expect(restored.id, original.id);
    expect(restored.bodyMd, original.bodyMd);
    expect(restored.keyPoints, original.keyPoints);
    expect(restored.tags, original.tags);
  });

  test('content pack parser accepts inline body articles', () {
    const json = r'{"format":"zimo-learning-pack","version":1,"pack_id":"test-pack","articles":[{"id":"demo-article","title":"demo long article","category":"finance-basics","icon":"book","minutes":12,"summary":"summary","key_points":["a","b"],"action_tip":"do one action","body_md":"## Intro\n\nBody text\n\n## Today Action\n\nAct","updated_at":"2026-07-23"}]}';
    final articles = LearningPackService.parsePackJson(json);
    expect(articles, hasLength(1));
    expect(articles.first.id, 'demo-article');
    expect(articles.first.bodyMd.contains('Intro'), isTrue);
    expect(articles.first.packId, 'test-pack');
  });

  test('content pack parser rejects wrong format', () {
    expect(
      () => LearningPackService.parsePackJson(
        '{"format":"nope","version":1,"articles":[]}',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
