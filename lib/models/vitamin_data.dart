/// 维生素数据模型
class VitaminData {
  final String name;       // 如 "维生素C"
  final String code;       // 如 "vitamin_c"
  final double amount;     // 含量
  final String unit;       // 单位 (mg/μg)
  final double? dailyValue; // 占每日推荐摄入量百分比
  final double dailyRecommended; // 每日推荐摄入量

  VitaminData({
    required this.name,
    required this.code,
    required this.amount,
    required this.unit,
    this.dailyValue,
    required this.dailyRecommended,
  });

  /// 计算占每日推荐摄入量的百分比
  double get percentageOfDaily {
    if (dailyRecommended <= 0) return 0;
    return (amount / dailyRecommended) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'amount': amount,
      'unit': unit,
      'daily_value': dailyValue,
      'daily_recommended': dailyRecommended,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory VitaminData.fromJson(Map<String, dynamic> json) => VitaminData.fromMap(json);

  factory VitaminData.fromMap(Map<String, dynamic> map) {
    return VitaminData(
      name: map['name'] as String,
      code: map['code'] as String,
      amount: (map['amount'] as num).toDouble(),
      unit: map['unit'] as String,
      dailyValue: map['daily_value'] != null ? (map['daily_value'] as num).toDouble() : null,
      dailyRecommended: (map['daily_recommended'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'VitaminData{name: $name, amount: $amount$unit, daily: ${percentageOfDaily.toStringAsFixed(1)}%}';
  }
}
