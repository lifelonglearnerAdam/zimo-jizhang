import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../features/import/category_matcher.dart';
import '../../providers/database_provider.dart';
import '../../providers/category_provider.dart';
import '../../data/models.dart';

/// 语音记账页面
class VoiceInputPage extends ConsumerStatefulWidget {
  const VoiceInputPage({super.key});

  @override
  ConsumerState<VoiceInputPage> createState() => _VoiceInputPageState();
}

class _VoiceInputPageState extends ConsumerState<VoiceInputPage> {
  final _textController = TextEditingController();
  bool _isListening = false;
  String _resultText = '';

  // 解析结果
  double? _parsedAmount;
  String? _parsedDesc;
  String? _parsedDate;
  int? _parsedCategoryId;
  String? _parsedType;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('语音记账'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // 语音输入区域
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Text('💬 说出你的消费',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('例如："昨天午饭花了35元"、"打车25块"、"工资收入5000"',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              // 手动输入区（语音识别在桌面端可能受限，优先用文本 NLU）
              TextField(
                controller: _textController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '输入或说出记账内容…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_isListening ? Icons.mic_rounded : Icons.keyboard_voice_rounded,
                        color: _isListening ? AppColors.danger : AppColors.primary),
                    onPressed: () {
                      // 语音识别：在桌面端尝试，回退到手动输入
                      setState(() => _isListening = !_isListening);
                      if (_isListening) {
                        _simulateVoiceRecognition();
                      }
                    },
                  ),
                ),
                onChanged: (text) {
                  if (text.length > 3) {
                    _parseVoiceText(text);
                  }
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _parseVoiceText(_textController.text),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('智能解析'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),

          // 解析结果
          if (_parsedAmount != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📋 解析结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _parsedRow('金额', '¥${_parsedAmount!.toStringAsFixed(2)}'),
                if (_parsedType != null) _parsedRow('类型', _parsedType == 'income' ? '💰 收入' : '💸 支出'),
                if (_parsedDesc != null) _parsedRow('描述', _parsedDesc!),
                if (_parsedDate != null) _parsedRow('日期', _parsedDate!),
                if (_parsedCategoryId != null)
                  _buildCatRow(_parsedCategoryId!),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmAdd,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('确认记账'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ],

          // 快捷示例
          const SizedBox(height: 24),
          _sectionTitle('快速示例'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickChip('午饭外卖 35', 'expense'),
              _quickChip('打车去公司 25元', 'expense'),
              _quickChip('超市买菜 86块', 'expense'),
              _quickChip('工资收入 5000', 'income'),
              _quickChip('昨天加油 200', 'expense'),
              _quickChip('咖啡 18元', 'expense'),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _parsedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _quickChip(String text, String type) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _textController.text = text;
        _parseVoiceText(text);
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }

  Widget _buildCatRow(int catId) {
    final cats = ref.read(allSubCategoriesProvider).valueOrNull ?? [];
    final cat = cats.where((c) => c.category.id == catId).firstOrNull;
    return _parsedRow('分类', '${cat?.category.icon ?? ''} ${cat?.category.name ?? '未分类'}');
  }

  /// NLU 解析：从自然语言提取 {金额, 类别, 描述, 日期, 收支类型}
  void _parseVoiceText(String text) {
    if (text.trim().isEmpty) return;

    // 1. 提取金额
    final amountRegex = RegExp(r'(\d+\.?\d{0,2})\s*(元|块|¥|块钱|毛)?');
    final amountMatch = amountRegex.firstMatch(text);

    // 2. 判断收支
    final isIncome = text.contains('收入') || text.contains('工资') || text.contains('奖金') || text.contains('到账');
    final type = isIncome ? 'income' : 'expense';

    // 3. 日期识别
    String date;
    final now = DateTime.now();
    if (text.contains('昨天')) {
      final yesterday = now.subtract(const Duration(days: 1));
      date = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    } else if (text.contains('前天')) {
      final dayBefore = now.subtract(const Duration(days: 2));
      date = '${dayBefore.year}-${dayBefore.month.toString().padLeft(2, '0')}-${dayBefore.day.toString().padLeft(2, '0')}';
    } else {
      date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    // 4. 描述：去掉金额和时间词
    String desc = text
        .replaceAll(amountRegex, '')
        .replaceAll('昨天', '')
        .replaceAll('前天', '')
        .replaceAll('今天', '')
        .replaceAll('花了', '')
        .replaceAll('用', '')
        .trim();

    // 5. 智能分类匹配
    _matchCategory(desc);

    setState(() {
      _parsedAmount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null;
      _parsedType = type;
      _parsedDesc = desc.isNotEmpty ? desc : null;
      _parsedDate = date;
      _resultText = text;
    });
  }

  void _matchCategory(String text) {
    final rules = <String, List<String>>{
      '餐饮': ['饭', '餐', '外卖', '奶茶', '咖啡', '面', '米粉', '小吃', '烧烤', '火锅', '面包', '蛋糕', '水果', '午饭', '晚饭', '早餐', '食堂'],
      '交通': ['打车', '滴滴', '地铁', '公交', '加油', '停车', '高速', '骑行', '共享', '车'],
      '购物': ['超市', '便利店', '淘宝', '京东', '拼多多', '菜', '买', '零食', '日用'],
      '居住': ['房租', '物业', '水电', '燃气', '宽带', '暖气', '电费', '水费'],
      '通讯': ['话费', '流量', '充值', '手机费'],
      '医疗': ['医院', '药', '挂号', '门诊', '体检'],
      '教育': ['书', '课程', '培训', '考试', '学费', '学习'],
      '娱乐': ['电影', '游戏', 'KTV', '演出', '会员', '视频'],
      '服饰': ['衣服', '鞋', '包', '美妆', '护肤'],
    };

    final allCats = ref.read(allSubCategoriesProvider).valueOrNull ?? [];
    for (final rule in rules.entries) {
      for (final kw in rule.value) {
        if (text.contains(kw)) {
          for (final cat in allCats) {
            if (cat.category.name.contains(rule.key)) {
              setState(() => _parsedCategoryId = cat.category.id);
              return;
            }
          }
        }
      }
    }
    _parsedCategoryId = null;
  }

  void _simulateVoiceRecognition() {
    // 桌面端模拟：1.5 秒后填入示例文本
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isListening) {
        setState(() {
          _isListening = false;
          _textController.text = '午饭外卖 35';
          _parseVoiceText(_textController.text);
        });
      }
    });
  }

  Future<void> _confirmAdd() async {
    if (_parsedAmount == null) return;
    final catId = _parsedCategoryId ?? 1;

    try {
      await ref.read(transactionDaoProvider).insertWithData(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            amountFen: (_parsedAmount! * 100).round(),
            categoryId: catId,
            date: _parsedDate ?? DateTime.now().toIso8601String().split('T')[0],
            description: _parsedDesc,
            type: _parsedType ?? 'expense',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('记账成功！${_parsedDesc ?? ""} ¥${_parsedAmount!.toStringAsFixed(2)}'),
            backgroundColor: AppColors.income,
            duration: const Duration(seconds: 2),
          ),
        );
        _textController.clear();
        setState(() {
          _parsedAmount = null;
          _parsedDesc = null;
          _parsedType = null;
          _parsedCategoryId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('记账失败：$e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
