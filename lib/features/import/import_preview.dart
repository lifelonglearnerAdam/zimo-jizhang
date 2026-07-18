import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers/category_provider.dart';
import 'import_provider.dart';

/// 导入预览页 — 展示解析结果，允许用户调整分类后确认导入
class ImportPreviewPage extends ConsumerStatefulWidget {
  const ImportPreviewPage({super.key});

  @override
  ConsumerState<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends ConsumerState<ImportPreviewPage> {
  /// index -> categoryId
  final Map<int, int> _categoryAssignments = {};
  bool _showAll = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = _showAll
        ? state.previewEntries
        : state.previewEntries.where((e) => !e.isDuplicate).toList();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('预览导入 (${entries.length}条)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => ref.read(importProvider.notifier).reset(),
        ),
      ),
      body: Column(
        children: [
          // 统计栏
          _buildStatsBar(state, isDark),
          // 筛选开关
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('显示全部', style: TextStyle(fontSize: 13)),
                Switch(
                  value: _showAll,
                  onChanged: (v) => setState(() => _showAll = v),
                  activeColor: AppColors.primary,
                ),
                if (!_showAll)
                  Text(
                    '已隐藏${state.previewEntries.where((e) => e.isDuplicate).length}条重复',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('智能分类', style: TextStyle(fontSize: 12)),
                  onPressed: _autoCategorize,
                ),
              ],
            ),
          ),
          // 条目列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: entries.length,
              itemBuilder: (ctx, i) => _buildEntryRow(entries[i], isDark),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildStatsBar(ImportState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('总计', '${state.previewEntries.length}条', AppColors.primary),
          _statItem(
            '新记录',
            '${state.previewEntries.where((e) => !e.isDuplicate).length}条',
            const Color(0xFF52C41A),
          ),
          _statItem(
            '重复',
            '${state.previewEntries.where((e) => e.isDuplicate).length}条',
            const Color(0xFFFAAD14),
          ),
          _statItem(
            '已分类',
            '${_categoryAssignments.length}条',
            AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildEntryRow(ImportPreviewEntry entry, bool isDark) {
    final hasCategory = _categoryAssignments.containsKey(entry.index);
    final catId = _categoryAssignments[entry.index];
    final catName = hasCategory
        ? (ref.read(allCategoriesProvider).valueOrNull ?? [])
                  .where((c) => c.id == catId)
                  .firstOrNull
                  ?.name ??
              '已选'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: entry.isDuplicate
            ? (isDark
                  ? Colors.red.withOpacity(0.08)
                  : Colors.red.withOpacity(0.04))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: entry.isDuplicate
            ? Border.all(color: Colors.red.withOpacity(0.2))
            : Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE8E8ED),
              ),
      ),
      child: Row(
        children: [
          // 收支图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: entry.type == 'income'
                  ? AppColors.incomeLight
                  : AppColors.expenseLight,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(
              entry.type == 'income'
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 16,
              color: entry.type == 'income'
                  ? AppColors.income
                  : AppColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.counterparty.isNotEmpty) ...[
                      Expanded(
                        child: Text(
                          entry.counterparty,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          entry.description.isNotEmpty
                              ? entry.description
                              : '无描述',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      entry.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (entry.paymentMethod.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          entry.paymentMethod,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                    if (entry.isDuplicate) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '重复',
                          style: TextStyle(fontSize: 10, color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 金额
          Text(
            '${entry.type == 'income' ? '+' : '-'}¥${(entry.amountFen / 100).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: entry.type == 'income'
                  ? AppColors.income
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          // 分类选择
          GestureDetector(
            onTap: entry.isDuplicate ? null : () => _showCategoryPicker(entry),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: hasCategory
                    ? AppColors.primaryLightest
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF0F0F5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                catName ?? '选分类',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: hasCategory
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(ImportPreviewEntry entry) {
    final parentCats = ref.read(parentCategoriesProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final type = entry.type;
        final filteredParents = parentCats.where((c) {
          // 简单判断：收入类分类名包含特定关键词 或者 支出类
          final isIncomeCat =
              c.name.contains('收入') ||
              c.name.contains('工资') ||
              c.name.contains('奖金');
          return type == 'income' ? isIncomeCat : !isIncomeCat;
        }).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              const Text(
                '选择分类',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredParents.length,
                  itemBuilder: (_, i) {
                    final parent = filteredParents[i];
                    final subs =
                        ref
                            .read(subCategoriesProvider(parent.id))
                            .valueOrNull ??
                        [];
                    return ExpansionTile(
                      leading: Text(
                        parent.icon ?? '📌',
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(
                        entry.type == 'income' ? parent.name : parent.name,
                      ),
                      children: subs
                          .map(
                            (sub) => ListTile(
                              leading: Text(
                                sub.icon ?? '📌',
                                style: const TextStyle(fontSize: 18),
                              ),
                              title: Text(sub.name),
                              onTap: () {
                                setState(
                                  () => _categoryAssignments[entry.index] =
                                      sub.id,
                                );
                                Navigator.pop(ctx);
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _autoCategorize() {
    final allCats = ref.read(allSubCategoriesProvider).valueOrNull ?? [];
    if (allCats.isEmpty) return;

    final state = ref.read(importProvider);
    final newEntries = <ImportPreviewEntry>[];

    for (final entry in state.previewEntries) {
      if (entry.isDuplicate || _categoryAssignments.containsKey(entry.index)) {
        newEntries.add(entry);
        continue;
      }

      // 基于简单关键词匹配做自动分类
      final text = '${entry.description} ${entry.counterparty}';
      int? bestCatId;
      int bestScore = 0;

      // 关键词规则（借鉴 BeeCount 思路）
      final rules = <String, List<String>>{
        '餐饮': [
          '饭',
          '餐',
          '外卖',
          '奶茶',
          '咖啡',
          '面',
          '米粉',
          '小吃',
          '烧烤',
          '火锅',
          '面包',
          '蛋糕',
          '水果',
        ],
        '交通': ['打车', '滴滴', '地铁', '公交', '加油', '停车', '高速', 'ETC', '骑行', '共享'],
        '购物': ['超市', '便利店', '淘宝', '京东', '拼多多', '天猫', '商场', '百货', '屈臣氏'],
        '居住': ['房租', '物业', '水电', '燃气', '宽带', '暖气'],
        '通讯': ['话费', '流量', '充值', '移动', '联通', '电信'],
        '医疗': ['医院', '药', '挂号', '门诊', '体检'],
        '教育': ['书', '课程', '培训', '考试', '学费'],
        '娱乐': ['电影', '游戏', 'KTV', '演出', '会员', '视频', '音乐'],
        '服饰': ['衣服', '鞋', '包', '美妆', '护肤', '饰品'],
      };

      for (final rule in rules.entries) {
        for (final kw in rule.value) {
          if (text.contains(kw)) {
            // 找关键词对应的分类
            for (final cat in allCats) {
              if (cat.category.name.contains(rule.key)) {
                bestCatId = cat.category.id;
                bestScore = 5;
                break;
              }
            }
            if (bestCatId != null) break;
          }
        }
        if (bestCatId != null) break;
      }

      if (bestCatId != null) {
        _categoryAssignments[entry.index] = bestCatId;
      }

      newEntries.add(entry);
    }

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已自动为${_categoryAssignments.length}条记录匹配分类'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildBottomBar(ImportState state) {
    final unassigned = state.previewEntries
        .where(
          (e) => !e.isDuplicate && !_categoryAssignments.containsKey(e.index),
        )
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (unassigned > 0)
              Text(
                '$unassigned 条未分类',
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(importProvider.notifier).reset(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: state.isImporting
                  ? null
                  : () => ref
                        .read(importProvider.notifier)
                        .confirmImport(
                          categoryAssignments: _categoryAssignments,
                        ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: state.isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('确认导入'),
            ),
          ],
        ),
      ),
    );
  }
}
