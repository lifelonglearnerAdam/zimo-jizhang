import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show databaseFactory, getDatabasesPath;

/// 为 Web 端初始化 IndexedDB 数据库工厂。
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

Future<String> resolveDatabasePath(String fileName) async {
  return p.join(await getDatabasesPath(), fileName);
}
