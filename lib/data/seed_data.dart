/// 默认分类种子数据
///
/// 10 个大类，52 个小类，覆盖中国个人日常消费场景
class SeedData {
  SeedData._();

  /// 收入分类
  static List<CategorySeed> get incomeCategories => [
        CategorySeed(
          name: '收入',
          icon: '💰',
          color: '#2D6A4F',
          children: [
            SubCategorySeed('工资薪水', '💼'),
            SubCategorySeed('奖金绩效', '🏆'),
            SubCategorySeed('投资收益', '📈'),
            SubCategorySeed('兼职外快', '💻'),
            SubCategorySeed('退款', '↩️'),
            SubCategorySeed('红包收入', '🧧'),
            SubCategorySeed('其他收入', '💵'),
          ],
        ),
      ];

  /// 获取所有默认支出分类
  static List<CategorySeed> get categories => [
        CategorySeed(
          name: '餐饮美食',
          icon: '🍽️',
          color: '#E76F51',
          children: [
            SubCategorySeed('一日三餐', '🍚'),
            SubCategorySeed('外卖外送', '🛵'),
            SubCategorySeed('零食饮料', '🥤'),
            SubCategorySeed('水果生鲜', '🍎'),
            SubCategorySeed('咖啡奶茶', '☕'),
            SubCategorySeed('聚餐聚会', '🥂'),
          ],
        ),
        CategorySeed(
          name: '交通出行',
          icon: '🚗',
          color: '#2D6A4F',
          children: [
            SubCategorySeed('公交地铁', '🚇'),
            SubCategorySeed('打车网约', '🚕'),
            SubCategorySeed('加油充电', '⛽'),
            SubCategorySeed('停车费', '🅿️'),
            SubCategorySeed('火车高铁', '🚄'),
            SubCategorySeed('飞机出行', '✈️'),
            SubCategorySeed('汽车养护', '🔧'),
          ],
        ),
        CategorySeed(
          name: '购物消费',
          icon: '🛒',
          color: '#457B9D',
          children: [
            SubCategorySeed('服饰鞋包', '👗'),
            SubCategorySeed('数码产品', '📱'),
            SubCategorySeed('个护美妆', '💄'),
            SubCategorySeed('日用百货', '🧻'),
            SubCategorySeed('家居好物', '🏡'),
            SubCategorySeed('运动户外', '⚽'),
          ],
        ),
        CategorySeed(
          name: '居家生活',
          icon: '🏠',
          color: '#6D597A',
          children: [
            SubCategorySeed('房租', '🏢'),
            SubCategorySeed('房贷', '🏦'),
            SubCategorySeed('水费', '💧'),
            SubCategorySeed('电费', '⚡'),
            SubCategorySeed('燃气费', '🔥'),
            SubCategorySeed('网费话费', '📶'),
            SubCategorySeed('物业费', '🏘️'),
            SubCategorySeed('维修修缮', '🛠️'),
          ],
        ),
        CategorySeed(
          name: '休闲娱乐',
          icon: '🎮',
          color: '#B5838D',
          children: [
            SubCategorySeed('游戏充值', '🎮'),
            SubCategorySeed('视频会员', '📺'),
            SubCategorySeed('音乐会员', '🎵'),
            SubCategorySeed('电影演出', '🎬'),
            SubCategorySeed('运动健身', '🏋️'),
            SubCategorySeed('旅行度假', '✈️'),
            SubCategorySeed('书籍阅读', '📖'),
          ],
        ),
        CategorySeed(
          name: '医疗健康',
          icon: '🏥',
          color: '#52796F',
          children: [
            SubCategorySeed('门诊看病', '🩺'),
            SubCategorySeed('药品购买', '💊'),
            SubCategorySeed('牙科口腔', '🦷'),
            SubCategorySeed('体检检查', '🩻'),
            SubCategorySeed('保健品', '💪'),
          ],
        ),
        CategorySeed(
          name: '教育学习',
          icon: '📚',
          color: '#84A98C',
          children: [
            SubCategorySeed('课程培训', '🎓'),
            SubCategorySeed('考试报名', '📝'),
            SubCategorySeed('书本教材', '📕'),
            SubCategorySeed('知识付费', '💡'),
          ],
        ),
        CategorySeed(
          name: '人情往来',
          icon: '🧧',
          color: '#E9C46A',
          children: [
            SubCategorySeed('红包礼金', '🧧'),
            SubCategorySeed('孝敬长辈', '👴'),
            SubCategorySeed('请客送礼', '🎁'),
            SubCategorySeed('小孩相关', '👶'),
          ],
        ),
        CategorySeed(
          name: '金融保险',
          icon: '🛡️',
          color: '#A8DADC',
          children: [
            SubCategorySeed('保险保费', '🔒'),
            SubCategorySeed('手续费', '💳'),
            SubCategorySeed('贷款利息', '📊'),
            SubCategorySeed('税费', '🧾'),
          ],
        ),
        CategorySeed(
          name: '其他支出',
          icon: '📦',
          color: '#B7B7A4',
          children: [
            SubCategorySeed('快递邮政', '📦'),
            SubCategorySeed('宠物花销', '🐾'),
            SubCategorySeed('捐赠公益', '💝'),
            SubCategorySeed('杂项', '📌'),
          ],
        ),
      ];
}

class CategorySeed {
  final String name;
  final String icon;
  final String color;
  final List<SubCategorySeed> children;

  const CategorySeed({
    required this.name,
    required this.icon,
    required this.color,
    required this.children,
  });
}

class SubCategorySeed {
  final String name;
  final String icon;

  const SubCategorySeed(this.name, this.icon);
}
