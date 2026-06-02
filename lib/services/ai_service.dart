import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../models/vitamin_data.dart';
import '../models/mineral_data.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';

/// AI 分析服务
/// 优先使用本地数据库，本地没有则调用 DashScope LLM API
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final DatabaseService _db = DatabaseService();

  // API 配置（从环境变量或配置读取）
  String? _apiKey;
  final String _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  final String _model = 'qwen-turbo';

  /// 设置 API Key
  void setApiKey(String key) {
    _apiKey = key;
  }

  /// 检查是否已配置 API
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// 通过文字分析食物维生素
  Future<AnalysisResult> analyzeByText(String foodName) async {
    // 1. 先查分析缓存（LLM查询过的结果会保存到这里）
    final cachedResult = await _db.getAnalysisCache(foodName);
    if (cachedResult != null) {
      debugPrint('Cache hit for: $foodName');
      // 缓存命中：用新ID记录历史，避免ID冲突
      final historyEntry = AnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        food: cachedResult.food,
        vitamins: cachedResult.vitamins,
        minerals: cachedResult.minerals,
        analyzedAt: DateTime.now(),
        source: 'cache',
      );
      await _db.saveHistory(historyEntry);
      return cachedResult;
    }

    // 2. 再查本地默认数据库
    final localFoods = await _db.searchFoods(foodName);
    if (localFoods.isNotEmpty) {
      final food = localFoods.first;
      final foodId = food['id'] as String;
      final vitaminMaps = await _db.getVitaminsByFoodId(foodId);
      
      if (vitaminMaps.isNotEmpty) {
        final vitamins = vitaminMaps.map((map) => VitaminData(
          name: map['name'] as String,
          code: map['code'] as String,
          amount: map['amount'] as double,
          unit: map['unit'] as String,
          dailyRecommended: map['daily_recommended'] as double,
          dailyValue: map['daily_value'] as double?,
        )).toList();

        // 获取微量元素数据
        final mineralMaps = await _db.getMineralsByFoodId(foodId);
        final minerals = mineralMaps.map((map) => MineralData(
          name: map['name'] as String,
          code: map['code'] as String,
          amount: map['amount'] as double,
          unit: map['unit'] as String,
          dailyRecommended: map['daily_recommended'] as double,
          dailyValue: map['daily_value'] as double?,
        )).toList();

        final result = AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          food: FoodItem(
            id: foodId,
            name: food['name'] as String,
            category: food['category'] as String?,
          ),
          vitamins: vitamins,
          minerals: minerals,
          analyzedAt: DateTime.now(),
          source: 'text',
        );

        // 保存到缓存和历史，下次可直接查询
        await _db.saveAnalysisCache(result);
        await _db.saveHistory(result);
        return result;
      }
    }

    // 3. 本地没有，调用 LLM API
    if (isConfigured) {
      try {
        final result = await _callLLMAPI(foodName);
        if (result != null) {
          // 保存到缓存和历史，下次可离线查询
          await _db.saveAnalysisCache(result);
          await _db.saveHistory(result);
          return result;
        }
      } catch (e) {
        debugPrint('LLM API call failed: $e');
      }
    }

    // 4. API 调用失败或未配置，返回模拟数据
    final mockResult = _generateMockResult(foodName);
    await _db.saveAnalysisCache(mockResult);
    await _db.saveHistory(mockResult);
    return mockResult;
  }

  /// 通过图片分析食物维生素和微量元素
  /// 支持本地文件路径（移动端）或 base64 数据（Web）
  Future<AnalysisResult> analyzeByImage(String imagePath) async {
    // 1. 尝试读取图片并编码为 base64
    Uint8List? imageBytes;
    try {
      if (imagePath.startsWith('data:image')) {
        // Web: base64 data URL
        final base64Data = imagePath.split(',').last;
        imageBytes = base64Decode(base64Data);
      } else if (imagePath.startsWith('http')) {
        // 网络图片：下载
        final response = await http.get(Uri.parse(imagePath))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      } else {
        // 本地文件
        imageBytes = await File(imagePath).readAsBytes();
      }
    } catch (e) {
      debugPrint('Read image failed: $e');
    }

    // 2. 如果有图片且 API 已配置，调用多模态 LLM
    if (imageBytes != null && isConfigured) {
      try {
        final result = await _callVisionLLMAPI(imageBytes);
        if (result != null) {
          await _db.saveAnalysisCache(result);
          await _db.saveHistory(result);
          return result;
        }
      } catch (e) {
        debugPrint('Vision LLM API failed: $e');
      }
    }

    // 3. 降级：回退到模拟数据（MVP 兜底）
    final mockFoods = ['苹果', '西兰花', '鸡蛋', '三文鱼', '橙子'];
    final randomFood = mockFoods[Random().nextInt(mockFoods.length)];
    return analyzeByText(randomFood);
  }

  /// 调用多模态 LLM API（支持图片+文字）
  Future<AnalysisResult?> _callVisionLLMAPI(Uint8List imageBytes) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;

    final base64Image = base64Encode(imageBytes);
    final prompt = _buildVisionPrompt();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'qwen-vl-plus', // 多模态视觉模型
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                },
              ],
            }
          ],
          'max_tokens': 2048,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String? ?? '';
        return _parseVisionLLMResponse(content);
      } else {
        debugPrint('Vision LLM error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Vision LLM exception: $e');
      return null;
    }
  }

  /// 构建视觉分析提示词
  String _buildVisionPrompt() {
    return '请识别图片中的食物，并分析其营养成分。\n\n'
        '【要求】\n'
        '1. 识别图片中的主要食物（一种或多种）\n'
        '2. 分析该食物的维生素含量\n'
        '3. 分析该食物的微量元素含量\n'
        '4. 给出每日推荐摄入量占比\n\n'
        '【输出格式】严格的 JSON，不要任何其他文字：\n'
        '{\n'
        '  "status": "success",\n'
        '  "food_name": "识别出的食物名称",\n'
        '  "category": "类别",\n'
        '  "vitamins": [\n'
        '    {"name": "维生素C", "code": "vitamin_c", "amount": 数值, "unit": "mg", "daily_recommended": 数值}\n'
        '  ],\n'
        '  "minerals": [\n'
        '    {"name": "铁", "code": "iron", "amount": 数值, "unit": "mg", "daily_recommended": 数值}\n'
        '  ],\n'
        '  "health_advice": "建议"\n'
        '}\n\n'
        '维生素：维生素A、B1、B2、B6、B12、C、D、E、K、叶酸、烟酸、泛酸。\n'
        '微量元素：钙、铁、锌、镁、钾、钠、硒、铜、锰、磷。\n'
        'amount 必须是数字，不要带单位。如果图片中没有食物，返回 {"status": "error", "message": "未识别到食物"}';
  }

  /// 解析视觉 LLM 响应
  AnalysisResult? _parseVisionLLMResponse(String content) {
    try {
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final jsonStr = content.substring(jsonStart, jsonEnd + 1);
      final data = jsonDecode(jsonStr);

      final status = data['status'] as String? ?? 'success';
      if (status == 'error') return null;

      final foodName = data['food_name'] as String? ?? '未知食物';
      final category = data['category'] as String?;
      final vitaminsList = data['vitamins'] as List<dynamic>? ?? [];
      final mineralsList = data['minerals'] as List<dynamic>? ?? [];

      final vitamins = vitaminsList.map((v) {
        final amount = v['amount'];
        final daily = v['daily_recommended'] ?? 0;
        return VitaminData(
          name: v['name'] as String? ?? '未知',
          code: v['code'] as String? ?? 'unknown',
          amount: amount is num ? amount.toDouble() : 0.0,
          unit: v['unit'] as String? ?? 'mg',
          dailyRecommended: daily is num ? daily.toDouble() : 0.0,
          dailyValue: daily > 0 ? (amount / daily) * 100 : null,
        );
      }).toList();

      final minerals = mineralsList.map((m) {
        final amount = m['amount'];
        final daily = m['daily_recommended'] ?? 0;
        return MineralData(
          name: m['name'] as String? ?? '未知',
          code: m['code'] as String? ?? 'unknown',
          amount: amount is num ? amount.toDouble() : 0.0,
          unit: m['unit'] as String? ?? 'mg',
          dailyRecommended: daily is num ? daily.toDouble() : 0.0,
          dailyValue: daily > 0 ? (amount / daily) * 100 : null,
        );
      }).toList();

      return AnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        food: FoodItem(
          id: 'vision_${DateTime.now().millisecondsSinceEpoch}',
          name: foodName,
          category: category,
        ),
        vitamins: vitamins,
        minerals: minerals,
        analyzedAt: DateTime.now(),
        source: 'image',
      );
    } catch (e) {
      debugPrint('Parse vision response failed: $e');
      return null;
    }
  }

  /// 调用 DashScope LLM API
  Future<AnalysisResult?> _callLLMAPI(String foodName) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return null;
    }

    final prompt = _buildPrompt(foodName);
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 2048,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String? ?? '';
        return _parseLLMResponse(foodName, content);
      } else {
        debugPrint('LLM API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('LLM API exception: $e');
      return null;
    }
  }

  /// 构建提示词 - 两步验证：先判断是否是食物，再返回营养
  String _buildPrompt(String foodName) {
    return '你是一个严格的食物识别系统。请判断 "$foodName" 是否是真实存在的食物。\n\n'
        '【判断标准】\n'
        '- 必须是真实可食用的食物、食材、水果、蔬菜、肉类、海鲜、谷物、坚果、乳制品等\n'
        '- 以下情况必须返回 error：不存在的词、无意义词、地名、人名、品牌名、店铺名、网络用语、建筑名、抽象概念\n'
        '- 示例："苹果"=食物，"西兰花"=食物，"铺头"=error（店铺名），"北京"=error（地名），"张三"=error（人名）\n\n'
        '【输出格式】严格的 JSON，不要任何其他文字：\n\n'
        '真实食物：\n'
        '{\n'
        '  "status": "success",\n'
        '  "food_name": "标准名称",\n'
        '  "category": "类别",\n'
        '  "vitamins": [\n'
        '    {"name": "维生素C", "code": "vitamin_c", "amount": 数值, "unit": "mg", "daily_recommended": 数值}\n'
        '  ],\n'
        '  "minerals": [\n'
        '    {"name": "铁", "code": "iron", "amount": 数值, "unit": "mg", "daily_recommended": 数值}\n'
        '  ],\n'
        '  "health_advice": "建议"\n'
        '}\n\n'
        '非食物：\n'
        '{\n'
        '  "status": "error",\n'
        '  "message": "无法识别该食物"\n'
        '}\n\n'
        '维生素：维生素A、B1、B2、B6、B12、C、D、E、K、叶酸、烟酸、泛酸。\n'
        '微量元素：钙、铁、锌、镁、钾、钠、硒、铜、锰、磷。\n'
        'amount 必须是数字，不要带单位。';
  }

  /// 解析 LLM 响应
  AnalysisResult? _parseLLMResponse(String foodName, String content) {
    try {
      // 提取 JSON 部分
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;
      
      final jsonStr = content.substring(jsonStart, jsonEnd + 1);
      final data = jsonDecode(jsonStr);

      // 检查状态
      final status = data['status'] as String? ?? 'success';
      if (status == 'error') {
        return null; // 不是真实食物，返回 null
      }

      final parsedFoodName = data['food_name'] as String? ?? foodName;
      final category = data['category'] as String?;
      final vitaminsList = data['vitamins'] as List<dynamic>? ?? [];
      final mineralsList = data['minerals'] as List<dynamic>? ?? [];

      final vitamins = vitaminsList.map((v) {
        final amount = v['amount'];
        final daily = v['daily_recommended'] ?? 0;
        return VitaminData(
          name: v['name'] as String? ?? '未知',
          code: v['code'] as String? ?? 'unknown',
          amount: amount is num ? amount.toDouble() : 0.0,
          unit: v['unit'] as String? ?? 'mg',
          dailyRecommended: daily is num ? daily.toDouble() : 0.0,
          dailyValue: daily > 0 ? (amount / daily) * 100 : null,
        );
      }).toList();

      final minerals = mineralsList.map((m) {
        final amount = m['amount'];
        final daily = m['daily_recommended'] ?? 0;
        return MineralData(
          name: m['name'] as String? ?? '未知',
          code: m['code'] as String? ?? 'unknown',
          amount: amount is num ? amount.toDouble() : 0.0,
          unit: m['unit'] as String? ?? 'mg',
          dailyRecommended: daily is num ? daily.toDouble() : 0.0,
          dailyValue: daily > 0 ? (amount / daily) * 100 : null,
        );
      }).toList();

      final result = AnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        food: FoodItem(
          id: 'llm_${DateTime.now().millisecondsSinceEpoch}',
          name: parsedFoodName,
          category: category,
        ),
        vitamins: vitamins,
        minerals: minerals,
        analyzedAt: DateTime.now(),
        source: 'text',
      );

      return result;
    } catch (e) {
      debugPrint('Parse LLM response failed: $e');
      return null;
    }
  }

  /// 测试 API 连接
  Future<bool> testConnection() async {
    if (_apiKey == null || _apiKey!.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': '你好',
            }
          ],
          'max_tokens': 10,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Test connection failed: $e');
      return false;
    }
  }

  /// 生成模拟分析结果（备用）
  AnalysisResult _generateMockResult(String foodName) {
    final vitamins = _generateMockVitamins();
    final minerals = _generateMockMinerals();
    
    return AnalysisResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      food: FoodItem(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        name: foodName,
        category: '未知',
      ),
      vitamins: vitamins,
      minerals: minerals,
      analyzedAt: DateTime.now(),
      source: 'text',
    );
  }

  /// 生成模拟维生素数据
  List<VitaminData> _generateMockVitamins() {
    final mockData = [
      {'name': '维生素C', 'code': 'vitamin_c', 'amount': 52.0, 'unit': 'mg', 'daily': 90.0},
      {'name': '维生素A', 'code': 'vitamin_a', 'amount': 54.0, 'unit': 'μg', 'daily': 900.0},
      {'name': '维生素K', 'code': 'vitamin_k', 'amount': 4.5, 'unit': 'μg', 'daily': 120.0},
      {'name': '维生素B6', 'code': 'vitamin_b6', 'amount': 0.041, 'unit': 'mg', 'daily': 1.3},
      {'name': '叶酸', 'code': 'folate', 'amount': 3.0, 'unit': 'μg', 'daily': 400.0},
      {'name': '维生素E', 'code': 'vitamin_e', 'amount': 0.18, 'unit': 'mg', 'daily': 15.0},
      {'name': '维生素B2', 'code': 'vitamin_b2', 'amount': 0.027, 'unit': 'mg', 'daily': 1.3},
    ];

    return mockData.map((data) => VitaminData(
      name: data['name'] as String,
      code: data['code'] as String,
      amount: data['amount'] as double,
      unit: data['unit'] as String,
      dailyRecommended: data['daily'] as double,
      dailyValue: ((data['amount'] as double) / (data['daily'] as double)) * 100,
    )).toList();
  }

  /// 生成模拟微量元素数据
  List<MineralData> _generateMockMinerals() {
    final mockData = [
      {'name': '钙', 'code': 'calcium', 'amount': 11.0, 'unit': 'mg', 'daily': 1000.0},
      {'name': '铁', 'code': 'iron', 'amount': 0.36, 'unit': 'mg', 'daily': 8.0},
      {'name': '钾', 'code': 'potassium', 'amount': 107.0, 'unit': 'mg', 'daily': 2000.0},
      {'name': '镁', 'code': 'magnesium', 'amount': 5.0, 'unit': 'mg', 'daily': 310.0},
      {'name': '锌', 'code': 'zinc', 'amount': 0.04, 'unit': 'mg', 'daily': 8.0},
    ];

    return mockData.map((data) => MineralData(
      name: data['name'] as String,
      code: data['code'] as String,
      amount: data['amount'] as double,
      unit: data['unit'] as String,
      dailyRecommended: data['daily'] as double,
      dailyValue: ((data['amount'] as double) / (data['daily'] as double)) * 100,
    )).toList();
  }
}
