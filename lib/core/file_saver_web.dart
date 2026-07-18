// Web 端文件保存：触发浏览器下载，不依赖服务器。
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveTextFile(String fileName, String content) async {
  return _download(
    fileName,
    Uint8List.fromList(content.codeUnits),
    'text/plain;charset=utf-8',
  );
}

Future<String?> saveBytesFile(String fileName, Uint8List bytes) async {
  return _download(fileName, bytes, 'application/octet-stream');
}

Future<String?> _download(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
