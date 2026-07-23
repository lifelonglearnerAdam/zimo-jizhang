// 数据模型 — 纯 Dart 类（无需代码生成）

class CategoryModel {
  final int id;
  final String name;
  final int? parentId;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'parent_id': parentId,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    int? parentId,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isDefault,
    bool? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class TransactionModel {
  static const _unchanged = Object();

  final String id;
  final int amountFen;
  final String type; // 'expense' | 'income'
  final int? categoryId;
  final String transactionDate;
  final String? description;
  final String? counterparty;
  final String? paymentMethod;
  final String source; // 'manual' | 'import'
  final String? importBatchId;
  final String? externalId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.amountFen,
    this.type = 'expense',
    this.categoryId,
    required this.transactionDate,
    this.description,
    this.counterparty,
    this.paymentMethod,
    this.source = 'manual',
    this.importBatchId,
    this.externalId,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      amountFen: map['amount_fen'] as int,
      type: map['type'] as String? ?? 'expense',
      categoryId: map['category_id'] as int?,
      transactionDate: map['transaction_date'] as String,
      description: map['description'] as String?,
      counterparty: map['counterparty'] as String?,
      paymentMethod: map['payment_method'] as String?,
      source: map['source'] as String? ?? 'manual',
      importBatchId: map['import_batch_id'] as String?,
      externalId: map['external_id'] as String?,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount_fen': amountFen,
      'type': type,
      'category_id': categoryId,
      'transaction_date': transactionDate,
      'description': description,
      'counterparty': counterparty,
      'payment_method': paymentMethod,
      'source': source,
      'import_batch_id': importBatchId,
      'external_id': externalId,
      'is_deleted': isDeleted ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  TransactionModel copyWith({
    String? id,
    int? amountFen,
    String? type,
    int? categoryId,
    String? transactionDate,
    Object? description = _unchanged,
    String? counterparty,
    String? paymentMethod,
    String? source,
    String? importBatchId,
    String? externalId,
    bool? isDeleted,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amountFen: amountFen ?? this.amountFen,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      transactionDate: transactionDate ?? this.transactionDate,
      description: identical(description, _unchanged)
          ? this.description
          : description as String?,
      counterparty: counterparty ?? this.counterparty,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      source: source ?? this.source,
      importBatchId: importBatchId ?? this.importBatchId,
      externalId: externalId ?? this.externalId,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// 组合数据类
class CategoryWithParent {
  final CategoryModel category;
  final CategoryModel? parent;

  const CategoryWithParent({required this.category, this.parent});

  String get displayName =>
      parent != null ? '${parent!.name} › ${category.name}' : category.name;

  int get parentId => parent?.id ?? category.parentId ?? category.id;
}

class DailyExpense {
  final String date;
  final int amountFen;

  const DailyExpense({required this.date, required this.amountFen});
}

class CategoryExpense {
  final int categoryId;
  final String categoryName;
  final String icon;
  final String color;
  final int totalFen;

  const CategoryExpense({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.totalFen,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// v3 新增模型
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 导入批次
class ImportBatch {
  final String id;
  final String source; // 'wechat' | 'alipay' | 'bank_csv'
  final String fileName;
  final int totalCount;
  final int importedCount;
  final int skippedCount;
  final String status; // 'processing' | 'completed' | 'failed'
  final DateTime createdAt;

  const ImportBatch({
    required this.id,
    required this.source,
    required this.fileName,
    this.totalCount = 0,
    this.importedCount = 0,
    this.skippedCount = 0,
    this.status = 'processing',
    required this.createdAt,
  });

  factory ImportBatch.fromMap(Map<String, dynamic> map) {
    return ImportBatch(
      id: map['id'] as String,
      source: map['source'] as String,
      fileName: map['file_name'] as String,
      totalCount: map['total_count'] as int? ?? 0,
      importedCount: map['imported_count'] as int? ?? 0,
      skippedCount: map['skipped_count'] as int? ?? 0,
      status: map['status'] as String? ?? 'processing',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'source': source,
    'file_name': fileName,
    'total_count': totalCount,
    'imported_count': importedCount,
    'skipped_count': skippedCount,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}

/// 导入规则（用户自定义字段映射）
class ImportRule {
  final int? id;
  final String source;
  final String name;
  final Map<String, String>
  fieldMapping; // {"date":"交易时间","amount":"金额(元)",...}
  final String? dateFormat;
  final String amountSignConvention; // '支出为正' | '收入为正'
  final List<String>? skipKeywords;
  final bool isDefault;

  const ImportRule({
    this.id,
    required this.source,
    required this.name,
    required this.fieldMapping,
    this.dateFormat,
    this.amountSignConvention = '支出为正',
    this.skipKeywords,
    this.isDefault = false,
  });

  factory ImportRule.fromMap(Map<String, dynamic> map) {
    return ImportRule(
      id: map['id'] as int?,
      source: map['source'] as String,
      name: map['name'] as String,
      fieldMapping: _parseJsonMap(map['field_mapping'] as String),
      dateFormat: map['date_format'] as String?,
      amountSignConvention: map['amount_sign_convention'] as String? ?? '支出为正',
      skipKeywords: map['skip_keywords'] != null
          ? (map['skip_keywords'] as String)
                .split(',')
                .map((s) => s.trim())
                .toList()
          : null,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'source': source,
    'name': name,
    'field_mapping': _encodeJsonMap(fieldMapping),
    'date_format': dateFormat,
    'amount_sign_convention': amountSignConvention,
    'skip_keywords': skipKeywords?.join(','),
    'is_default': isDefault ? 1 : 0,
  };

  static Map<String, String> _parseJsonMap(String json) {
    // 简单 JSON map 解析，避免引入 dart:convert 依赖
    final map = <String, String>{};
    final trimmed = json.replaceAll(RegExp(r'[{}"]'), '');
    for (final pair in trimmed.split(',')) {
      final kv = pair.split(':');
      if (kv.length == 2) {
        map[kv[0].trim()] = kv[1].trim();
      }
    }
    return map;
  }

  static String _encodeJsonMap(Map<String, String> map) {
    final entries = map.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
    return '{$entries}';
  }
}

/// 导入预览条目
class ImportPreviewEntry {
  final int index;
  final String date;
  final String type; // 'expense' | 'income'
  final int amountFen;
  final String description;
  final String counterparty;
  final String paymentMethod;
  final int? matchedCategoryId;
  final String? matchedCategoryName;
  final int confidence; // 0-100 分类匹配置信度
  final bool isDuplicate;
  final String? externalId;

  const ImportPreviewEntry({
    required this.index,
    required this.date,
    this.type = 'expense',
    required this.amountFen,
    this.description = '',
    this.counterparty = '',
    this.paymentMethod = '',
    this.matchedCategoryId,
    this.matchedCategoryName,
    this.confidence = 0,
    this.isDuplicate = false,
    this.externalId,
  });
}

/// 定期交易
class RecurringTransaction {
  final int? id;
  final int amountFen;
  final String type;
  final int? categoryId;
  final String frequency; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  final int intervalDay;
  final String nextDueDate;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const RecurringTransaction({
    this.id,
    required this.amountFen,
    this.type = 'expense',
    this.categoryId,
    required this.frequency,
    this.intervalDay = 1,
    required this.nextDueDate,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      amountFen: map['amount_fen'] as int,
      type: map['type'] as String? ?? 'expense',
      categoryId: map['category_id'] as int?,
      frequency: map['frequency'] as String,
      intervalDay: map['interval_day'] as int? ?? 1,
      nextDueDate: map['next_due_date'] as String,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'amount_fen': amountFen,
    'type': type,
    'category_id': categoryId,
    'frequency': frequency,
    'interval_day': intervalDay,
    'next_due_date': nextDueDate,
    'description': description,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };
}

/// 储蓄目标。金额统一使用分，和交易记录保持一致。
class FinancialGoal {
  final int? id;
  final String name;
  final int targetFen;
  final int currentFen;
  final String? targetDate;
  final String icon;
  final String color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialGoal({
    this.id,
    required this.name,
    required this.targetFen,
    this.currentFen = 0,
    this.targetDate,
    this.icon = '🎯',
    this.color = '#2D6A4F',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progress =>
      targetFen <= 0 ? 0 : (currentFen / targetFen).clamp(0.0, 1.0);

  int get remainingFen => (targetFen - currentFen).clamp(0, targetFen);

  factory FinancialGoal.fromMap(Map<String, dynamic> map) {
    return FinancialGoal(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetFen: (map['target_fen'] as num).toInt(),
      currentFen: (map['current_fen'] as num? ?? 0).toInt(),
      targetDate: map['target_date'] as String?,
      icon: map['icon'] as String? ?? '🎯',
      color: map['color'] as String? ?? '#2D6A4F',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'target_fen': targetFen,
    'current_fen': currentFen,
    'target_date': targetDate,
    'icon': icon,
    'color': color,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class LearningProgress {
  final String articleId;
  final bool completed;
  final bool bookmarked;
  final DateTime? lastOpenedAt;
  final DateTime? completedAt;

  const LearningProgress({
    required this.articleId,
    this.completed = false,
    this.bookmarked = false,
    this.lastOpenedAt,
    this.completedAt,
  });

  factory LearningProgress.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(Object? value) =>
        value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

    return LearningProgress(
      articleId: map['article_id'] as String,
      completed: (map['completed'] as int? ?? 0) == 1,
      bookmarked: (map['bookmarked'] as int? ?? 0) == 1,
      lastOpenedAt: parseDate(map['last_opened_at']),
      completedAt: parseDate(map['completed_at']),
    );
  }
}
