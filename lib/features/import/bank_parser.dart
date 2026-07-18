import '../../core/csv_parser.dart';
import 'wechat_parser.dart'; // 复用 ParsedBillEntry

/// 银行账单 CSV 解析器（通用模板）
class BankParser {
  /// 解析银行账单，支持自定义字段映射
  static List<ParsedBillEntry> parse(
    CsvParseResult csv, {
    Map<String, String>? fieldMapping,
  }) {
    final mapping = fieldMapping ?? _defaultMapping();
    final entries = <ParsedBillEntry>[];

    final dateKey = mapping['date'] ?? '交易日期';
    final amountKey = mapping['amount'] ?? '交易金额';
    final typeKey = mapping['type'] ?? '收支方向';
    final descKey = mapping['description'] ?? '摘要';
    final counterpartyKey = mapping['counterparty'] ?? '对方户名';
    final externalIdKey = mapping['external_id'] ?? '流水号';

    for (var i = 0; i < csv.rows.length; i++) {
      final row = csv.rows[i];
      try {
        final dateStr = _find(csv.headers, row, dateKey);
        final amountStr = _find(csv.headers, row, amountKey);
        final typeStr = _find(csv.headers, row, typeKey);
        final description = _find(csv.headers, row, descKey);
        final counterparty = _find(csv.headers, row, counterpartyKey);
        final externalId = _find(csv.headers, row, externalIdKey);

        if (amountStr == null || dateStr == null) continue;

        final cleanAmount = amountStr
            .replaceAll(',', '')
            .replaceAll('¥', '')
            .trim();
        final amount = double.tryParse(cleanAmount);
        if (amount == null) continue;

        // 银行收支方向：贷/收入，借/支出
        final isExpense =
            typeStr == null ||
            typeStr.contains('支出') ||
            typeStr.contains('借') ||
            typeStr.contains('消费');
        final type = isExpense ? 'expense' : 'income';

        final desc = description ?? '';
        // 跳过利息等非消费记录
        if (desc.contains('利息') || desc.contains('结息')) continue;

        entries.add(
          ParsedBillEntry(
            date: _normalizeBankDate(dateStr),
            type: type,
            amountFen: (amount * 100).round(),
            description: desc,
            counterparty: counterparty ?? '',
            paymentMethod: '银行卡',
            externalId: externalId,
            source: 'bank_csv',
          ),
        );
      } catch (_) {}
    }

    return entries;
  }

  static String? _find(List<String> headers, List<String> row, String key) {
    for (var i = 0; i < headers.length; i++) {
      if (headers[i].contains(key)) {
        if (i < row.length) {
          final val = row[i];
          return val.isEmpty ? null : val;
        }
        return null;
      }
    }
    return null;
  }

  static String _normalizeBankDate(String raw) {
    // 银行日期可能是 yyyyMMdd 或 yyyy-MM-dd
    if (raw.length == 8 && !raw.contains('-')) {
      return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
    }
    return raw.split(' ')[0].replaceAll('/', '-');
  }

  static Map<String, String> _defaultMapping() => {
    'date': '交易日期',
    'amount': '交易金额',
    'type': '收支方向',
    'description': '摘要',
    'counterparty': '对方户名',
    'external_id': '流水号',
  };
}
