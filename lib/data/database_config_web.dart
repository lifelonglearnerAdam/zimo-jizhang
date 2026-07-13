import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// 为 Web 端初始化 IndexedDB 数据库工厂。
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
