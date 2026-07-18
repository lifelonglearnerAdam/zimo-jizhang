import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// 金额展示组件
///
/// 支持大号金额（用于仪表盘）和小号金额（用于列表）
class AmountDisplay extends StatelessWidget {
  final int amountFen;
  final AmountSize size;
  final Color? color;
  final bool showSymbol;
  final String? type; // 'expense' or 'income'

  const AmountDisplay({
    super.key,
    required this.amountFen,
    this.size = AmountSize.medium,
    this.color,
    this.showSymbol = true,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (type == 'income' ? AppColors.income : AppColors.expense);

    final prefix = type == 'expense' ? '-' : '';

    return Text(
      '$prefix${MoneyUtils.fenToYuan(amountFen, showSymbol: showSymbol)}',
      style: switch (size) {
        AmountSize.small => TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: effectiveColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        AmountSize.medium => TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        AmountSize.large => TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: effectiveColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        AmountSize.xlarge => TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: effectiveColor,
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      },
    );
  }
}

enum AmountSize { small, medium, large, xlarge }
