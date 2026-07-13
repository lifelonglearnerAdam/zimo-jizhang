/// 桌面/移动端文件保存 —— 使用 dart:io
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// 保存文本文件到本地文档目录，返回文件路径
Future<String> saveTextFile(String name, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsString(content);
  return file.path;
}

/// 保存二进制文件到本地文档目录，返回文件路径
Future<String> saveBytesFile(String name, Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file.path;
}
