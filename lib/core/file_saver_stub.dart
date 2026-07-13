/// Web 端文件保存 — 暂不实现下载，保证页面正常加载
import 'dart:typed_data';

/// 保存文本文件（Web 端暂不支持直接下载）
Future<String?> saveTextFile(String fileName, String content) async {
  // TODO: 后续通过 JS interop 实现下载
  return null;
}

/// 保存二进制文件（Web 端暂不支持直接下载）
Future<String?> saveBytesFile(String fileName, Uint8List bytes) async {
  // TODO: 后续通过 JS interop 实现下载
  return null;
}
