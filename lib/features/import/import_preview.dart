import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers/category_provider.dart';
import '../../providers/database_provider.dart';
import 'category_matcher.dart';
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
  /// 用户主动选中的条目 index（仅选中的会被导入）
  final Set<int> _selectedIndices = {};
  /// 退款抵消配对：两个抵消条目的 index → 配对另一方的 index
  final Map<int, int> _refundPairs = {};
  bool _showAll = true;
  bool _refundsDetected = false;

  @override
  void initState() {
    super.initState();
    // 等 build 完后自动检测退款配对
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectRefundPairs());
  }

  /// 自动检测美团等平台的「购买+退款」配对
  void _detectRefundPairs() {
    if (_refundsDetected) return;
    _refundsDetected = true;
    final state = ref.read(importProvider);
    final entries = state.previewEntries;
    if (entries.isEmpty) return;

    // 常见外卖/团购平台关键词
    const refundPlatforms = ['美团', '饿了么', '大众点评', '滴滴', '花小猪', '京东', '淘宝', '拼多多'];

    for (int i = 0; i < entries.length; i++) {
      if (_refundPairs.containsKey(i)) continue;
      final a = entries[i];
      final aName = '${a.counterparty}${a.description}';
      final isRefundA = a.type == 'income' ||
          aName.contains('退款') || aName.contains('返还') ||
          aName.contains('退') || aName.contains('返款');

      // 只处理可能是退款的记录
      if (!isRefundA && a.type != 'expense') continue;

      for (int j = i + 1; j < entries.length; j++) {
        if (_refundPairs.containsKey(j)) continue;
        final b = entries[j];
        final bName = '${b.counterparty}${b.description}';
        final isRefundB = b.type == 'income' ||
            bName.contains('退款') || bName.contains('返还') ||
            bName.contains('退') || bName.contains('返款');

        // 必须一个支出一个收入
        if (a.type == b.type) continue;

        // 金额相等（取绝对值）
        if (a.amountFen != b.amountFen) continue;

        // 同一天
        if (a.date != b.date) continue;

        // 同一平台（通过关键词判断）
        bool samePlatform = false;
        for (final pf in refundPlatforms) {
          if (aName.contains(pf) && bName.contains(pf)) {
            samePlatform = true;
            break;
          }
        }
        // 或者交易对手完全相同
        if (!samePlatform && a.counterparty != b.counterparty) continue;
        // 如果是同一对手方但不是退款场景，也跳过
        if (!samePlatform && !isRefundA && !isRefundB) continue;

        // 找到了！标记配对
        _refundPairs[i] = j;
        _refundPairs[j] = i;
        break;
      }
    }

    if (_refundPairs.isNotEmpty) {
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已自动识别 ${_refundPairs.length ~/ 2} 对退款抵消，默认排除'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () {
                setState(() => _refundPairs.clear());
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importProvider);

    // ★ 持续 watch 这两个 provider，确保分类数据始终可用
    final parentsAsync = ref.watch(parentCategoriesProvider);
    final allSubsAsync = ref.watch(allSubCategoriesProvider);

    final parentCats = parentsAsync.valueOrNull ?? [];
    final allSubs = allSubsAsync.valueOrNull ?? [];

    // 构建 parentId → subCategories 映射
    final subCatsMap = <int, List<CategoryModel>>{};
    for (final s in allSubs) {
      final parentId = s.category.parentId;
      if (parentId != null) {
        subCatsMap.putIfAbsent(parentId, () => []).add(s.category);
      }
    }

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
          _buildStatsBar(state, isDark),
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: entries.length,
              itemBuilder: (ctx, i) => _buildEntryRow(
                entries[i],
                isDark,
                parentCats,
                subCatsMap,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildStatsBar(ImportState state, bool isDark) {
    final total = state.previewEntries.length;
    final duplicates =
        state.previewEntries.where((e) => e.isDuplicate).length;
    final selected = _selectedIndices.length;
    final refundCount = _refundPairs.length ~/ 2;
    final categorized = _categoryAssignments.length;
    final willImport = state.previewEntries
        .where((e) =>
            !e.isDuplicate &&
            _selectedIndices.contains(e.index) &&
            _categoryAssignments.containsKey(e.index) &&
            !_refundPairs.containsKey(e.index))
        .length;

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
          _statItem('总计', '$total条', AppColors.primary),
          _statItem('将导入', '$willImport条', const Color(0xFF52C41A)),
          _statItem('已选', '$selected条', const Color(0xFF1890FF)),
          _statItem('已分类', '$categorized条', AppColors.textSecondary),
          if (refundCount > 0)
            _statItem('抵消', '$refundCount对', const Color(0xFFFAAD14)),
          if (duplicates > 0)
            _statItem('重复', '$duplicates条', const Color(0xFFFAAD14)),
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

  Widget _buildEntryRow(
    ImportPreviewEntry entry,
    bool isDark,
    List<CategoryModel> parentCats,
    Map<int, List<CategoryModel>> subCatsMap,
  ) {
    final hasCategory = _categoryAssignments.containsKey(entry.index);
    final catId = _categoryAssignments[entry.index];
    final isSelected = _selectedIndices.contains(entry.index);
    final isRefundPaired = _refundPairs.containsKey(entry.index);

    // 查找分类名称
    String? catName;
    if (hasCategory && catId != null) {
      for (final subs in subCatsMap.values) {
        for (final s in subs) {
          if (s.id == catId) {
            catName = s.name;
            break;
          }
        }
        if (catName != null) break;
      }
      catName ??= '已选';
    }

    return Opacity(
      opacity: isRefundPaired ? 0.35 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isRefundPaired
              ? (isDark
                    ? Colors.green.withOpacity(0.06)
                    : Colors.green.withOpacity(0.03))
              : entry.isDuplicate
                  ? (isDark
                        ? Colors.red.withOpacity(0.08)
                        : Colors.red.withOpacity(0.04))
                  : isSelected
                      ? (isDark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFE8F0FE))
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: isRefundPaired
              ? Border.all(color: Colors.green.withOpacity(0.3))
              : entry.isDuplicate
                  ? Border.all(color: Colors.red.withOpacity(0.2))
                  : Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE8E8ED),
                    ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: (entry.isDuplicate || isRefundPaired)
                  ? null
                  : () {
                      setState(() {
                        if (_selectedIndices.contains(entry.index)) {
                          _selectedIndices.remove(entry.index);
                        } else {
                          _selectedIndices.add(entry.index);
                        }
                      });
                    },
              child: Icon(
                isRefundPaired
                    ? Icons.swap_horiz_rounded
                    : entry.isDuplicate
                        ? Icons.block
                        : isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: isRefundPaired
                    ? Colors.green.withOpacity(0.5)
                    : entry.isDuplicate
                        ? Colors.red.withOpacity(0.3)
                        : isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: entry.type == 'income'
                    ? AppColors.incomeLight
                    : AppColors.expenseLight,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                entry.type == 'income'
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 14,
                color: entry.type == 'income'
                    ? AppColors.income
                    : AppColors.danger,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.counterparty.isNotEmpty
                        ? entry.counterparty
                        : entry.description.isNotEmpty
                            ? entry.description
                            : '无描述',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLightest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            entry.paymentMethod,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.primary),
                          ),
                        ),
                      ],
                      if (isRefundPaired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '退款抵消',
                            style: TextStyle(fontSize: 10, color: Colors.green),
                          ),
                        ),
                      ],
                      if (entry.isDuplicate) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
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
            GestureDetector(
              onTap: (entry.isDuplicate || isRefundPaired || !isSelected)
                  ? null
                  : () => _showCategoryPicker(entry, parentCats, subCatsMap),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
      ),
    );
  }

  void _showCategoryPicker(
    ImportPreviewEntry entry,
    List<CategoryModel> parentCats,
    Map<int, List<CategoryModel>> subCatsMap,
  ) {
    final type = entry.type;
    // 使用更全面的关键词集合来判断是否为收入类分类
    bool isIncomeCategoryName(String name) {
      const incomeKeys = [
        '收入', '工资', '奖金', '投资', '理财',
        '退款', '兼职', '红包', '补贴', '报销',
        '利息', '分红',
      ];
      return incomeKeys.any((k) => name.contains(k));
    }

    final filteredParents = parentCats.where((c) {
      final isIncomeCat = isIncomeCategoryName(c.name);
      if (type == 'income') {
        return isIncomeCat;
      } else {
        return !isIncomeCat;
      }
    }).toList();

    // 如果过滤后为空，回退到全部大类（避免"暂无分类数据"）
    final displayParents = filteredParents.isNotEmpty ? filteredParents : parentCats;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (displayParents.isEmpty) {
          return Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Text(
                '暂无分类数据，请先在设置中配置分类',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(16),
          height: 420,
          child: Column(
            children: [
              const Text(
                '选择分类',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: displayParents.length,
                  itemBuilder: (_, i) {
                    final parent = displayParents[i];
                    final subs = subCatsMap[parent.id] ?? [];
                    return ExpansionTile(
                      leading: Text(
                        parent.icon ?? '📌',
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(parent.name),
                      children: subs
                          .map(
                            (sub) => ListTile(
                              leading: Text(
                                sub.icon ?? '📌',
                                style: const TextStyle(fontSize: 18),
                              ),
                              title: Text(sub.name),
                              trailing:
                                  _categoryAssignments[entry.index] == sub.id
                                      ? const Icon(Icons.check_circle,
                                          color: AppColors.primary, size: 20)
                                      : null,
                              onTap: () {
                                setState(() => _categoryAssignments[entry
                                    .index] = sub.id);
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

  Future<void> _autoCategorize() async {
    final allCats = ref.read(allSubCategoriesProvider).valueOrNull ?? [];
    if (allCats.isEmpty) return;

    final state = ref.read(importProvider);

    final rules = <String, List<String>>{
      '餐饮': [
        '饭', '餐', '外卖', '奶茶', '咖啡', '面', '米粉', '小吃',
        '烧烤', '火锅', '面包', '蛋糕', '水果', '食堂', '饿了么', '美团外卖',
        '肯德基', '麦当劳', '必胜客', '瑞幸', '星巴克', '喜茶', '蜜雪冰城',
      ],
      '交通': [
        '打车', '滴滴', '地铁', '公交', '加油', '停车', '高速', 'ETC',
        '骑行', '共享', '高德', '花小猪', '12306', '机票', '火车票',
      ],
      '购物': [
        '超市', '便利店', '淘宝', '京东', '拼多多', '天猫', '商场', '百货',
        '屈臣氏', '衣服', '鞋', '包', '美妆', '护肤', '饰品', '数码', '配件',
        '名创优品', '无印良品', '山姆', 'Costco', '盒马',
      ],
      '居家': [
        '房租', '物业', '水电', '燃气', '宽带', '暖气', '维修',
        '话费', '流量', '充值', '移动', '联通', '电信',
      ],
      '娱乐': [
        '电影', '游戏', 'KTV', '演出', '会员', '视频', '音乐',
        '健身房', '游泳', '瑜伽', '旅行', '酒店', '景点',
        'Steam', '爱奇艺', '腾讯视频', 'B站', 'QQ音乐', '网易云',
      ],
      '医疗': [
        '医院', '药', '挂号', '门诊', '体检', '牙科', '洗牙', '诊所',
      ],
      '教育': [
        '课程', '培训', '考试', '学费', '知识付费', '得到', '教材', '文具',
      ],
      '人情': [
        '红包', '份子', '送礼', '孝敬', '结婚', '压岁', '请客',
      ],
      '金融': [
        '保险', '手续费', '利息', '税费', '贷款', '转账费',
      ],
      '其他': [
        '快递', '邮寄', '宠物', '猫粮', '狗粮', '捐赠', '公益',
      ],
    };

    int autoAssigned = 0;

    for (final entry in state.previewEntries) {
      if (entry.isDuplicate || _categoryAssignments.containsKey(entry.index)) {
        continue;
      }

      final text = '${entry.description} ${entry.counterparty}';
      int? bestCatId;

      for (final rule in rules.entries) {
        for (final kw in rule.value) {
          if (text.contains(kw)) {
            for (final cat in allCats) {
              final parentName = cat.parent?.name ?? '';
              if (parentName.contains(rule.key)) {
                bestCatId = cat.category.id;
                break;
              }
            }
            if (bestCatId != null) break;
          }
        }
        if (bestCatId != null) break;
      }

      if (bestCatId == null) {
        final txDao = ref.read(transactionDaoProvider);
        final matcher = CategoryMatcher(txDao);
        final result = await matcher.match(
          entry.counterparty,
          entry.description,
        );
        if (result != null &&
            result.categoryId != null &&
            result.confidence >= 60) {
          bestCatId = result.categoryId;
        }
      }

      if (bestCatId != null) {
        _categoryAssignments[entry.index] = bestCatId;
        autoAssigned++;
      }
    }

    setState(() {});

    if (mounted) {
      final remaining = state.previewEntries
          .where((e) =>
              !e.isDuplicate &&
              !_categoryAssignments.containsKey(e.index))
          .length;
      final msg = remaining > 0
          ? '已自动匹配 $autoAssigned 条，还剩 $remaining 条需手动选择分类'
          : '已自动为 $autoAssigned 条记录匹配分类 ✓';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    }
  }

  void _confirmWithWarning(ImportState state) {
    final willImport = state.previewEntries
        .where((e) =>
            !e.isDuplicate &&
            _selectedIndices.contains(e.index) &&
            _categoryAssignments.containsKey(e.index) &&
            !_refundPairs.containsKey(e.index))
        .toList();
    final unassigned = state.previewEntries
        .where((e) =>
            !e.isDuplicate &&
            _selectedIndices.contains(e.index) &&
            !_categoryAssignments.containsKey(e.index) &&
            !_refundPairs.containsKey(e.index))
        .length;
    final notSelected = state.previewEntries
        .where((e) =>
            !e.isDuplicate &&
            !_selectedIndices.contains(e.index) &&
            !_refundPairs.containsKey(e.index))
        .length;

    void doConfirm() => ref
        .read(importProvider.notifier)
        .confirmImport(
          categoryAssignments: _categoryAssignments,
          excludedIndices: [
            // 排除未选中和退款配对的条目
            for (final e in state.previewEntries)
              if (!_selectedIndices.contains(e.index) ||
                  _refundPairs.containsKey(e.index))
                e.index,
          ],
        );

    if (willImport.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('没有可导入的记录'),
          content: Text(
            notSelected > 0
                ? '已选 $_selectedIndices.length 条，但未分配分类。\n请为选中的记录分配分类后再导入。'
                : '请先勾选要导入的记录，并为其分配分类。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('返回'),
            ),
          ],
        ),
      );
      return;
    }

    if (unassigned == 0) {
      doConfirm();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入确认'),
        content: Text(
          '$unassigned 条已选中但未分配分类，它们将不会被导入。\n'
          '确认导入 ${willImport.length} 条记录？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              doConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ImportState state) {
    final unassigned = state.previewEntries
        .where((e) =>
            !e.isDuplicate &&
            _selectedIndices.contains(e.index) &&
            !_categoryAssignments.containsKey(e.index) &&
            !_refundPairs.containsKey(e.index))
        .length;
    final selected = _selectedIndices.length;

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
            Text(
              '已选 $selected 条',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (unassigned > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$unassigned 条未分类',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(importProvider.notifier).reset(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: state.isImporting
                  ? null
                  : () => _confirmWithWarning(state),
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('确认导入'),
            ),
          ],
        ),
      ),
    );
  }
}
