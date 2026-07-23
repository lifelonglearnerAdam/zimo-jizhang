import '../../data/database.dart';

/// 智能分类匹配器 — 基于历史交易记录匹配分类
class CategoryMatcher {
  final TransactionDao _txDao;

  CategoryMatcher(this._txDao);

  /// 根据交易对方 / 描述匹配最佳分类
  /// 返回 {categoryId, categoryName, confidence(0-100)}
  Future<MatchResult?> match(String counterparty, String description) async {
    // 1. 精确匹配交易对方
    final byCounterparty = await _searchTransactions(counterparty);
    if (byCounterparty.isNotEmpty) {
      return _bestMatch(byCounterparty, 90);
    }

    // 2. 模糊匹配描述中的关键词
    final keywords = _extractKeywords(description);
    for (final kw in keywords) {
      final byKeyword = await _searchTransactions(kw);
      if (byKeyword.isNotEmpty) {
        return _bestMatch(byKeyword, 60);
      }
    }

    return null; // 无匹配
  }

  Future<List<_TxRef>> _searchTransactions(String keyword) async {
    final txs = await _txDao.search(keyword);
    return txs
        .map(
          (t) => _TxRef(
            categoryId: t.categoryId,
            description: t.description ?? '',
          ),
        )
        .toList();
  }

  MatchResult _bestMatch(List<_TxRef> refs, int baseConfidence) {
    // 选择最常见的分类
    final count = <int, int>{};
    for (final r in refs) {
      if (r.categoryId != null) {
        count[r.categoryId!] = (count[r.categoryId!] ?? 0) + 1;
      }
    }
    if (count.isEmpty)
      return MatchResult(categoryId: null, categoryName: '未分类', confidence: 0);

    final best = count.entries.reduce((a, b) => a.value > b.value ? a : b);
    final matchCount = best.value;
    final total = refs.length;
    final confidence = (baseConfidence * (matchCount / total).clamp(0.5, 1.0))
        .round();

    return MatchResult(
      categoryId: best.key,
      categoryName: null, // 由调用方填充
      confidence: confidence,
    );
  }

  List<String> _extractKeywords(String text) {
    if (text.isEmpty) return [];
    // 简单分词：取 2-4 字的关键词
    final keywords = <String>[];
    for (var len = 3; len >= 2; len--) {
      for (var i = 0; i <= text.length - len; i++) {
        keywords.add(text.substring(i, i + len));
      }
    }
    return keywords.take(10).toList();
  }
}

class MatchResult {
  final int? categoryId;
  final String? categoryName;
  final int confidence;

  const MatchResult({this.categoryId, this.categoryName, this.confidence = 0});
}

class _TxRef {
  final int? categoryId;
  final String description;
  const _TxRef({this.categoryId, this.description = ''});
}
