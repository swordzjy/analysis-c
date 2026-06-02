import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../models/vitamin_data.dart';
import '../models/mineral_data.dart';
import '../models/food_item.dart';
import '../utils/theme.dart';
import '../widgets/vitamin_chart.dart';
import '../widgets/mineral_chart.dart';

/// 分析结果页面 - 带 Tab 切换（维生素 / 微量元素）
class ResultScreen extends StatefulWidget {
  final AnalysisResult result;
  final Uint8List? imageBytes; // 图片分析时传入的原图

  const ResultScreen({
    super.key,
    required this.result,
    this.imageBytes,
  });

  /// 从数据库数据创建结果页（用于文字输入分析）
  factory ResultScreen.fromDatabase({
    required String foodId,
    required String foodName,
    required List<Map<String, dynamic>> vitaminMaps,
    List<Map<String, dynamic>>? mineralMaps,
    String? source,
  }) {
    final vitamins = vitaminMaps.map((map) => VitaminData(
      name: map['name'] as String,
      code: map['code'] as String,
      amount: map['amount'] as double,
      unit: map['unit'] as String,
      dailyRecommended: map['daily_recommended'] as double,
      dailyValue: map['daily_value'] as double?,
    )).toList();

    final minerals = mineralMaps?.map((map) => MineralData(
      name: map['name'] as String,
      code: map['code'] as String,
      amount: map['amount'] as double,
      unit: map['unit'] as String,
      dailyRecommended: map['daily_recommended'] as double,
      dailyValue: map['daily_value'] as double?,
    )).toList() ?? [];

    final result = AnalysisResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      food: FoodItem(id: foodId, name: foodName),
      vitamins: vitamins,
      minerals: minerals,
      analyzedAt: DateTime.now(),
      source: source,
    );

    return ResultScreen(result: result);
  }

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析结果'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResult(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.local_florist), text: '维生素'),
            Tab(icon: Icon(Icons.grain), text: '微量元素'),
          ],
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryLight,
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: 维生素
          _buildVitaminTab(),
          // Tab 2: 微量元素
          _buildMineralTab(),
        ],
      ),
    );
  }

  // ==================== 维生素 Tab ====================

  Widget _buildVitaminTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 食物信息卡片
            _buildFoodCard(context),
            const SizedBox(height: 20),

            // 维生素概览
            _buildSectionTitle(context, '维生素概览'),
            const SizedBox(height: 12),
            _buildVitaminOverview(),
            const SizedBox(height: 24),

            // 饼图 - 比例分布
            _buildSectionTitle(context, '维生素比例分布'),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: VitaminPieChart(vitamins: widget.result.vitamins),
            ),
            const SizedBox(height: 24),

            // 柱状图 - 每日摄入量对比
            _buildSectionTitle(context, '占每日推荐摄入量'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: VitaminBarChart(vitamins: widget.result.vitamins),
            ),
            const SizedBox(height: 24),

            // 详细列表
            _buildSectionTitle(context, '维生素详细数据'),
            const SizedBox(height: 12),
            _buildVitaminList(),
            const SizedBox(height: 24),

            // 健康建议
            _buildHealthAdvice(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ==================== 微量元素 Tab ====================

  Widget _buildMineralTab() {
    final minerals = widget.result.minerals;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 食物信息卡片
            _buildFoodCard(context),
            const SizedBox(height: 20),

            if (minerals.isEmpty)
              _buildEmptyMineralState()
            else ...[
              // 微量元素概览
              _buildSectionTitle(context, '微量元素概览'),
              const SizedBox(height: 12),
              _buildMineralOverview(),
              const SizedBox(height: 24),

              // 饼图 - 比例分布
              _buildSectionTitle(context, '微量元素比例分布'),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: MineralPieChart(minerals: minerals),
              ),
              const SizedBox(height: 24),

              // 柱状图 - 每日摄入量对比
              _buildSectionTitle(context, '占每日推荐摄入量'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: MineralBarChart(minerals: minerals),
              ),
              const SizedBox(height: 24),

              // 详细列表
              _buildSectionTitle(context, '微量元素详细数据'),
              const SizedBox(height: 12),
              _buildMineralList(),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMineralState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.science_outlined,
            size: 64,
            color: AppTheme.textSecondaryLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无微量元素数据',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前数据仅包含维生素分析',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryLight.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 共享组件 ====================

  Widget _buildFoodCard(BuildContext context) {
    final isImageSource = widget.result.source == 'image';
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 图片分析时显示原图
          if (isImageSource && widget.imageBytes != null) ...[
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: MemoryImage(widget.imageBytes!),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '拍照识别',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (!isImageSource || widget.imageBytes == null) ...[
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.food_bank,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  widget.result.food.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (widget.result.food.category != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.result.food.category!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '分析时间: ${_formatDate(widget.result.analyzedAt)}',
                  style: TextStyle(
                    color: AppTheme.textSecondaryLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInfoChip(
                      icon: Icons.science,
                      label: '${widget.result.vitamins.length} 种维生素',
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: Icons.grain,
                      label: '${widget.result.minerals.length} 种微量元素',
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: isImageSource ? Icons.camera_alt : Icons.edit,
                      label: isImageSource ? '拍照识别' : '文字输入',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  // ==================== 维生素相关 ====================

  Widget _buildVitaminOverview() {
    final topVitamins = widget.result.topVitamins.take(4).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: topVitamins.map((v) => VitaminCircularIndicator(vitamin: v)).toList(),
    );
  }

  Widget _buildVitaminList() {
    return Column(
      children: widget.result.vitamins.map((vitamin) => _buildVitaminTile(vitamin)).toList(),
    );
  }

  Widget _buildVitaminTile(VitaminData vitamin) {
    final percentage = vitamin.percentageOfDaily;
    final color = _getVitaminColor(percentage);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    vitamin.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${vitamin.amount}${vitamin.unit}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percentage / 100).clamp(0, 1).toDouble(),
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '每日推荐: ${vitamin.dailyRecommended}${vitamin.unit}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 微量元素相关 ====================

  Widget _buildMineralOverview() {
    final topMinerals = widget.result.topMinerals.take(4).toList();

    if (topMinerals.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: topMinerals.map((m) => MineralCircularIndicator(mineral: m)).toList(),
    );
  }

  Widget _buildMineralList() {
    return Column(
      children: widget.result.minerals.map((mineral) => _buildMineralTile(mineral)).toList(),
    );
  }

  Widget _buildMineralTile(MineralData mineral) {
    final percentage = mineral.percentageOfDaily;
    final color = _getVitaminColor(percentage);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mineral.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${mineral.amount}${mineral.unit}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percentage / 100).clamp(0, 1).toDouble(),
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '每日推荐: ${mineral.dailyRecommended}${mineral.unit}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 健康建议 ====================

  Widget _buildHealthAdvice(BuildContext context) {
    final advice = _generateAdvice();

    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Text(
                  '健康建议',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryLight,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateAdvice() {
    final topVitamin = widget.result.topVitamins.isNotEmpty ? widget.result.topVitamins.first : null;
    if (topVitamin == null) return '暂无具体建议';

    final adviceMap = {
      'vitamin_c': '维生素C有助于增强免疫力，促进胶原蛋白合成。建议搭配富含铁的食物一起食用，提高铁的吸收率。',
      'vitamin_a': '维生素A对视力保护和皮肤健康很重要。脂溶性维生素，建议与含脂肪的食物同食以提高吸收。',
      'vitamin_k': '维生素K对血液凝固和骨骼健康至关重要。正在服用抗凝血药物者应注意摄入量。',
      'vitamin_b6': '维生素B6参与蛋白质代谢和神经递质合成。有助于维持正常的神经系统功能。',
      'vitamin_b12': '维生素B12对红细胞形成和神经系统健康很重要。素食者需特别注意补充。',
      'vitamin_d': '维生素D有助于钙的吸收和骨骼健康。适当晒太阳也是获取维生素D的好方法。',
      'vitamin_e': '维生素E是强效抗氧化剂，有助于保护细胞免受自由基损伤。',
      'folate': '叶酸对DNA合成和细胞分裂很重要，孕妇尤其需要充足的叶酸摄入。',
    };

    return adviceMap[topVitamin.code] ??
        '${topVitamin.name}是这种食物的主要维生素贡献。保持均衡饮食，多样化摄入各类营养素。';
  }

  Color _getVitaminColor(double percentage) {
    if (percentage >= 50) return AppTheme.primaryColor;
    if (percentage >= 20) return AppTheme.infoColor;
    if (percentage >= 10) return AppTheme.warningColor;
    return AppTheme.textSecondaryLight;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _shareResult(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能开发中...')),
    );
  }
}
