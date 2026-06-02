import 'dart:convert';
import 'dart:developer' show log;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/analysis_result.dart';
import '../models/vitamin_data.dart';
import '../models/mineral_data.dart';
import '../models/food_item.dart';
import '../utils/constants.dart';

/// 本地数据库服务
/// Web 平台使用 localStorage，移动端使用 SQLite
class DatabaseService {
  static dynamic _db;
  static final DatabaseService _instance = DatabaseService._internal();

  // Web 平台内存存储（作为 localStorage 的缓存）
  final Map<String, List<Map<String, dynamic>>> _memoryStore = {
    AppConstants.tableFoods: [],
    AppConstants.tableVitamins: [],
    AppConstants.tableMinerals: [],
    AppConstants.tableHistory: [],
    AppConstants.tableAnalysisCache: [],
  };

  factory DatabaseService() => _instance;
  DatabaseService._internal() {
    if (kIsWeb) {
      _loadFromLocalStorage();
    } else {
      _initMemoryDB();
    }
  }

  bool get _isWeb => kIsWeb;

  // ==================== Web localStorage 持久化 ====================

  void _loadFromLocalStorage() {
    // Web localStorage 已移除，使用内存存储
    _initMemoryDB();
  }

  void _saveToLocalStorage() {
    // Web localStorage 已移除，使用内存存储
  }

  // ==================== 内存数据库初始化（预设数据）====================

  void _initMemoryDB() {
    // 初始化内存中的食物数据
    for (final foodData in AppConstants.defaultFoods) {
      final foodId = foodData['id'] as String;
      _memoryStore[AppConstants.tableFoods]!.add({
        'id': foodId,
        'name': foodData['name'],
        'category': foodData['category'],
      });

      // 初始化维生素数据
      final vitamins = foodData['vitamins'] as Map<String, dynamic>;
      for (final entry in vitamins.entries) {
        final vitaminCode = entry.key;
        final vitaminInfo = AppConstants.vitaminTypes.firstWhere(
          (v) => v['code'] == vitaminCode,
          orElse: () => {'code': vitaminCode, 'name': vitaminCode, 'unit': 'mg', 'daily': 0.0},
        );
        _memoryStore[AppConstants.tableVitamins]!.add({
          'food_id': foodId,
          'name': vitaminInfo['name'],
          'code': vitaminCode,
          'amount': entry.value,
          'unit': vitaminInfo['unit'],
          'daily_recommended': vitaminInfo['daily'],
        });
      }

      // 初始化微量元素数据
      final minerals = foodData['minerals'] as Map<String, dynamic>?;
      if (minerals != null) {
        for (final entry in minerals.entries) {
          final mineralCode = entry.key;
          final mineralInfo = AppConstants.mineralTypes.firstWhere(
            (m) => m['code'] == mineralCode,
            orElse: () => {'code': mineralCode, 'name': mineralCode, 'unit': 'mg', 'daily': 0.0},
          );
          _memoryStore[AppConstants.tableMinerals]!.add({
            'food_id': foodId,
            'name': mineralInfo['name'],
            'code': mineralCode,
            'amount': entry.value,
            'unit': mineralInfo['unit'],
            'daily_recommended': mineralInfo['daily'],
          });
        }
      }
    }
  }

  Future<dynamic> get database async {
    if (_isWeb) return null;
    _db ??= await _initDB();
    return _db!;
  }

  Future<dynamic> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(dynamic db, int version) async {
    // 食物表
    await db.execute('''
      CREATE TABLE ${AppConstants.tableFoods} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        image_url TEXT,
        description TEXT
      )
    ''');

    // 维生素表
    await db.execute('''
      CREATE TABLE ${AppConstants.tableVitamins} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        amount REAL NOT NULL,
        unit TEXT NOT NULL,
        daily_value REAL,
        daily_recommended REAL NOT NULL,
        FOREIGN KEY (food_id) REFERENCES ${AppConstants.tableFoods}(id)
      )
    ''');

    // 微量元素表
    await db.execute('''
      CREATE TABLE ${AppConstants.tableMinerals} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        amount REAL NOT NULL,
        unit TEXT NOT NULL,
        daily_value REAL,
        daily_recommended REAL NOT NULL,
        FOREIGN KEY (food_id) REFERENCES ${AppConstants.tableFoods}(id)
      )
    ''');

    // 历史记录表
    await db.execute('''
      CREATE TABLE ${AppConstants.tableHistory} (
        id TEXT PRIMARY KEY,
        food_name TEXT NOT NULL,
        food_id TEXT,
        analyzed_at TEXT NOT NULL,
        image_path TEXT,
        source TEXT
      )
    ''');

    // 分析缓存表（保存完整分析结果，用于离线查询）
    await db.execute('''
      CREATE TABLE ${AppConstants.tableAnalysisCache} (
        id TEXT PRIMARY KEY,
        food_name TEXT NOT NULL,
        food_id TEXT,
        vitamins_json TEXT NOT NULL,
        minerals_json TEXT,
        analyzed_at TEXT NOT NULL,
        source TEXT
      )
    ''');

    // 初始化默认食物数据
    await _seedDefaultData(db);
  }

  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    // 后续版本升级处理
  }

  // ==================== Web 平台内存存储方法 ====================

  List<Map<String, dynamic>> _memoryQuery(String table, {String? orderBy}) {
    var results = List<Map<String, dynamic>>.from(_memoryStore[table] ?? []);
    if (orderBy != null && orderBy.contains('DESC')) {
      results = results.reversed.toList();
    }
    return results;
  }

  List<Map<String, dynamic>> _memoryWhere(String table, String field, dynamic value) {
    return (_memoryStore[table] ?? []).where((item) => item[field] == value).toList();
  }

  List<Map<String, dynamic>> _memorySearch(String table, String field, String query) {
    return (_memoryStore[table] ?? []).where((item) {
      final itemValue = item[field]?.toString().toLowerCase() ?? '';
      return itemValue.contains(query.toLowerCase());
    }).toList();
  }

  void _memoryInsert(String table, Map<String, dynamic> data) {
    _memoryStore[table] ??= [];
    _memoryStore[table]!.add(Map<String, dynamic>.from(data));
  }

  void _memoryDelete(String table, String field, dynamic value) {
    _memoryStore[table] ??= [];
    _memoryStore[table]!.removeWhere((item) => item[field] == value);
  }

  void _memoryClear(String table) {
    _memoryStore[table] = [];
  }

  // ==================== SQLite 初始化 ====================

  /// 初始化默认食物数据
  Future<void> _seedDefaultData(dynamic db) async {
    for (final foodData in AppConstants.defaultFoods) {
      final foodId = foodData['id'] as String;
      
      // 插入食物
      await db.insert(AppConstants.tableFoods, {
        'id': foodId,
        'name': foodData['name'],
        'category': foodData['category'],
      });

      // 插入维生素数据
      final vitamins = foodData['vitamins'] as Map<String, dynamic>;
      for (final entry in vitamins.entries) {
        final vitaminCode = entry.key;
        final vitaminInfo = AppConstants.vitaminTypes.firstWhere(
          (v) => v['code'] == vitaminCode,
          orElse: () => {'code': vitaminCode, 'name': vitaminCode, 'unit': 'mg', 'daily': 0.0},
        );
        
        await db.insert(AppConstants.tableVitamins, {
          'food_id': foodId,
          'name': vitaminInfo['name'],
          'code': vitaminCode,
          'amount': entry.value,
          'unit': vitaminInfo['unit'],
          'daily_recommended': vitaminInfo['daily'],
        });
      }

      // 插入微量元素数据
      final minerals = foodData['minerals'] as Map<String, dynamic>?;
      if (minerals != null) {
        for (final entry in minerals.entries) {
          final mineralCode = entry.key;
          final mineralInfo = AppConstants.mineralTypes.firstWhere(
            (m) => m['code'] == mineralCode,
            orElse: () => {'code': mineralCode, 'name': mineralCode, 'unit': 'mg', 'daily': 0.0},
          );
          
          await db.insert(AppConstants.tableMinerals, {
            'food_id': foodId,
            'name': mineralInfo['name'],
            'code': mineralCode,
            'amount': entry.value,
            'unit': mineralInfo['unit'],
            'daily_recommended': mineralInfo['daily'],
          });
        }
      }
    }
  }

  // ==================== 食物查询 ====================

  /// 搜索食物（模糊匹配）
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (_isWeb) {
      return _memorySearch(AppConstants.tableFoods, 'name', query);
    }
    final db = await database;
    return await db.query(
      AppConstants.tableFoods,
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name',
    );
  }

  /// 获取所有食物
  Future<List<Map<String, dynamic>>> getAllFoods() async {
    if (_isWeb) {
      return _memoryQuery(AppConstants.tableFoods, orderBy: 'name');
    }
    final db = await database;
    return await db.query(AppConstants.tableFoods, orderBy: 'name');
  }

  /// 根据ID获取食物
  Future<Map<String, dynamic>?> getFoodById(String id) async {
    if (_isWeb) {
      final results = _memoryWhere(AppConstants.tableFoods, 'id', id);
      return results.isNotEmpty ? results.first : null;
    }
    final db = await database;
    final results = await db.query(
      AppConstants.tableFoods,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ==================== 维生素查询 ====================

  /// 获取食物的维生素数据
  Future<List<Map<String, dynamic>>> getVitaminsByFoodId(String foodId) async {
    if (_isWeb) {
      return _memoryWhere(AppConstants.tableVitamins, 'food_id', foodId);
    }
    final db = await database;
    return await db.query(
      AppConstants.tableVitamins,
      where: 'food_id = ?',
      whereArgs: [foodId],
    );
  }

  // ==================== 微量元素查询 ====================

  /// 获取食物的微量元素数据
  Future<List<Map<String, dynamic>>> getMineralsByFoodId(String foodId) async {
    if (_isWeb) {
      return _memoryWhere(AppConstants.tableMinerals, 'food_id', foodId);
    }
    final db = await database;
    return await db.query(
      AppConstants.tableMinerals,
      where: 'food_id = ?',
      whereArgs: [foodId],
    );
  }

  // ==================== 分析缓存 CRUD ====================

  /// 保存分析结果到缓存（用于离线查询）
  Future<void> saveAnalysisCache(AnalysisResult result) async {
    final cacheData = {
      'id': result.id,
      'food_name': result.food.name,
      'food_id': result.food.id,
      'vitamins_json': jsonEncode(result.vitamins.map((v) => v.toMap()).toList()),
      'minerals_json': jsonEncode(result.minerals.map((m) => m.toMap()).toList()),
      'analyzed_at': result.analyzedAt.toIso8601String(),
      'source': result.source,
    };

    if (_isWeb) {
      // Web 平台：先删除同名食物的旧缓存
      _memoryStore[AppConstants.tableAnalysisCache]!
          .removeWhere((item) => item['food_name'] == result.food.name);
      _memoryInsert(AppConstants.tableAnalysisCache, cacheData);
      // 持久化到 localStorage
      _saveToLocalStorage();
      return;
    }
    final db = await database;
    // 先删除同名食物的旧缓存
    await db.delete(
      AppConstants.tableAnalysisCache,
      where: 'food_name = ?',
      whereArgs: [result.food.name],
    );
    await db.insert(
      AppConstants.tableAnalysisCache,
      cacheData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 从缓存查询分析结果（按食物名称模糊匹配）
  Future<AnalysisResult?> getAnalysisCache(String foodName) async {
    if (_isWeb) {
      final caches = _memoryStore[AppConstants.tableAnalysisCache] ?? [];
      for (final cache in caches) {
        final cachedName = cache['food_name'] as String;
        if (cachedName.toLowerCase() == foodName.toLowerCase() ||
            cachedName.toLowerCase().contains(foodName.toLowerCase()) ||
            foodName.toLowerCase().contains(cachedName.toLowerCase())) {
          return _parseCacheData(cache);
        }
      }
      return null;
    }
    final db = await database;
    final results = await db.query(
      AppConstants.tableAnalysisCache,
      where: 'food_name LIKE ?',
      whereArgs: ['%$foodName%'],
      orderBy: 'analyzed_at DESC',
      limit: 1,
    );
    if (results.isNotEmpty) {
      return _parseCacheData(results.first);
    }
    return null;
  }

  /// 获取所有缓存记录（用于历史记录页面）
  Future<List<Map<String, dynamic>>> getAllAnalysisCache() async {
    if (_isWeb) {
      return _memoryQuery(AppConstants.tableAnalysisCache, orderBy: 'analyzed_at DESC');
    }
    final db = await database;
    return await db.query(
      AppConstants.tableAnalysisCache,
      orderBy: 'analyzed_at DESC',
    );
  }

  /// 解析缓存数据为 AnalysisResult
  AnalysisResult? _parseCacheData(Map<String, dynamic> cache) {
    try {
      final vitaminsJson = cache['vitamins_json'] as String;
      final mineralsJson = cache['minerals_json'] as String?;
      final vitaminsList = jsonDecode(vitaminsJson) as List<dynamic>;
      final mineralsList = mineralsJson != null ? jsonDecode(mineralsJson) as List<dynamic> : [];

      final vitamins = vitaminsList.map((v) => VitaminData.fromMap(v as Map<String, dynamic>)).toList();
      final minerals = mineralsList.map((m) => MineralData.fromMap(m as Map<String, dynamic>)).toList();

      return AnalysisResult(
        id: cache['id'] as String,
        food: FoodItem(
          id: cache['food_id'] as String? ?? '',
          name: cache['food_name'] as String,
        ),
        vitamins: vitamins,
        minerals: minerals,
        analyzedAt: DateTime.parse(cache['analyzed_at'] as String),
        source: cache['source'] as String?,
      );
    } catch (e) {
      log('Parse cache data failed: $e');
      return null;
    }
  }

  // ==================== 历史记录 CRUD ====================

  /// 保存分析历史
  Future<void> saveHistory(AnalysisResult result) async {
    if (_isWeb) {
      _memoryInsert(AppConstants.tableHistory, result.toMap());
      // 持久化到 localStorage
      _saveToLocalStorage();
      return;
    }
    final db = await database;
    await db.insert(
      AppConstants.tableHistory,
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取所有历史记录
  Future<List<Map<String, dynamic>>> getHistory() async {
    if (_isWeb) {
      return _memoryQuery(AppConstants.tableHistory, orderBy: 'analyzed_at DESC');
    }
    final db = await database;
    return await db.query(
      AppConstants.tableHistory,
      orderBy: 'analyzed_at DESC',
    );
  }

  /// 删除单条历史
  Future<void> deleteHistory(String id) async {
    if (_isWeb) {
      _memoryDelete(AppConstants.tableHistory, 'id', id);
      _saveToLocalStorage();
      return;
    }
    final db = await database;
    await db.delete(
      AppConstants.tableHistory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空所有历史
  Future<void> clearHistory() async {
    if (_isWeb) {
      _memoryClear(AppConstants.tableHistory);
      _memoryClear(AppConstants.tableAnalysisCache);
      _saveToLocalStorage();
      return;
    }
    final db = await database;
    await db.delete(AppConstants.tableHistory);
    await db.delete(AppConstants.tableAnalysisCache);
  }

  /// 获取历史记录数量
  Future<int> getHistoryCount() async {
    if (_isWeb) {
      return (_memoryStore[AppConstants.tableHistory] ?? []).length;
    }
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tableHistory}',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // ==================== 工具方法 ====================

  /// 关闭数据库
  Future<void> close() async {
    if (_isWeb) return;
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  /// 删除整个数据库（调试用）
  Future<void> deleteDatabase() async {
    if (_isWeb) {
      _memoryClear(AppConstants.tableFoods);
      _memoryClear(AppConstants.tableVitamins);
      _memoryClear(AppConstants.tableHistory);
      _memoryClear(AppConstants.tableAnalysisCache);
      // Web localStorage 已移除
      return;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    await databaseFactory.deleteDatabase(path);
    _db = null;
  }
}
