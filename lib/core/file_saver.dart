/// 跨平台文件保存
/// Web 端触发浏览器下载，桌面/移动端保存到本地文档目录
import 'package:flutter/foundation.dart' show kIsWeb;

export 'file_saver_stub.dart' if (dart.library.io) 'file_saver_io.dart';
