import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_result.dart';

class HistoryService {
  static const String _historyKey = 'analysis_history';
  static const int _maxHistory = 50;

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  /// 保存分析结果到历史记录
  static Future<void> saveHistory(AnalysisResult result) async {
    final prefs = await _prefs;
    final history = await getHistory();

    // 检查是否已存在相同食物，存在则移到最前面
    history.removeWhere((item) => item.food.name == result.food.name);

    // 添加新记录到开头
    history.insert(0, result);

    // 限制数量
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }

    // 保存
    final jsonList = history.map((r) => r.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(jsonList));
  }

  /// 获取历史记录
  static Future<List<AnalysisResult>> getHistory() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_historyKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((json) => AnalysisResult.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 清空历史记录
  static Future<void> clearHistory() async {
    final prefs = await _prefs;
    await prefs.remove(_historyKey);
  }

  /// 删除单条记录
  static Future<void> removeHistory(String foodName) async {
    final prefs = await _prefs;
    final history = await getHistory();
    history.removeWhere((item) => item.food.name == foodName);

    final jsonList = history.map((r) => r.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(jsonList));
  }
}
