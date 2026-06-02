import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/mineral_data.dart';
import '../utils/theme.dart';

/// 微量元素饼图组件
class MineralPieChart extends StatelessWidget {
  final List<MineralData> minerals;
  final double radius;

  const MineralPieChart({
    super.key,
    required this.minerals,
    this.radius = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (minerals.isEmpty) {
      return const Center(child: Text('暂无微量元素数据'));
    }

    // 按含量排序，取前6个，其余归为"其他"
    final sorted = List<MineralData>.from(minerals)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    
    final displayMinerals = sorted.take(6).toList();
    final colors = _generateColors(displayMinerals.length);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: displayMinerals.asMap().entries.map((entry) {
          final index = entry.key;
          final mineral = entry.value;
          final percentage = _calculatePercentage(mineral, displayMinerals);
          
          return PieChartSectionData(
            value: mineral.amount,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: radius,
            color: colors[index],
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _buildBadge(mineral.name, colors[index]),
            badgePositionPercentageOffset: 1.2,
          );
        }).toList(),
      ),
    );
  }

  double _calculatePercentage(MineralData mineral, List<MineralData> all) {
    final total = all.fold<double>(0, (sum, m) => sum + m.amount);
    if (total <= 0) return 0;
    return (mineral.amount / total) * 100;
  }

  Widget _buildBadge(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Color> _generateColors(int count) {
    const baseColors = [
      Color(0xFF4CAF50), // 绿
      Color(0xFF2196F3), // 蓝
      Color(0xFFFF9800), // 橙
      Color(0xFF9C27B0), // 紫
      Color(0xFFF44336), // 红
      Color(0xFF00BCD4), // 青
      Color(0xFFFFEB3B), // 黄
      Color(0xFF795548), // 棕
    ];
    return baseColors.take(count).toList();
  }
}

/// 微量元素柱状图组件（每日摄入量对比）
class MineralBarChart extends StatelessWidget {
  final List<MineralData> minerals;

  const MineralBarChart({super.key, required this.minerals});

  @override
  Widget build(BuildContext context) {
    if (minerals.isEmpty) {
      return const Center(child: Text('暂无微量元素数据'));
    }

    // 取前5个主要微量元素
    final displayMinerals = minerals.take(5).toList();
    final maxValue = displayMinerals
        .map((m) => m.percentageOfDaily)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final mineral = displayMinerals[groupIndex];
              return BarTooltipItem(
                '${mineral.name}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: '${mineral.amount}${mineral.unit}\n占每日需求 ${mineral.percentageOfDaily.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < displayMinerals.length) {
                  final name = displayMinerals[value.toInt()].name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      name.length > 2 ? name.substring(0, 2) : name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: displayMinerals.asMap().entries.map((entry) {
          final index = entry.key;
          final mineral = entry.value;
          final percentage = mineral.percentageOfDaily;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: percentage.toDouble(),
                color: _getBarColor(percentage),
                width: 24,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getBarColor(double percentage) {
    if (percentage >= 50) return AppTheme.primaryColor;
    if (percentage >= 20) return AppTheme.infoColor;
    if (percentage >= 10) return AppTheme.warningColor;
    return AppTheme.textSecondaryLight;
  }
}

/// 微量元素环形进度指示器（单个元素）
class MineralCircularIndicator extends StatelessWidget {
  final MineralData mineral;
  final double size;

  const MineralCircularIndicator({
    super.key,
    required this.mineral,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = mineral.percentageOfDaily.clamp(0, 100).toDouble();
    final color = _getColor(percentage);

    return SizedBox(
      width: size,
      height: size + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (percentage / 100).toDouble(),
                    strokeWidth: 8,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: size * 0.2,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          mineral.unit,
                          style: TextStyle(
                            fontSize: size * 0.1,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mineral.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getColor(double percentage) {
    if (percentage >= 50) return AppTheme.primaryColor;
    if (percentage >= 20) return AppTheme.infoColor;
    if (percentage >= 10) return AppTheme.warningColor;
    return AppTheme.textSecondaryLight;
  }
}
