import 'package:flutter/material.dart';

/// 子墨记账 — 主题配置 v2
///
/// 设计哲学：克制、温暖、呼吸感
/// 墨绿色主色调 + 陶土橙支出色 + 渐变玻璃态卡片

class AppColors {
  AppColors._();

  // 主色调 — 墨绿系
  static const Color primary = Color(0xFF2D6A4F);
  static const Color primaryLight = Color(0xFF52B788);
  static const Color primaryLightest = Color(0xFFD8F3DC);
  static const Color primaryDark = Color(0xFF1B4332);

  // 渐变
  static const List<Color> primaryGradient = [Color(0xFF2D6A4F), Color(0xFF40916C)];
  static const List<Color> expenseGradient = [Color(0xFFE76F51), Color(0xFFF4A261)];
  static const List<Color> incomeGradient = [Color(0xFF2D6A4F), Color(0xFF52B788)];
  static const List<Color> cardGradient = [Color(0xFFFFFFFF), Color(0xFFF8FAF9)];

  // 背景
  static const Color background = Color(0xFFF5F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFAFBFC);

  // 金额
  static const Color expense = Color(0xFFE76F51);
  static const Color expenseLight = Color(0xFFFFF0EB);
  static const Color income = Color(0xFF2D6A4F);
  static const Color incomeLight = Color(0xFFE8F5E9);

  // 文字
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFC7C7CC);

  // 分割线
  static const Color divider = Color(0xFFE5E7EB);

  // 状态
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444);

  // 分类色板
  static const List<Color> categoryColors = [
    Color(0xFFE76F51), Color(0xFF2D6A4F), Color(0xFF457B9D),
    Color(0xFF6D597A), Color(0xFFB5838D), Color(0xFF52796F),
    Color(0xFF84A98C), Color(0xFFE9C46A), Color(0xFFA8DADC),
    Color(0xFFB7B7A4),
  ];
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double full = 999;
}

class AppShadows {
  AppShadows._();
  static const card = [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))];
  static const elevated = [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 4))];
  static const floating = [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8))];
  static const glow = [BoxShadow(color: Color(0x202D6A4F), blurRadius: 20, offset: Offset(0, 4))];
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null,

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        hintStyle: const TextStyle(color: AppColors.textHint),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        indicatorColor: AppColors.primaryLightest,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary);
          }
          return const TextStyle(fontSize: 11, color: AppColors.textSecondary);
        }),
      ),

      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        selectedLabelTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        indicatorColor: AppColors.primaryLightest,
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 0,
      ),

      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 0.5, space: 0),

      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.primaryLight,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(color: const Color(0xFF1E293B), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 1, backgroundColor: Color(0xFF0F172A)),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: const Color(0xFF1E293B), indicatorColor: AppColors.primary.withOpacity(0.3)),
      navigationRailTheme: const NavigationRailThemeData(backgroundColor: Color(0xFF1E293B)),
    );
  }
}
