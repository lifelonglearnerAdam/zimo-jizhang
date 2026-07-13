import '../../core/csv_parser.dart';
import '../../data/models.dart';

/// 微信账单解析器
class WechatParser {
  /// 解析微信账单 CSV
  static List<ParsedBillEntry> parse(CsvParseResult csv) {
    final entries = <ParsedBillEntry>[];
    final rule = _defaultRule();

    for (var i = 0; i < csv.rows.length; i++) {
      final row = csv.rows[i];
      try {
        final dateStr = CsvParser.getField(csv.headers, row, 'date', rule);
        final typeStr = CsvParser.getField(csv.headers, row, 'type', rule);
        final counterparty = CsvParser.getField(csv.headers, row, 'counterparty', rule);
        final description = CsvParser.getField(csv.headers, row, 'description', rule);
        final amountStr = CsvParser.getField(csv.headers, row, 'amount', rule);
        final paymentMethod = CsvParser.getField(csv.headers, row, 'payment_method', rule);
        final externalId = CsvParser.getField(csv.headers, row, 'external_id', rule);

        if (amountStr == null || dateStr == null) continue;

        // 微信表头可能有 "¥" 前缀
        final cleanAmount = amountStr.replaceFirst('¥', '').trim();
        final amount = double.tryParse(cleanAmount);
        if (amount == null) continue;

        // 微信 "收/支" 字段：支出→expense，收入→income
        final isExpense = typeStr == null || typeStr.contains('支出') || typeStr == '支';
        final type = isExpense ? 'expense' : 'income';

        // 过滤微信红包和转账
        final desc = description ?? '';
        if (desc.contains('微信红包') || desc.contains('转账')) continue;

        entries.add(ParsedBillEntry(
          date: _normalizeDate(dateStr),
          type: type,
          amountFen: (amount * 100).round(),
          description: desc,
          counterparty: counterparty ?? '',
          paymentMethod: paymentMethod ?? '微信',
          externalId: externalId,
          source: 'wechat',
        ));
      } catch (_) {
        // 跳过格式不对的行
      }
    }

    return entries;
  }

  static String _normalizeDate(String raw) {
    // 微信日期格式通常为 yyyy/MM/dd HH:mm:ss，取日期部分
    final parts = raw.split(' ');
    var date = parts[0];
    date = date.replaceAll('/', '-');
    return date;
  }

  static Map<String, String> _defaultRule() => {
        'date': '交易时间',
        'type': '收/支',
        'counterparty': '交易对方',
        'description': '商品',
        'amount': '金额(元)',
        'payment_method': '支付方式',
        'external_id': '交易单号',
      };
}

/// 解析后的账单条目
class ParsedBillEntry {
  final String date;
  final String type; // 'expense' | 'income'
  final int amountFen;
  final String description;
  final String counterparty;
  final String paymentMethod;
  final String? externalId;
  final String source; // 'wechat' | 'alipay' | 'bank_csv'

  const ParsedBillEntry({
    required this.date,
    this.type = 'expense',
    required this.amountFen,
    this.description = '',
    this.counterparty = '',
    this.paymentMethod = '',
    this.externalId,
    this.source = 'wechat',
  });
}
