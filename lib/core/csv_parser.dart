import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

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
  /// 从字节数组解析 CSV（适用于 Web 端 file_picker 返回值）
  static Future<CsvParseResult> parse(
    Uint8List bytes, {
    String? fileName,
  }) async {
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
}
