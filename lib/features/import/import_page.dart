import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'import_provider.dart';
import 'import_preview.dart';

/// 账单导入入口页面
class ImportPage extends ConsumerWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 如果有预览数据，跳转到预览页
    if (state.previewEntries.isNotEmpty) {
      return const ImportPreviewPage();
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('导入账单'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(importProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('选择账单来源'),
            const SizedBox(height: 12),
            _SourceCard(
              icon: Icons.chat_rounded,
              color: const Color(0xFF07C160),
              title: '微信账单',
              subtitle: '从微信导出的 CSV 账单文件',
              onTap: state.isParsing
                  ? null
                  : () => _pickAndParse(ref, 'wechat'),
            ),
            _SourceCard(
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF1677FF),
              title: '支付宝账单',
              subtitle: '从支付宝导出的 CSV 账单文件（支持 GBK 编码）',
              onTap: state.isParsing
                  ? null
                  : () => _pickAndParse(ref, 'alipay'),
            ),
            _SourceCard(
              icon: Icons.account_balance_rounded,
              color: const Color(0xFFD4380D),
              title: '银行卡账单',
              subtitle: '银行导出的 CSV 账单（通用模板，自动匹配字段）',
              onTap: state.isParsing
                  ? null
                  : () => _pickAndParse(ref, 'bank_csv'),
            ),
            if (state.isParsing) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '正在解析账单…',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            _helpSection(isDark),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndParse(WidgetRef ref, String source) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'CSV', 'txt', 'TXT'],
      allowMultiple: false,
      withData: true, // Web 端需要读取字节数据
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      // Web 端优先使用 bytes，桌面端也可用 path 读取后再转换为兼容
      if (file.bytes != null) {
        await ref
            .read(importProvider.notifier)
            .parseFile(file.bytes!, file.name, source);
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _helpSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E8ED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Text('如何导出账单？', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _helpItem('微信', '我 › 服务 › 钱包 › 账单 › 常见问题 › 下载账单 › 用于个人对账'),
          _helpItem('支付宝', '我的 › 账单 › 筛选 › 下载账单 › Excel格式'),
          _helpItem('银行', '手机银行APP › 交易明细 › 导出'),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String steps) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryLightest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              steps,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 账单来源卡片
class _SourceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SourceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E8ED),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
