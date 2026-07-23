import "package:sqflite/sqflite.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';

enum AppThemeMode { light, dark, system }

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>(
      (ref) => ThemeModeNotifier(),
    );

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      if (rows.isNotEmpty) {
        final v = rows.first['value'] as String;
        state = AppThemeMode.values.firstWhere(
          (e) => e.name == v,
          orElse: () => AppThemeMode.light,
        );
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    final db = await DatabaseService.instance.database;
    await db.insert('settings', {
      'key': 'theme_mode',
      'value': mode.name,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
