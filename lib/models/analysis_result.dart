import 'vitamin_data.dart';
import 'mineral_data.dart';
import 'food_item.dart';

/// 分析结果模型
class AnalysisResult {
  final String id;
  final FoodItem food;
  final List<VitaminData> vitamins;
  final List<MineralData> minerals;
  final DateTime analyzedAt;
  final String? imagePath; // 用户上传的图片路径
  final String? source; // 'text' 或 'image'

  AnalysisResult({
    required this.id,
    required this.food,
    required this.vitamins,
    this.minerals = const [],
    required this.analyzedAt,
    this.imagePath,
    this.source,
  });

  /// 获取主要维生素（按含量排序前5）
  List<VitaminData> get topVitamins {
    final sorted = List<VitaminData>.from(vitamins)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(5).toList();
  }

  /// 获取主要微量元素（按含量排序前5）
  List<MineralData> get topMinerals {
    final sorted = List<MineralData>.from(minerals)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(5).toList();
  }

  /// 获取总维生素含量（标准化为mg）
  double get totalVitaminAmount {
    return vitamins.fold(0, (sum, v) {
      // 统一转换为mg (μg -> mg / 1000)
      final amountInMg = v.unit == 'μg' ? v.amount / 1000 : v.amount;
      return sum + amountInMg;
    });
  }

  /// 获取总微量元素含量（标准化为mg）
  double get totalMineralAmount {
    return minerals.fold(0, (sum, m) {
      final amountInMg = m.unit == 'μg' ? m.amount / 1000 : m.amount;
      return sum + amountInMg;
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'food_name': food.name,
      'food_id': food.id,
      'analyzed_at': analyzedAt.toIso8601String(),
      'image_path': imagePath,
      'source': source,
    };
  }

  /// 完整序列化（用于历史记录存储）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'food': food.toJson(),
      'vitamins': vitamins.map((v) => v.toJson()).toList(),
      'minerals': minerals.map((m) => m.toJson()).toList(),
      'analyzed_at': analyzedAt.toIso8601String(),
      'image_path': imagePath,
      'source': source,
    };
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'] as String,
      food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
      vitamins: (json['vitamins'] as List<dynamic>)
          .map((v) => VitaminData.fromJson(v as Map<String, dynamic>))
          .toList(),
      minerals: (json['minerals'] as List<dynamic>)
          .map((m) => MineralData.fromJson(m as Map<String, dynamic>))
          .toList(),
      analyzedAt: DateTime.parse(json['analyzed_at'] as String),
      imagePath: json['image_path'] as String?,
      source: json['source'] as String?,
    );
  }

  factory AnalysisResult.fromMap(Map<String, dynamic> map, {List<VitaminData>? vitaminList, List<MineralData>? mineralList}) {
    return AnalysisResult(
      id: map['id'] as String,
      food: FoodItem(
        id: map['food_id'] as String? ?? '',
        name: map['food_name'] as String,
      ),
      vitamins: vitaminList ?? [],
      minerals: mineralList ?? [],
      analyzedAt: DateTime.parse(map['analyzed_at'] as String),
      imagePath: map['image_path'] as String?,
      source: map['source'] as String?,
    );
  }

  @override
  String toString() => 'AnalysisResult{food: ${food.name}, vitamins: ${vitamins.length}, minerals: ${minerals.length}}';
}
