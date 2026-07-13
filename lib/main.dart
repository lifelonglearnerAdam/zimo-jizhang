import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants.dart';
import 'data/database.dart';

/// 全局错误信息，供 runApp 渲染
String? _fatalError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 初始化桌面窗口管理器（仅桌面端）
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      await _initWindowManager();
    }

    // 初始化数据库并插入默认分类
    await DatabaseService.instance.ensureInitialized();
  } catch (e, st) {
    _fatalError = '初始化失败: $e\n\n$st';
  }

  // 设置全局错误页面
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFFF2F4F7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFE76F51)),
            const SizedBox(height: 12),
            const Text(
              '页面加载出错',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Text(
              details.exceptionAsString(),
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
              maxLines: 20,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  };

  // 如果初始化失败，显示错误页面
  if (_fatalError != null) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_fatalError!, style: const TextStyle(fontSize: 14, color: Colors.red)),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(
    const ProviderScope(
      child: ZimoJizhangApp(),
    ),
  );
}

Future<void> _initWindowManager() async {
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    title: AppConstants.appName,
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
