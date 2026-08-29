import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// CSV 解析结果
class CsvParseResult {
  final List<String> headers;
  final List<List<String>> rows;
  final String encoding;
  final String delimiter;

  const CsvParseResult({
    required this.headers,
    required this.rows,
    this.encoding = 'UTF-8',
    this.delimiter = ',',
  });
}

/// 通用 CSV 解析器 — 自动检测编码、分隔符
/// 跨平台兼容（Web + 桌面 + 移动端）
class CsvParser {
  /// 从字节数组解析（自动检测 CSV / XLSX 格式）
  /// 适用于 Web 端 file_picker 返回值
  static Future<CsvParseResult> parse(
    Uint8List bytes, {
    String? fileName,
  }) async {
    // 检测 XLSX 文件
    if (fileName != null && _isXlsxFile(fileName)) {
      return _parseXlsx(bytes);
    }
    return _parseCsv(bytes);
  }

  /// 解析 CSV 文本
  static Future<CsvParseResult> _parseCsv(Uint8List bytes) async {
    // 自动检测编码
    String content;
    String encoding;

    if (_isUtf8Bom(bytes)) {
      content = utf8.decode(bytes.skip(3).toList());
      encoding = 'UTF-8-BOM';
    } else if (_isGbk(bytes)) {
      try {
        content = _decodeGbk(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      encoding = 'GBK';
    } else {
      content = utf8.decode(bytes);
      encoding = 'UTF-8';
    }

    // 检测分隔符
    final delimiter = _detectDelimiter(content);

    // 解析 CSV
    final rows = CsvToListConverter(fieldDelimiter: delimiter).convert(content);
    if (rows.isEmpty) throw Exception('CSV 文件为空');

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).map((row) {
      return row.map((e) => e.toString().trim()).toList();
    }).toList();

    return CsvParseResult(
      headers: headers,
      rows: dataRows,
      encoding: encoding,
      delimiter: delimiter,
    );
  }

  /// 从解析结果中根据字段映射提取数据
  static String? getField(
    List<String> headers,
    List<String> row,
    String fieldKey,
    Map<String, String> fieldMapping,
  ) {
    final csvHeader = fieldMapping[fieldKey];
    if (csvHeader == null) return null;
    final idx = headers.indexOf(csvHeader);
    if (idx < 0 || idx >= row.length) return null;
    final val = row[idx];
    return val.isEmpty ? null : val;
  }

  /// 检测是否为 UTF-8 BOM
  static bool _isUtf8Bom(List<int> bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
  }

  /// 简单 GBK 检测
  static bool _isGbk(List<int> bytes) {
    try {
      utf8.decode(bytes);
      return false;
    } catch (_) {
      return true;
    }
  }

  /// GBK 解码（简化实现）
  static String _decodeGbk(List<int> bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] < 0x80) {
        result.add(bytes[i]);
      } else {
        if (i + 1 < bytes.length) {
          final code = (bytes[i] << 8) | bytes[i + 1];
          if (code >= 0xA1A1 && code <= 0xF7FE) {
            final unicode = _gbkToUnicode(code);
            result.add(unicode);
            i++;
          } else {
            result.add(bytes[i]);
          }
        } else {
          result.add(bytes[i]);
        }
      }
    }
    return String.fromCharCodes(result);
  }

  /// 简化 GBK->Unicode 映射（覆盖常用字符）
  static int _gbkToUnicode(int gbk) {
    // 这里使用一个非常简化的映射表，覆盖记账相关的常见中文字符
    // 对于不在此范围内的字符，使用替代字符
    final high = (gbk >> 8) & 0xFF;
    final low = gbk & 0xFF;

    // 简单的 GBK 偏移映射（不完整，但覆盖大多数常用字符）
    if (high >= 0xA1 && high <= 0xA9 && low >= 0xA1 && low <= 0xFE) {
      return 0xFF00 + (high - 0xA0) * 0x5E + (low - 0xA1); // 近似
    }
    if (high >= 0xB0 && high <= 0xF7 && low >= 0xA1 && low <= 0xFE) {
      return 0x4E00 + (high - 0xB0) * 0x5E + (low - 0xA1); // 近似
    }

    // 返回替代字符
    return 0xFFFD; // U+FFFD
  }

  /// 检测分隔符
  static String _detectDelimiter(String content) {
    final firstLine = content.split('\n').first;
    final commas = ','.allMatches(firstLine).length;
    final tabs = '\t'.allMatches(firstLine).length;
    return tabs > commas ? '\t' : ',';
  }

  /// 判断是否为 XLSX 文件
  static bool _isXlsxFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.xlsx') || lower.endsWith('.xls');
  }

  /// 将 Excel CellValue 转为字符串
  static String _cellValueToStr(CellValue? cv) {
    if (cv == null) return '';
    if (cv is TextCellValue) return cv.value.toString();
    if (cv is DateTimeCellValue) {
      final dt = cv.asDateTimeLocal();
      final y = dt.year, mo = dt.month, d = dt.day;
      final h = dt.hour, mi = dt.minute, s = dt.second;
      return '$y/${_p2(mo)}/${_p2(d)} ${_p2(h)}:${_p2(mi)}:${_p2(s)}';
    }
    if (cv is DateCellValue) {
      return '${cv.year}/${_p2(cv.month)}/${_p2(cv.day)}';
    }
    if (cv is DoubleCellValue) {
      final n = cv.value;
      if (n > 40000 && n < 70000) {
        final d = _excelSerialToDate(n);
        if (d != null) return d;
      }
      return cv.value.toString();
    }
    if (cv is IntCellValue) return cv.value.toString();
    if (cv is BoolCellValue) return cv.value.toString();
    return cv.toString();
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');

  /// Excel 日期序列号转字符串 (yyyy/MM/dd HH:mm:ss)
  /// Excel 纪元：1899-12-30（Windows 默认）
  static String? _excelSerialToDate(double serial) {
    // Excel 1900 日期系统的纪元
    // ignore: prefer_const_constructors
    final excelEpoch = DateTime(1899, 12, 30);
    try {
      final days = serial.floor();
      final fraction = serial - days;
      final date = excelEpoch.add(Duration(days: days));
      if (fraction > 0) {
        final seconds = (fraction * 86400).round();
        final dt = date.add(Duration(seconds: seconds));
        return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      }
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  /// 解析 XLSX/XLS 文件，转换为 CsvParseResult
  /// 支持微信 / 支付宝 / 银行导出的 Excel 账单
  static CsvParseResult _parseXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) throw Exception('XLSX 文件中没有找到工作表');
    final table = excel.tables.values.first;

    // 找到表头行：查找第一个包含常见账单日期列名（如"交易时间"、"交易日期"）的行
    int headerRowIndex = 0;
    bool found = false;
    for (int i = 0; i < table.rows.length && i < 30; i++) {
      final row = table.rows[i];
      for (final cell in row) {
        final val = _cellValueToStr(cell?.value);
        if (val.contains('交易时间') ||
            val.contains('交易日期') ||
            val.contains('记账日期') ||
            val.contains('入账时间')) {
          headerRowIndex = i;
          found = true;
          break;
        }
      }
      if (found) break;
    }

    if (!found) {
      // 未找到中文表头，回退到第一行作为表头
      headerRowIndex = 0;
    }

    // 提取表头
    final headerRow = table.rows[headerRowIndex];
    final headers = headerRow
        .map((c) => _cellValueToStr(c?.value).trim())
        .toList();
    // 移除尾部空列
    while (headers.isNotEmpty && headers.last.isEmpty) {
      headers.removeLast();
    }

    // 提取数据行
    final dataRows = <List<String>>[];
    for (int i = headerRowIndex + 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rowData = <String>[];
      bool hasContent = false;
      for (int j = 0; j < headers.length && j < row.length; j++) {
        var val = '';
        if (j < row.length) {
          val = _cellValueToStr(row[j]?.value);
        }
        val = val.trim();
        if (val.isNotEmpty) hasContent = true;
        rowData.add(val);
      }
      // 跳过完全空行和分隔线行
      if (!hasContent || rowData.every((c) => c.startsWith('---'))) {
        continue;
      }
      dataRows.add(rowData);
    }

    if (dataRows.isEmpty && headers.isEmpty) {
      throw Exception('XLSX 文件解析后无数据，请检查文件格式');
    }

    return CsvParseResult(
      headers: headers,
      rows: dataRows,
      encoding: 'UTF-8',
      delimiter: ',',
    );
  }
}
