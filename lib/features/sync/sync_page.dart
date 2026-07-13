import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/database_provider.dart';
import 'sync_service.dart';

/// 数据同步页面
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _message;
  bool _isSuccess = true;

  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _showWebdav = false;

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('数据同步'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('本地备份'),
          const SizedBox(height: 8),
          _buildCard(isDark, icon: Icons.file_download_rounded, title: '导出 JSON 备份', subtitle: '将所有交易记录导出为 JSON 文件', trailing: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : ElevatedButton.icon(onPressed: _exportData, icon: const Icon(Icons.save_alt_rounded, size: 18), label: const Text('导出'), style: _btnStyle())),
          _buildCard(isDark, icon: Icons.file_upload_rounded, title: '从 JSON 文件导入', subtitle: '选择 JSON 备份文件进行导入（自动差分合并）', trailing: _isImporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : ElevatedButton.icon(onPressed: _importData, icon: const Icon(Icons.file_open_rounded, size: 18), label: const Text('导入'), style: _btnStyle())),
          const SizedBox(height: 24),
          _sectionTitle('云端同步（WebDAV）'),
          const SizedBox(height: 8),
          _buildCard(isDark, icon: Icons.cloud_sync_rounded, title: 'WebDAV 同步', subtitle: '连接坚果云等 WebDAV 服务，实现手机与电脑数据互通', trailing: Switch(value: _showWebdav, activeColor: AppColors.primary, onChanged: (v) => setState(() => _showWebdav = v))),
          if (_showWebdav) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(children: [
              _buildTextField('WebDAV 地址', _urlController, hint: 'https://dav.jianguoyun.com/dav/zimo'),
              const SizedBox(height: 10),
              _buildTextField('用户名', _userController),
              const SizedBox(height: 10),
              _buildTextField('密码', _passController, isPassword: true),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: Row(children: [
                Expanded(child: ElevatedButton.icon(onPressed: _uploadToWebdav, icon: const Icon(Icons.cloud_upload_rounded, size: 18), label: const Text('上传'), style: _btnStyle())),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(onPressed: _downloadFromWebdav, icon: const Icon(Icons.cloud_download_rounded, size: 18), label: const Text('下载'), style: _btnStyle())),
              ])),
            ])),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (_isSuccess ? AppColors.incomeLight : AppColors.danger.withOpacity(0.1)), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(_isSuccess ? Icons.check_circle_outline : Icons.error_outline, size: 20, color: _isSuccess ? AppColors.income : AppColors.danger), const SizedBox(width: 8), Expanded(child: Text(_message!, style: TextStyle(fontSize: 13, color: _isSuccess ? AppColors.income : AppColors.danger)))])),
          ],
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final txDao = ref.read(transactionDaoProvider);
      final service = SyncService(txDao);
      final path = await service.exportToFile();
      if (path != null) {
        _showMsg('导出成功！文件位于：$path', true);
      } else {
        _showMsg('导出成功！文件已下载', true);
      }
    } catch (e) { _showMsg('导出失败：$e', false); }
    setState(() => _isExporting = false);
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      _showMsg('无法读取文件', false);
      return;
    }
    setState(() => _isImporting = true);
    try {
      final txDao = ref.read(transactionDaoProvider);
      final service = SyncService(txDao);
      final syncResult = await service.importFromBytes(file.bytes!);
      _showMsg('导入完成！新增 ${syncResult.imported} 条，跳过 ${syncResult.skipped} 条（已是最新）', true);
    } catch (e) { _showMsg('导入失败：$e', false); }
    setState(() => _isImporting = false);
  }

  Future<void> _uploadToWebdav() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _message = '正在上传…');
    try {
      final txDao = ref.read(transactionDaoProvider);
      final service = SyncService(txDao);
      final ok = await service.uploadToWebdav(_urlController.text.trim(), _userController.text.trim(), _passController.text.trim());
      _showMsg(ok ? '上传成功！' : '上传失败，请检查配置', ok);
    } catch (e) { _showMsg('上传失败：$e', false); }
  }

  Future<void> _downloadFromWebdav() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _message = '正在下载…');
    try {
      final txDao = ref.read(transactionDaoProvider);
      final service = SyncService(txDao);
      final json = await service.downloadFromWebdav(_urlController.text.trim(), _userController.text.trim(), _passController.text.trim());
      if (json != null) {
        final syncResult = await service.importFromJson(json);
        _showMsg('同步完成！新增 ${syncResult.imported} 条，跳过 ${syncResult.skipped} 条', true);
      } else { _showMsg('下载失败，请检查配置', false); }
    } catch (e) { _showMsg('下载失败：$e', false); }
  }

  void _showMsg(String msg, bool success) => setState(() { _message = msg; _isSuccess = success; });
  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));
  Widget _buildCard(bool isDark, {required IconData icon, required String title, required String subtitle, required Widget trailing}) => Card(margin: const EdgeInsets.only(bottom: 8), color: isDark ? const Color(0xFF1E293B) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryLightest, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Icon(icon, color: AppColors.primary, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))])), trailing])));
  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false, String? hint}) => TextField(controller: controller, obscureText: isPassword, decoration: InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), isDense: true));
  ButtonStyle _btnStyle() => ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)));
}
