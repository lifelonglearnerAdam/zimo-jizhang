import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'seed_data.dart';
import 'database_config_native.dart'
    if (dart.library.html) 'database_config_web.dart';

/// 数据库服务 — 单例模式
class DatabaseService {
  static DatabaseService? _instance;
  Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // 调用平台特定的数据库工厂配置
    // - 桌面端：初始化 FFI
    // - Web 端：初始化 IndexedDB
    // - 移动端：无操作（使用原生 sqflite 平台通道）
    configureDatabaseFactory();

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'zimo_jizhang.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建分类表
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        parent_id INTEGER REFERENCES categories(id),
        icon TEXT,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        is_default INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    // 创建交易记录表
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount_fen INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense' CHECK(type IN ('expense','income')),
        category_id INTEGER REFERENCES categories(id),
        transaction_date TEXT NOT NULL,
        description TEXT,
        counterparty TEXT,
        payment_method TEXT,
        source TEXT DEFAULT 'manual' CHECK(source IN ('manual','import')),
        import_batch_id TEXT,
        external_id TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    // 创建预算表
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER REFERENCES categories(id),
        type TEXT NOT NULL DEFAULT 'monthly' CHECK(type IN ('monthly','category')),
        amount_fen INTEGER NOT NULL,
        year_month TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    // 创建账户表
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('cash','wechat','alipay','bank_card','credit_card','other')),
        initial_balance_fen INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_tx_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_tx_category ON transactions(category_id)');
    await db.execute('CREATE INDEX idx_tx_type ON transactions(type)');

    // 插入默认分类
    await _seedCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER REFERENCES categories(id),
          type TEXT NOT NULL DEFAULT 'monthly' CHECK(type IN ('monthly','category')),
          amount_fen INTEGER NOT NULL,
          year_month TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT (datetime('now', 'localtime')),
          updated_at TEXT DEFAULT (datetime('now', 'localtime'))
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('cash','wechat','alipay','bank_card','credit_card','other')),
          initial_balance_fen INTEGER DEFAULT 0,
          sort_order INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT (datetime('now', 'localtime')),
          updated_at TEXT DEFAULT (datetime('now', 'localtime'))
        )
      ''');
    }
    if (oldVersion < 3) {
      // 导入批次表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS import_batches (
          id TEXT PRIMARY KEY,
          source TEXT NOT NULL,
          file_name TEXT NOT NULL,
          total_count INTEGER DEFAULT 0,
          imported_count INTEGER DEFAULT 0,
          skipped_count INTEGER DEFAULT 0,
          status TEXT DEFAULT 'processing',
          created_at TEXT DEFAULT (datetime('now', 'localtime'))
        )
      ''');
      // 导入规则表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS import_rules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source TEXT NOT NULL,
          name TEXT NOT NULL,
          field_mapping TEXT NOT NULL,
          date_format TEXT,
          amount_sign_convention TEXT DEFAULT '支出为正',
          skip_keywords TEXT,
          is_default INTEGER DEFAULT 0
        )
      ''');
      // 定期交易表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount_fen INTEGER NOT NULL,
          type TEXT NOT NULL DEFAULT 'expense' CHECK(type IN ('expense','income')),
          category_id INTEGER REFERENCES categories(id),
          frequency TEXT NOT NULL CHECK(frequency IN ('daily','weekly','monthly','yearly')),
          interval_day INTEGER DEFAULT 1,
          next_due_date TEXT NOT NULL,
          description TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT (datetime('now', 'localtime'))
        )
      ''');
      // 插入默认导入规则
      await _seedImportRules(db);
    }
  }

  Future<void> _seedCategories(Database db) async {
    // 先插入支出分类
    final expenseSeeds = SeedData.categories;
    for (var i = 0; i < expenseSeeds.length; i++) {
      await _insertCategorySeed(db, expenseSeeds[i], i);
    }
    // 再插入收入分类
    final incomeSeeds = SeedData.incomeCategories;
    for (var i = 0; i < incomeSeeds.length; i++) {
      await _insertCategorySeed(db, incomeSeeds[i], expenseSeeds.length + i);
    }
  }

  Future<void> _insertCategorySeed(Database db, CategorySeed seed, int sortOrder) async {
    final parentId = await db.insert('categories', {
      'name': seed.name,
      'icon': seed.icon,
      'color': seed.color,
      'sort_order': sortOrder,
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    for (var j = 0; j < seed.children.length; j++) {
      final child = seed.children[j];
      await db.insert('categories', {
        'name': child.name,
        'icon': child.icon,
        'parent_id': parentId,
        'sort_order': j,
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// 确保数据库已初始化
  Future<void> ensureInitialized() async {
    await database;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAO — 分类
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class CategoryDao {
  final DatabaseService _db = DatabaseService.instance;

  Future<List<CategoryModel>> getParentCategories() async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'parent_id IS NULL AND is_active = 1',
      orderBy: 'sort_order',
    );
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<List<CategoryModel>> getSubCategories(int parentId) async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'parent_id = ? AND is_active = 1',
      whereArgs: [parentId],
      orderBy: 'sort_order',
    );
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<List<CategoryWithParent>> getAllSubCategoriesWithParent() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT c.*, p.name as parent_name, p.icon as parent_icon
      FROM categories c
      LEFT JOIN categories p ON c.parent_id = p.id
      WHERE c.parent_id IS NOT NULL AND c.is_active = 1
      ORDER BY c.sort_order
    ''');
    return maps.map((m) {
      final cat = CategoryModel.fromMap(m);
      final parent = m['parent_name'] != null
          ? CategoryModel(
              id: cat.parentId!,
              name: m['parent_name'] as String,
              icon: m['parent_icon'] as String?,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : null;
      return CategoryWithParent(category: cat, parent: parent);
    }).toList();
  }

  Future<List<CategoryModel>> getAllActive() async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'is_active = 1',
      orderBy: 'sort_order',
    );
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<CategoryModel?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return CategoryModel.fromMap(maps.first);
  }

  Future<int> insert(CategoryModel category) async {
    final db = await _db.database;
    return db.insert('categories', category.toMap());
  }

  Future<int> insertWithData({
    required String name,
    required String icon,
    int? parentId,
    String? color,
    int sortOrder = 0,
    bool isDefault = false,
  }) async {
    final db = await _db.database;
    return db.insert('categories', {
      'name': name,
      'icon': icon,
      'parent_id': parentId,
      'color': color,
      'sort_order': sortOrder,
      'is_default': isDefault ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> update(CategoryModel category) async {
    final db = await _db.database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> softDelete(int id) async {
    final db = await _db.database;
    return db.update(
      'categories',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> seedDefaults() async {
    // seedDefaults is called during database creation via _seedCategories
    // This method is kept for compatibility but is a no-op for sqflite
    final existing = await getAllActive();
    if (existing.isNotEmpty) return;
    // If database exists but has no categories (edge case), trigger re-seed
    final db = await _db.database;
    await DatabaseService.instance._seedCategories(db);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAO — 交易记录
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class TransactionDao {
  final DatabaseService _db = DatabaseService.instance;

  Future<void> insertTransaction(TransactionModel tx) async {
    final db = await _db.database;
    await db.insert('transactions', tx.toMap());
  }

  Future<void> insertWithData({
    required String id,
    required int amountFen,
    required int categoryId,
    required String date,
    String? description,
    String? paymentMethod,
    String type = 'expense',
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('transactions', {
      'id': id,
      'amount_fen': amountFen,
      'type': type,
      'category_id': categoryId,
      'transaction_date': date,
      'description': description,
      'payment_method': paymentMethod,
      'source': 'manual',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> update(TransactionModel tx) async {
    final db = await _db.database;
    return db.update('transactions', tx.toMap(), where: 'id = ?', whereArgs: [tx.id]);
  }

  Future<int> softDelete(String id) async {
    final db = await _db.database;
    return db.update(
      'transactions',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionModel>> getAll({int? limit, int? offset}) async {
    final db = await _db.database;
    final maps = await db.query(
      'transactions',
      where: 'is_deleted = 0',
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getByMonth(String yearMonth, {int? categoryId}) async {
    final db = await _db.database;
    final startDate = '$yearMonth-01';
    final endDate = _getEndDate(yearMonth);

    String where = 'is_deleted = 0 AND transaction_date >= ? AND transaction_date <= ? AND type = ?';
    List<dynamic> args = [startDate, endDate, 'expense'];

    if (categoryId != null) {
      where += ' AND category_id = ?';
      args.add(categoryId);
    }

    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: args,
      orderBy: 'transaction_date DESC, created_at DESC',
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getToday() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final db = await _db.database;
    final maps = await db.query(
      'transactions',
      where: 'is_deleted = 0 AND transaction_date = ? AND type = ?',
      whereArgs: [dateStr, 'expense'],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<int> getTodayTotalExpense() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_fen), 0) as total FROM transactions WHERE is_deleted = 0 AND transaction_date = ? AND type = ?',
      [dateStr, 'expense'],
    );
    return _toInt(result.first['total']);
  }

  Future<int> getMonthTotalExpense() async {
    final now = DateTime.now();
    final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final endDate = _getEndDate('${now.year}-${now.month.toString().padLeft(2, '0')}');

    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_fen), 0) as total FROM transactions WHERE is_deleted = 0 AND transaction_date >= ? AND transaction_date <= ? AND type = ?',
      [startDate, endDate, 'expense'],
    );
    return _toInt(result.first['total']);
  }

  Future<int> getLastMonthTotalExpense() async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final startDate =
        '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-01';
    final endDate =
        _getEndDate('${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}');

    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_fen), 0) as total FROM transactions WHERE is_deleted = 0 AND transaction_date >= ? AND transaction_date <= ? AND type = ?',
      [startDate, endDate, 'expense'],
    );
    return _toInt(result.first['total']);
  }

  Future<List<DailyExpense>> getDailyExpensesByMonth(String yearMonth) async {
    final startDate = '$yearMonth-01';
    final endDate = _getEndDate(yearMonth);

    final db = await _db.database;
    final results = await db.rawQuery(
      'SELECT transaction_date, SUM(amount_fen) as total FROM transactions WHERE is_deleted = 0 AND transaction_date >= ? AND transaction_date <= ? AND type = ? GROUP BY transaction_date ORDER BY transaction_date',
      [startDate, endDate, 'expense'],
    );
    return results.map((r) => DailyExpense(
          date: r['transaction_date'] as String,
          amountFen: _toInt(r['total']),
        )).toList();
  }

  Future<List<CategoryExpense>> getCategoryExpensesByMonth(String yearMonth) async {
    final startDate = '$yearMonth-01';
    final endDate = _getEndDate(yearMonth);

    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT
        COALESCE(p.id, c.id) as category_id,
        COALESCE(p.name, c.name) as category_name,
        COALESCE(p.icon, c.icon) as category_icon,
        COALESCE(p.color, c.color) as category_color,
        SUM(t.amount_fen) as total_fen
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN categories p ON c.parent_id = p.id
      WHERE t.is_deleted = 0
        AND t.type = 'expense'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
      GROUP BY COALESCE(p.id, c.id)
      ORDER BY total_fen DESC
    ''', [startDate, endDate]);

    return results.map((r) => CategoryExpense(
          categoryId: r['category_id'] as int,
          categoryName: r['category_name'] as String,
          icon: (r['category_icon'] as String?) ?? '📌',
          color: (r['category_color'] as String?) ?? '#B7B7A4',
          totalFen: _toInt(r['total_fen'] ?? 0),
        )).toList();
  }

  Future<List<TransactionModel>> search(String keyword) async {
    final db = await _db.database;
    final maps = await db.query(
      'transactions',
      where: 'is_deleted = 0 AND (description LIKE ? OR counterparty LIKE ?)',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'transaction_date DESC',
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<int> getMonthTotalIncome() async {
    final now = DateTime.now();
    final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final endDate = _getEndDate('${now.year}-${now.month.toString().padLeft(2, '0')}');

    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_fen), 0) as total FROM transactions WHERE is_deleted = 0 AND transaction_date >= ? AND transaction_date <= ? AND type = ?',
      [startDate, endDate, 'income'],
    );
    return _toInt(result.first['total']);
  }

  Future<int> getMonthTransactionCount() async {
    final now = DateTime.now();
    final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final endDate = _getEndDate('${now.year}-${now.month.toString().padLeft(2, '0')}');

    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM transactions WHERE is_deleted = 0 AND transaction_date >= ? AND transaction_date <= ? AND type = ?',
      [startDate, endDate, 'expense'],
    );
    return _toInt(result.first['cnt']);
  }

  /// 获取某年各月支出汇总
  Future<List<MonthlyTotal>> getYearMonthlyExpenses(int year) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT SUBSTR(transaction_date, 6, 2) as month, SUM(amount_fen) as total
      FROM transactions
      WHERE is_deleted = 0 AND type = 'expense' AND transaction_date >= ? AND transaction_date <= ?
      GROUP BY month ORDER BY month
    ''', ['$year-01-01', '$year-12-31']);
    return results.map((r) => MonthlyTotal(month: int.parse(r['month'] as String), totalFen: _toInt(r['total']))).toList();
  }

  Future<List<MonthlyTotal>> getYearMonthlyIncome(int year) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT SUBSTR(transaction_date, 6, 2) as month, SUM(amount_fen) as total
      FROM transactions
      WHERE is_deleted = 0 AND type = 'income' AND transaction_date >= ? AND transaction_date <= ?
      GROUP BY month ORDER BY month
    ''', ['$year-01-01', '$year-12-31']);
    return results.map((r) => MonthlyTotal(month: int.parse(r['month'] as String), totalFen: _toInt(r['total']))).toList();
  }

  Future<int> getYearTotalExpense(int year) async {
    final db = await _db.database;
    final r = await db.rawQuery('SELECT COALESCE(SUM(amount_fen), 0) as t FROM transactions WHERE is_deleted = 0 AND type = ? AND transaction_date >= ? AND transaction_date <= ?', ['expense', '$year-01-01', '$year-12-31']);
    return _toInt(r.first['t']);
  }

  Future<int> getYearTotalIncome(int year) async {
    final db = await _db.database;
    final r = await db.rawQuery('SELECT COALESCE(SUM(amount_fen), 0) as t FROM transactions WHERE is_deleted = 0 AND type = ? AND transaction_date >= ? AND transaction_date <= ?', ['income', '$year-01-01', '$year-12-31']);
    return _toInt(r.first['t']);
  }

  Future<List<CategoryExpense>> getYearCategoryExpenses(int year) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT COALESCE(p.id, c.id) as category_id, COALESCE(p.name, c.name) as category_name,
             COALESCE(p.icon, c.icon) as category_icon, COALESCE(p.color, c.color) as category_color,
             SUM(t.amount_fen) as total_fen
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN categories p ON c.parent_id = p.id
      WHERE t.is_deleted = 0 AND t.type = 'expense' AND t.transaction_date >= ? AND t.transaction_date <= ?
      GROUP BY COALESCE(p.id, c.id) ORDER BY total_fen DESC
    ''', ['$year-01-01', '$year-12-31']);
    return results.map((r) => CategoryExpense(categoryId: r['category_id'] as int, categoryName: r['category_name'] as String, icon: (r['category_icon'] as String?) ?? '📌', color: (r['category_color'] as String?) ?? '#B7B7A4', totalFen: _toInt(r['total_fen'] ?? 0))).toList();
  }

  Future<double> getYearAvgDailyExpense(int year) async {
    final total = await getYearTotalExpense(year);
    final now = DateTime.now();
    final daysInYear = year == now.year ? DateTime.now().difference(DateTime(year, 1, 1)).inDays + 1 : 365;
    return daysInYear > 0 ? total / daysInYear : 0;
  }

  Future<Map<String, String>> getYearMonthlyMaxCategory(int year) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT month, category_name, max_total FROM (
        SELECT SUBSTR(t.transaction_date, 6, 2) as month, COALESCE(p.name, c.name) as category_name,
               SUM(t.amount_fen) as total, MAX(SUM(t.amount_fen)) OVER (PARTITION BY SUBSTR(t.transaction_date, 6, 2)) as max_total
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        LEFT JOIN categories p ON c.parent_id = p.id
        WHERE t.is_deleted = 0 AND t.type = 'expense' AND t.transaction_date >= ? AND t.transaction_date <= ?
        GROUP BY month, COALESCE(p.name, c.name)
      ) WHERE total = max_total
    ''', ['$year-01-01', '$year-12-31']);
    final map = <String, String>{};
    for (final r in results) { map[r['month'] as String] = r['category_name'] as String; }
    return map;
  }

  String _getEndDate(String yearMonth) {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final lastDay = DateTime(year, month + 1, 0).day;
    return '$yearMonth-${lastDay.toString().padLeft(2, '0')}';
  }

  /// 安全转换 SQFlite 聚合结果（SUM/COUNT 在 FFI 上可能返回 double）
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class MonthlyTotal {
  final int month;
  final int totalFen;
  MonthlyTotal({required this.month, required this.totalFen});
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAO — 预算
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BudgetDao {
  final DatabaseService _db = DatabaseService.instance;

  Future<void> setBudget({
    int? categoryId,
    required int amountFen,
    required String yearMonth,
  }) async {
    final db = await _db.database;
    // 先删除同类型同月份旧预算
    await db.delete('budgets', where: 'category_id IS ? AND year_month = ?', whereArgs: [categoryId, yearMonth]);
    // 插入新预算
    await db.insert('budgets', {
      'category_id': categoryId,
      'type': categoryId == null ? 'monthly' : 'category',
      'amount_fen': amountFen,
      'year_month': yearMonth,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int?> getBudget({int? categoryId, required String yearMonth}) async {
    final db = await _db.database;
    final rows = await db.query('budgets',
        where: 'category_id IS ? AND year_month = ? AND is_active = 1',
        whereArgs: [categoryId, yearMonth]);
    if (rows.isEmpty) return null;
    return rows.first['amount_fen'] as int;
  }

  Future<Map<int?, int>> getAllBudgets(String yearMonth) async {
    final db = await _db.database;
    final rows = await db.query('budgets',
        where: 'year_month = ? AND is_active = 1', whereArgs: [yearMonth]);
    final result = <int?, int>{};
    for (final r in rows) {
      result[r['category_id'] as int?] = r['amount_fen'] as int;
    }
    return result;
  }

  Future<void> deleteBudget({int? categoryId, required String yearMonth}) async {
    final db = await _db.database;
    await db.delete('budgets', where: 'category_id IS ? AND year_month = ?', whereArgs: [categoryId, yearMonth]);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAO — 账户
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AccountDao {
  final DatabaseService _db = DatabaseService.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return db.query('accounts', where: 'is_active = 1', orderBy: 'sort_order');
  }

  Future<int> insert(String name, String type, {int initialBalance = 0}) async {
    final db = await _db.database;
    final maxOrder = await db.rawQuery('SELECT MAX(sort_order) as m FROM accounts');
    final order = ((maxOrder.first['m'] as int?) ?? 0) + 1;
    return db.insert('accounts', {
      'name': name, 'type': type,
      'initial_balance_fen': initialBalance,
      'sort_order': order,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> update(int id, String name) async {
    final db = await _db.database;
    return db.update('accounts', {'name': name, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> softDelete(int id) async {
    final db = await _db.database;
    return db.update('accounts', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> seedDefaults() async {
    final existing = await getAll();
    if (existing.isNotEmpty) return;
    final db = await _db.database;
    final defaults = [
      {'name': '微信零钱', 'type': 'wechat', 'sort_order': 0},
      {'name': '支付宝', 'type': 'alipay', 'sort_order': 1},
      {'name': '现金', 'type': 'cash', 'sort_order': 2},
      {'name': '工商银行', 'type': 'bank_card', 'sort_order': 3},
      {'name': '招商银行', 'type': 'bank_card', 'sort_order': 4},
    ];
    for (final a in defaults) {
      await db.insert('accounts', {
        ...a,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAO — 导入批次
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ImportBatchDao {
  final DatabaseService _db = DatabaseService.instance;

  Future<void> insert(ImportBatch batch) async {
    final db = await _db.database;
    await db.insert('import_batches', batch.toMap());
  }

  Future<void> updateStatus(String id, String status, {int? imported, int? skipped}) async {
    final db = await _db.database;
    final updates = <String, dynamic>{'status': status};
    if (imported != null) updates['imported_count'] = imported;
    if (skipped != null) updates['skipped_count'] = skipped;
    await db.update('import_batches', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ImportBatch>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('import_batches', orderBy: 'created_at DESC');
    return maps.map((m) => ImportBatch.fromMap(m)).toList();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAO — 导入规则
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ImportRuleDao {
  final DatabaseService _db = DatabaseService.instance;

  Future<List<ImportRule>> getBySource(String source) async {
    final db = await _db.database;
    final maps = await db.query('import_rules',
        where: 'source = ?', whereArgs: [source], orderBy: 'is_default DESC');
    return maps.map((m) => ImportRule.fromMap(m)).toList();
  }

  Future<ImportRule?> getDefault(String source) async {
    final db = await _db.database;
    final maps = await db.query('import_rules',
        where: 'source = ? AND is_default = 1', whereArgs: [source]);
    if (maps.isEmpty) return null;
    return ImportRule.fromMap(maps.first);
  }

  Future<int> insert(ImportRule rule) async {
    final db = await _db.database;
    return db.insert('import_rules', rule.toMap());
  }

  Future<int> update(ImportRule rule) async {
    final db = await _db.database;
    return db.update('import_rules', rule.toMap(),
        where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('import_rules', where: 'id = ?', whereArgs: [id]);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAO — 定期交易
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecurringTransactionDao {
  final DatabaseService _db = DatabaseService.instance;

  Future<List<RecurringTransaction>> getAllActive() async {
    final db = await _db.database;
    final maps = await db.query('recurring_transactions',
        where: 'is_active = 1', orderBy: 'next_due_date ASC');
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  Future<List<RecurringTransaction>> getDueToday() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final db = await _db.database;
    final maps = await db.query('recurring_transactions',
        where: 'is_active = 1 AND next_due_date <= ?', whereArgs: [dateStr]);
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  Future<int> insert(RecurringTransaction rt) async {
    final db = await _db.database;
    return db.insert('recurring_transactions', rt.toMap());
  }

  Future<void> updateDueDate(int id, String nextDueDate) async {
    final db = await _db.database;
    await db.update('recurring_transactions', {'next_due_date': nextDueDate},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.update('recurring_transactions', {'is_active': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 导入规则种子数据
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> _seedImportRules(Database db) async {
  // 微信默认规则
  await db.insert('import_rules', {
    'source': 'wechat',
    'name': '微信账单默认规则',
    'field_mapping':
        '{"date":"交易时间","type":"收/支","counterparty":"交易对方","description":"商品","amount":"金额(元)","payment_method":"支付方式","external_id":"交易单号"}',
    'date_format': 'yyyy/MM/dd HH:mm:ss',
    'amount_sign_convention': '支出为正',
    'skip_keywords': '微信红包,转账,退款',
    'is_default': 1,
  });

  // 支付宝默认规则
  await db.insert('import_rules', {
    'source': 'alipay',
    'name': '支付宝账单默认规则',
    'field_mapping':
        '{"date":"交易时间","type":"收/支","counterparty":"交易对方","description":"商品说明","amount":"金额","payment_method":"收/付款方式","external_id":"交易订单号"}',
    'date_format': 'yyyy/MM/dd HH:mm:ss',
    'amount_sign_convention': '支出为正',
    'skip_keywords': '退款,充值,提现',
    'is_default': 1,
  });

  // 银行通用规则
  await db.insert('import_rules', {
    'source': 'bank_csv',
    'name': '银行账单通用规则',
    'field_mapping':
        '{"date":"交易日期","type":"收支方向","counterparty":"对方户名","description":"摘要","amount":"交易金额","external_id":"流水号"}',
    'date_format': 'yyyyMMdd',
    'amount_sign_convention': '支出为正',
    'skip_keywords': '利息,结息,转账存入',
    'is_default': 1,
  });
}
