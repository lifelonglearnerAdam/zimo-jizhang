import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:typed_data';
import '../../data/models.dart';
import '../../providers/database_provider.dart';
import '../../core/csv_parser.dart';
import 'wechat_parser.dart';
import 'alipay_parser.dart';
import 'bank_parser.dart';

/// 导入状态
class ImportState {
  final bool isParsing;
  final bool isImporting;
  final String? source; // 'wechat' | 'alipay' | 'bank_csv'
  final String? fileName;
  final List<ImportPreviewEntry> previewEntries;
  final int totalCount;
  final int importedCount;
  final int skippedCount;
  final String? error;

  const ImportState({
    this.isParsing = false,
    this.isImporting = false,
    this.source,
    this.fileName,
    this.previewEntries = const [],
    this.totalCount = 0,
    this.importedCount = 0,
    this.skippedCount = 0,
    this.error,
  });

  ImportState copyWith({
    bool? isParsing,
    bool? isImporting,
    String? source,
    String? fileName,
    List<ImportPreviewEntry>? previewEntries,
    int? totalCount,
    int? importedCount,
    int? skippedCount,
    String? error,
  }) {
    return ImportState(
      isParsing: isParsing ?? this.isParsing,
      isImporting: isImporting ?? this.isImporting,
      source: source ?? this.source,
      fileName: fileName ?? this.fileName,
      previewEntries: previewEntries ?? this.previewEntries,
      totalCount: totalCount ?? this.totalCount,
      importedCount: importedCount ?? this.importedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      error: error,
    );
  }
}

/// 导入 Notifier
class ImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;

  ImportNotifier(this._ref) : super(const ImportState());

  /// 解析文件（从字节数据）
  Future<void> parseFile(
    Uint8List bytes,
    String fileName,
    String source,
  ) async {
    state = state.copyWith(isParsing: true, source: source, error: null);

    try {
      final csv = await CsvParser.parse(bytes, fileName: fileName);

      List<ParsedBillEntry> entries;
      switch (source) {
        case 'wechat':
          entries = WechatParser.parse(csv);
          break;
        case 'alipay':
          entries = AlipayParser.parse(csv);
          break;
        case 'bank_csv':
          entries = BankParser.parse(csv);
          break;
        default:
          throw Exception('不支持的账单来源: $source');
      }

      // 去重检测
      final txDao = _ref.read(transactionDaoProvider);
      final existingDates = <String, Set<String>>{};
      final allExisting = await txDao.getAll(limit: 1000);
      for (final tx in allExisting) {
        final key =
            '${tx.transactionDate}_${tx.amountFen}_${tx.counterparty ?? ''}';
        existingDates.putIfAbsent(tx.transactionDate, () => {}).add(key);
      }

      // 构建预览条目
      final previews = <ImportPreviewEntry>[];
      final seenInFile = <String>{};

      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final dupKey = '${e.date}_${e.amountFen}_${e.counterparty}';

        // 文件内去重
        if (seenInFile.contains(dupKey)) continue;
        seenInFile.add(dupKey);

        // 数据库去重
        final isDuplicate = existingDates[e.date]?.contains(dupKey) ?? false;

        previews.add(
          ImportPreviewEntry(
            index: i,
            date: e.date,
            type: e.type,
            amountFen: e.amountFen,
            description: e.description,
            counterparty: e.counterparty,
            paymentMethod: e.paymentMethod,
            isDuplicate: isDuplicate,
            externalId: e.externalId,
          ),
        );
      }

      state = state.copyWith(
        isParsing: false,
        fileName: fileName,
        previewEntries: previews,
        totalCount: entries.length,
        importedCount: previews.length,
      );
    } catch (e) {
      state = state.copyWith(isParsing: false, error: e.toString());
    }
  }

  /// 确认导入（批量写入数据库）
  Future<void> confirmImport({
    required Map<int, int> categoryAssignments, // index -> categoryId
  }) async {
    if (state.previewEntries.isEmpty) return;
    state = state.copyWith(isImporting: true);

    try {
      final txDao = _ref.read(transactionDaoProvider);
      final now = DateTime.now();
      int imported = 0;
      int skipped = 0;

      for (final entry in state.previewEntries) {
        if (entry.isDuplicate) {
          skipped++;
          continue;
        }

        final categoryId = categoryAssignments[entry.index];
        if (categoryId == null) {
          skipped++;
          continue;
        }

        await txDao.insertWithData(
          id: '${now.microsecondsSinceEpoch}_${entry.index}',
          amountFen: entry.amountFen,
          categoryId: categoryId,
          date: entry.date,
          description: entry.description.isNotEmpty
              ? entry.description
              : entry.counterparty,
          paymentMethod: entry.paymentMethod.isNotEmpty
              ? entry.paymentMethod
              : null,
          type: entry.type,
        );
        imported++;
      }

      state = state.copyWith(
        isImporting: false,
        importedCount: imported,
        skippedCount: skipped,
        previewEntries: [], // 清空预览
      );
    } catch (e) {
      state = state.copyWith(isImporting: false, error: e.toString());
    }
  }

  /// 批量设置分类
  void batchSetCategory(int categoryId, List<int> indices) {
    // 在 preview 页面处理
  }

  void reset() {
    state = const ImportState();
  }
}

/// Provider
final importProvider = StateNotifierProvider<ImportNotifier, ImportState>((
  ref,
) {
  return ImportNotifier(ref);
});
