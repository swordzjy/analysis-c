/// 微量元素数据模型
class MineralData {
  final String name;       // 如 "铁"
  final String code;       // 如 "iron"
  final double amount;     // 含量
  final String unit;       // 单位 (mg/μg)
  final double? dailyValue; // 占每日推荐摄入量百分比
  final double dailyRecommended; // 每日推荐摄入量

  MineralData({
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

  factory MineralData.fromJson(Map<String, dynamic> json) => MineralData.fromMap(json);

  factory MineralData.fromMap(Map<String, dynamic> map) {
    return MineralData(
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
    return 'MineralData{name: $name, amount: $amount$unit, daily: ${percentageOfDaily.toStringAsFixed(1)}%}';
  }
}
