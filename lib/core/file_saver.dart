// Web 端触发浏览器下载，桌面/移动端保存到本地文档目录。

export 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart';
