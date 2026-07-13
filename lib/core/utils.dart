import 'package:intl/intl.dart';

/// 金额工具函数
class MoneyUtils {
  MoneyUtils._();

  static NumberFormat? _cachedFormat;

  /// 获取 NumberFormat，失败时回退到默认 locale
  static NumberFormat get _format {
    if (_cachedFormat != null) return _cachedFormat!;
    try {
      _cachedFormat = NumberFormat('#,##0.00', 'zh_CN');
    } catch (_) {
      try {
        _cachedFormat = NumberFormat('#,##0.00');
      } catch (_) {
        // 极端情况：手动格式化
        _cachedFormat = null;
      }
    }
    return _cachedFormat ?? NumberFormat('#,##0.00');
  }

  static NumberFormat? _cachedShortFormat;
  static NumberFormat get _shortFormat {
    if (_cachedShortFormat != null) return _cachedShortFormat!;
    try {
      _cachedShortFormat = NumberFormat('#,##0', 'zh_CN');
    } catch (_) {
      _cachedShortFormat = NumberFormat('#,##0');
    }
    return _cachedShortFormat!;
  }

  /// 分转元字符串（用于显示）
  /// [fen] 金额，单位：分
  /// [showSymbol] 是否显示 ¥ 符号
  static String fenToYuan(int fen, {bool showSymbol = true}) {
    final yuan = fen / 100.0;
    String formatted;
    try {
      formatted = _format.format(yuan);
    } catch (_) {
      formatted = yuan.toStringAsFixed(2);
    }
    return showSymbol ? '¥$formatted' : formatted;
  }

  /// 元转分
  static int yuanToFen(double yuan) {
    return (yuan * 100).round();
  }

  /// 格式化金额为简短展示（如 ¥1,280）
  static String fenToShort(int fen) {
    final yuan = fen / 100.0;
    String formatted;
    try {
      if (yuan == yuan.roundToDouble()) {
        formatted = _shortFormat.format(yuan.round());
      } else {
        formatted = _format.format(yuan);
      }
    } catch (_) {
      formatted = yuan.toStringAsFixed(2);
    }
    return '¥$formatted';
  }
}

/// 日期工具函数（命名 AppDateUtils 避免与 Flutter Material DateUtils 冲突）
class AppDateUtils {
  AppDateUtils._();

  static DateFormat? _cachedMonthFormatter;
  static DateFormat? _cachedWeekdayFormatter;

  static DateFormat get _monthFormatter {
    if (_cachedMonthFormatter != null) return _cachedMonthFormatter!;
    try {
      _cachedMonthFormatter = DateFormat('yyyy年M月', 'zh_CN');
    } catch (_) {
      _cachedMonthFormatter = DateFormat('yyyy年M月');
    }
    return _cachedMonthFormatter!;
  }

  static DateFormat get _weekdayFormatter {
    if (_cachedWeekdayFormatter != null) return _cachedWeekdayFormatter!;
    try {
      _cachedWeekdayFormatter = DateFormat('EEEE', 'zh_CN');
    } catch (_) {
      _cachedWeekdayFormatter = DateFormat('EEEE');
    }
    return _cachedWeekdayFormatter!;
  }

  static final _dateFormatter = DateFormat('yyyy-MM-dd');
  static final _displayFormatter = DateFormat('M月d日');

  /// 今天的日期字符串
  static String today() => _dateFormatter.format(DateTime.now());

  /// 当前月份字符串
  static String currentMonth() => _monthFormatter.format(DateTime.now());

  /// 格式化日期为显示格式（M月d日）
  static String toDisplay(String dateStr) {
    final date = DateTime.parse(dateStr);
    return _displayFormatter.format(date);
  }

  /// 格式化日期，带星期
  static String toDisplayWithWeekday(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${_displayFormatter.format(date)} ${_weekdayFormatter.format(date)}';
  }

  /// 本月第一天
  static String firstDayOfMonth(DateTime date) {
    return _dateFormatter.format(DateTime(date.year, date.month, 1));
  }

  /// 本月最后一天
  static String lastDayOfMonth(DateTime date) {
    return _dateFormatter.format(DateTime(date.year, date.month + 1, 0));
  }

  /// 上个月第一天
  static String firstDayOfLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    return _dateFormatter.format(lastMonth);
  }

  /// 上个月最后一天
  static String lastDayOfLastMonth() {
    final now = DateTime.now();
    return _dateFormatter.format(DateTime(now.year, now.month, 0));
  }

  /// 获取月份字符串
  static String toMonthLabel(String dateStr) {
    final date = DateTime.parse(dateStr);
    return _monthFormatter.format(date);
  }
}
