import '../../core/csv_parser.dart';
import 'wechat_parser.dart'; // 复用 ParsedBillEntry

/// 支付宝账单解析器
class AlipayParser {
  /// 解析支付宝账单 CSV（通常 GBK 编码）
  static List<ParsedBillEntry> parse(CsvParseResult csv) {
    final entries = <ParsedBillEntry>[];

    for (var i = 0; i < csv.rows.length; i++) {
      final row = csv.rows[i];
      try {
        final dateStr = _getField(csv.headers, row, '交易时间');
        final counterparty = _getField(csv.headers, row, '交易对方');
        final description = _getField(csv.headers, row, '商品说明');
        final typeStr = _getField(csv.headers, row, '收/支');
        final amountStr = _getField(csv.headers, row, '金额');
        final paymentMethod = _getField(csv.headers, row, '收/付款方式');
        final externalId = _getField(csv.headers, row, '交易订单号');

        if (amountStr == null || dateStr == null) continue;

        final amount = double.tryParse(amountStr.trim());
        if (amount == null) continue;

        // 支付宝 "收/支"：支→expense，收→income，不计→skip
        final isExpense = typeStr == null || typeStr.contains('支');
        final type = isExpense ? 'expense' : 'income';

        // 过滤退款、充值、提现
        final desc = description ?? '';
        if (desc.contains('退款') || desc.contains('充值') || desc.contains('提现')) continue;

        entries.add(ParsedBillEntry(
          date: _normalizeDate(dateStr),
          type: type,
          amountFen: (amount * 100).round(),
          description: desc,
          counterparty: counterparty ?? '',
          paymentMethod: paymentMethod ?? '支付宝',
          externalId: externalId,
          source: 'alipay',
        ));
      } catch (_) {}
    }

    return entries;
  }

  static String? _getField(List<String> headers, List<String> row, String name) {
    final idx = headers.indexOf(name);
    if (idx < 0 || idx >= row.length) return null;
    final val = row[idx];
    return val.isEmpty ? null : val;
  }

  static String _normalizeDate(String raw) {
    final parts = raw.split(' ');
    return parts[0].replaceAll('/', '-');
  }
}
