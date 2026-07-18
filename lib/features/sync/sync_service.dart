import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../data/models.dart';
import '../../data/database.dart';
import '../../core/file_saver.dart';

/// 同步服务 — JSON 导出/导入 + WebDAV 远程同步
class SyncService {
  final TransactionDao txDao;

  SyncService(this.txDao);

  /// 导出所有交易为 JSON
  Future<String> exportToJson() async {
    final txs = await txDao.getAll(limit: 10000);
    final data = txs
        .map(
          (t) => {
            'id': t.id,
            'amount_fen': t.amountFen,
            'type': t.type,
            'category_id': t.categoryId,
            'transaction_date': t.transactionDate,
            'description': t.description,
            'counterparty': t.counterparty,
            'payment_method': t.paymentMethod,
            'source': t.source,
            'external_id': t.externalId,
            'updated_at': t.updatedAt.toIso8601String(),
          },
        )
        .toList();

    final json = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'count': txs.length,
      'transactions': data,
    });

    return json;
  }

  /// 导出到文件（桌面端保存到本地，Web 端触发下载）
  Future<String?> exportToFile() async {
    final json = await exportToJson();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'zimo_jizhang_backup_$timestamp.json';
    return await saveTextFile(fileName, json);
  }

  /// 从 JSON 字符串导入（差分合并）
  Future<SyncResult> importFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final txsList = data['transactions'] as List;
    final existing = await txDao.getAll(limit: 10000);
    final existingIds = existing.map((t) => t.id).toSet();

    int imported = 0;
    int skipped = 0;

    for (final item in txsList) {
      final txMap = item as Map<String, dynamic>;
      final id = txMap['id'] as String;

      if (existingIds.contains(id)) {
        // 更新已存在的记录（以 updated_at 为准）
        final existingTx = existing.firstWhere((t) => t.id == id);
        final newUpdatedAt = DateTime.parse(txMap['updated_at'] as String);
        if (newUpdatedAt.isAfter(existingTx.updatedAt)) {
          await txDao.update(
            TransactionModel(
              id: id,
              amountFen: txMap['amount_fen'] as int,
              type: txMap['type'] as String? ?? 'expense',
              categoryId: txMap['category_id'] as int?,
              transactionDate: txMap['transaction_date'] as String,
              description: txMap['description'] as String?,
              counterparty: txMap['counterparty'] as String?,
              paymentMethod: txMap['payment_method'] as String?,
              source: txMap['source'] as String? ?? 'import',
              externalId: txMap['external_id'] as String?,
              createdAt: existingTx.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
          imported++;
        } else {
          skipped++;
        }
      } else {
        // 新记录
        await txDao.insertWithData(
          id: id,
          amountFen: txMap['amount_fen'] as int,
          categoryId: txMap['category_id'] as int? ?? 1,
          date: txMap['transaction_date'] as String,
          description: txMap['description'] as String?,
          paymentMethod: txMap['payment_method'] as String?,
          type: txMap['type'] as String? ?? 'expense',
        );
        imported++;
      }
    }

    return SyncResult(imported: imported, skipped: skipped);
  }

  /// 从字节数据导入（跨平台兼容）
  Future<SyncResult> importFromBytes(Uint8List bytes) {
    final content = utf8.decode(bytes);
    return importFromJson(content);
  }

  /// WebDAV 上传
  Future<bool> uploadToWebdav(
    String url,
    String username,
    String password,
  ) async {
    try {
      final json = await exportToJson();
      final auth = base64Encode(utf8.encode('$username:$password'));
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/json',
        },
        body: json,
      );
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// WebDAV 下载
  Future<String?> downloadFromWebdav(
    String url,
    String username,
    String password,
  ) async {
    try {
      final auth = base64Encode(utf8.encode('$username:$password'));
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Basic $auth'},
      );
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class SyncResult {
  final int imported;
  final int skipped;

  const SyncResult({this.imported = 0, this.skipped = 0});
}
