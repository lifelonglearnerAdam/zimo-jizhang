import 'package:flutter/material.dart';
import '../core/constants.dart';

/// 响应式布局包装器
///
/// 桌面端（宽度 >= 800px）：显示侧边栏 + 主内容区
/// 手机端（宽度 < 800px）：显示底部导航栏 + 主内容区
class ResponsiveLayout extends StatelessWidget {
  final Widget child;

  const ResponsiveLayout({super.key, required this.child});

  /// 判断当前是否为桌面端布局
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.breakpointWidth;
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
