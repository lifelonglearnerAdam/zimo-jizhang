import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
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

/// 使用稳定的用户数据目录，并只复制迁移旧版相对路径数据库。
Future<String> resolveDatabasePath(String fileName) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return p.join(await getDatabasesPath(), fileName);
  }

  final supportDirectory = await getApplicationSupportDirectory();
  final databaseDirectory = Directory(
    p.join(supportDirectory.path, 'databases'),
  );
  await databaseDirectory.create(recursive: true);
  final stablePath = p.join(databaseDirectory.path, fileName);

  final stableFile = File(stablePath);
  if (!await stableFile.exists()) {
    final userProfile = Platform.environment['USERPROFILE'];
    final candidates = <String>{
      p.join(await getDatabasesPath(), fileName),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        '.dart_tool',
        'sqflite_common_ffi',
        'databases',
        fileName,
      ),
      if (userProfile != null)
        p.join(
          userProfile,
          'Desktop',
          '.dart_tool',
          'sqflite_common_ffi',
          'databases',
          fileName,
        ),
    };

    final existing = <File>[];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) existing.add(file);
    }
    if (existing.isNotEmpty) {
      existing.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      await existing.first.copy(stablePath);
    }
  }

  return stablePath;
}
