import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 为桌面端（Windows/Linux/macOS）初始化 FFI 数据库工厂。
/// 在 Android/iOS 上不执行任何操作，使用原生 sqflite 平台通道。
void configureDatabaseFactory() {
  if (Platform.isAndroid || Platform.isIOS) {
    // 使用默认 sqflite 平台通道 — 无需操作
    return;
  }
  // 桌面端：初始化 FFI 并设置数据库工厂
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
