# 维生素分析仪 (Vitamin Analyzer) PRD & 开发计划

> **For Hermes:** 使用 subagent-driven-development 技能按任务逐步实施。

**Goal:** 构建一个跨平台 Flutter App，用户通过文字输入或拍照上传食物，AI 分析并展示维生素含量及比例分布。

**Architecture:** 采用 Flutter 跨平台框架，一套代码输出 iOS/Android/Web 三端。AI 分析通过调用云端 LLM API（文字）+ 图像识别 API（图片）实现，营养数据本地缓存。

**Tech Stack:** Flutter 3.32 / Dart / Material 3 / 云端 AI API / 本地 SQLite

---

## 一、产品需求文档 (PRD)

### 1.1 产品定位
- **名称**: 维生素分析仪 (Vitamin Analyzer)
- **Slogan**: 拍一拍，知营养
- **目标用户**: 健康饮食关注者、健身人群、营养师
- **核心价值**: 快速了解食物的维生素构成，辅助科学饮食决策

### 1.2 功能模块

#### 模块 A: 首页入口
- 顶部品牌 Logo + 名称
- 两个主要入口按钮：
  - 📷 拍照识别
  - ⌨️ 文字输入
- 最近分析历史（本地存储）
- 底部 Tab: 首页 / 历史 / 我的

#### 模块 B: 文字输入分析
- 搜索框：输入食物名称（如"苹果"、"西兰花"）
- 支持自然语言（"一个中等大小的苹果"）
- 智能联想：输入时匹配本地食物库
- 点击分析后展示结果页

#### 模块 C: 拍照识别分析
- 调用系统相机（移动端）/ 文件选择（Web）
- 支持相册选取
- 图片预览 + 确认分析按钮
- 分析中 Loading 状态
- 展示结果页

#### 模块 D: 维生素分析结果页
- 食物名称 + 图片
- 维生素含量列表（A、B1、B2、B6、B12、C、D、E、K、叶酸等）
- 可视化图表：
  - 饼图：维生素比例分布
  - 柱状图：含量对比
- 每日推荐摄入量对比（%DV）
- 健康建议文字
- 分享/保存结果按钮

#### 模块 E: 历史记录
- 按时间倒序排列
- 显示食物名 + 分析时间 + 缩略图
- 支持删除单条/清空全部
- 点击可重新查看结果

#### 模块 F: 用户设置
- 主题切换（浅色/深色/跟随系统）
- 语言设置（后续版本）
- 清除缓存
- 关于/隐私政策

### 1.3 非功能需求
- **性能**: 分析响应 < 3秒，页面切换 < 300ms
- **离线**: 支持无网络时查看历史，文字分析可离线（本地数据库）
- **隐私**: 照片仅用于分析，不存储上传；数据本地优先
- **兼容**: iOS 12+ / Android 8+ / 现代浏览器

### 1.4 UI/UX 设计原则
- 绿色健康主题（主色 #4CAF50）
- 卡片式布局，圆角 16dp
- 大字体、高对比度，适合各年龄段
- 动画流畅，反馈及时
- 空状态友好引导

---

## 二、技术架构

```
lib/
├── main.dart                 # 入口，主题配置
├── screens/                  # 页面
│   ├── home_screen.dart      # 首页（两个入口）
│   ├── text_input_screen.dart # 文字输入页
│   ├── camera_screen.dart    # 拍照/选图页
│   ├── result_screen.dart    # 分析结果页
│   ├── history_screen.dart   # 历史记录页
│   └── settings_screen.dart  # 设置页
├── models/                   # 数据模型
│   ├── food_item.dart        # 食物模型
│   ├── vitamin_data.dart     # 维生素数据模型
│   └── analysis_result.dart  # 分析结果模型
├── services/                 # 服务层
│   ├── ai_service.dart       # AI 分析服务（API调用）
│   ├── image_service.dart    # 图片处理服务
│   ├── database_service.dart # 本地数据库服务
│   └── nutrition_api.dart    # 营养数据API
├── widgets/                  # 可复用组件
│   ├── vitamin_chart.dart    # 维生素图表组件
│   ├── food_card.dart        # 食物卡片
│   ├── loading_indicator.dart # 加载动画
│   └── empty_state.dart      # 空状态组件
├── utils/                    # 工具类
│   ├── constants.dart        # 常量定义
│   ├── helpers.dart          # 辅助函数
│   └── theme.dart            # 主题配置
└── providers/                # 状态管理（后续需要时添加）
    └── app_state.dart
```

---

## 三、开发计划 (MVP 2周冲刺)

### Week 1: 核心骨架 + 文字分析

#### Task 1: 项目初始化与基础配置
**Objective:** 搭建 Flutter 项目结构，配置主题与路由
**Files:**
- Modify: `lib/main.dart`
- Create: `lib/utils/constants.dart`, `lib/utils/theme.dart`
- Create: `lib/screens/home_screen.dart`

**Step 1: 配置主题**
```dart
// lib/utils/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color secondaryColor = Color(0xFF81C784);
  
  static ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );
  
  static ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.dark),
    useMaterial3: true,
  );
}
```

**Step 2: 创建首页骨架**
```dart
// lib/screens/home_screen.dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('维生素分析仪')),
      body: Center(child: Text('首页内容')),
    );
  }
}
```

**Step 3: 验证运行**
Run: `flutter run -d chrome` (或模拟器)
Expected: 绿色主题的首页显示

**Step 4: Commit**
```bash
git add .
git commit -m "feat: init project with theme and home screen"
```

---

#### Task 2: 定义数据模型
**Objective:** 创建食物、维生素、分析结果的数据模型
**Files:**
- Create: `lib/models/vitamin_data.dart`
- Create: `lib/models/food_item.dart`
- Create: `lib/models/analysis_result.dart`

**Step 1: 维生素数据模型**
```dart
// lib/models/vitamin_data.dart
class VitaminData {
  final String name;      // 如 "维生素C"
  final String code;      // 如 "vitamin_c"
  final double amount;    // 含量 (mg/μg)
  final String unit;      // 单位
  final double? dailyValue; // 占每日推荐摄入量百分比
  
  VitaminData({
    required this.name,
    required this.code,
    required this.amount,
    required this.unit,
    this.dailyValue,
  });
}
```

**Step 2: 食物模型**
```dart
// lib/models/food_item.dart
class FoodItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String? category;
  
  FoodItem({required this.id, required this.name, this.imageUrl, this.category});
}
```

**Step 3: 分析结果模型**
```dart
// lib/models/analysis_result.dart
class AnalysisResult {
  final String id;
  final FoodItem food;
  final List<VitaminData> vitamins;
  final DateTime analyzedAt;
  final String? imagePath; // 用户上传的图片路径
  
  AnalysisResult({
    required this.id,
    required this.food,
    required this.vitamins,
    required this.analyzedAt,
    this.imagePath,
  });
}
```

**Step 4: Commit**
```bash
git add lib/models/
git commit -m "feat: add data models for food, vitamin, and analysis"
```

---

#### Task 3: 本地数据库服务
**Objective:** 使用 SQLite 存储食物营养数据和历史记录
**Files:**
- Create: `lib/services/database_service.dart`
- Add dependency: `sqflite: ^2.3.0`, `path: ^1.8.3` in `pubspec.yaml`

**Step 1: 添加依赖**
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path: ^1.8.3
  path_provider: ^2.1.1
```

**Step 2: 实现数据库服务**
```dart
// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;
  static const String dbName = 'vitamin_analyzer.db';
  
  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }
  
  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), dbName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }
  
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        image_url TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE vitamins (
        id TEXT PRIMARY KEY,
        food_id TEXT,
        name TEXT,
        code TEXT,
        amount REAL,
        unit TEXT,
        daily_value REAL,
        FOREIGN KEY (food_id) REFERENCES foods(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE history (
        id TEXT PRIMARY KEY,
        food_name TEXT,
        food_id TEXT,
        analyzed_at TEXT,
        image_path TEXT
      )
    ''');
  }
}
```

**Step 3: Commit**
```bash
flutter pub get
git add pubspec.yaml lib/services/
git commit -m "feat: add sqlite database service with schema"
```

---

#### Task 4: 文字输入页面
**Objective:** 实现食物名称搜索输入页面
**Files:**
- Create: `lib/screens/text_input_screen.dart`

**Step 1: 创建搜索页面**
```dart
// lib/screens/text_input_screen.dart
class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});
  
  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('输入食物名称')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '例如：苹果、西兰花、鸡蛋...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.analytics),
              label: const Text('开始分析'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _analyze() {
    if (_controller.text.isNotEmpty) {
      // TODO: 导航到结果页
    }
  }
}
```

**Step 2: Commit**
```bash
git add lib/screens/text_input_screen.dart
git commit -m "feat: add text input screen for food search"
```

---

#### Task 5: 首页入口与导航
**Objective:** 完善首页，添加两个入口按钮和底部导航
**Files:**
- Modify: `lib/screens/home_screen.dart`
- Create: `lib/screens/history_screen.dart`
- Create: `lib/screens/settings_screen.dart`

**Step 1: 更新首页**
```dart
// lib/screens/home_screen.dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const _HomeContent(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.history), label: '历史'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('维生素分析仪', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            _buildEntryCard(
              icon: Icons.camera_alt,
              title: '拍照识别',
              subtitle: '拍一拍，知营养',
              color: Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
            ),
            const SizedBox(height: 16),
            _buildEntryCard(
              icon: Icons.edit,
              title: '文字输入',
              subtitle: '输入食物名称查询',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TextInputScreen())),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEntryCard({...}) { ... }
}
```

**Step 2: Commit**
```bash
git add lib/screens/
git commit -m "feat: complete home screen with navigation and entry cards"
```

---

### Week 2: AI 分析 + 结果展示 + 拍照

#### Task 6: AI 分析服务（文字）
**Objective:** 实现调用云端 API 分析食物维生素
**Files:**
- Create: `lib/services/ai_service.dart`
- Add dependency: `http: ^1.1.0` in `pubspec.yaml`

**Step 1: 实现 AI 服务**
```dart
// lib/services/ai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../models/vitamin_data.dart';
import '../models/food_item.dart';

class AIService {
  static const String _apiEndpoint = 'https://api.example.com/analyze'; // 替换为实际API
  
  Future<AnalysisResult> analyzeByText(String foodName) async {
    // TODO: 调用实际AI API
    // 目前返回模拟数据用于UI开发
    return _mockResult(foodName);
  }
  
  Future<AnalysisResult> analyzeByImage(String imagePath) async {
    // TODO: 上传图片并分析
    return _mockResult('未知食物');
  }
  
  AnalysisResult _mockResult(String foodName) {
    return AnalysisResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      food: FoodItem(id: '1', name: foodName),
      vitamins: [
        VitaminData(name: '维生素C', code: 'vitamin_c', amount: 52, unit: 'mg', dailyValue: 58),
        VitaminData(name: '维生素A', code: 'vitamin_a', amount: 54, unit: 'μg', dailyValue: 6),
        VitaminData(name: '维生素K', code: 'vitamin_k', amount: 4.5, unit: 'μg', dailyValue: 4),
      ],
      analyzedAt: DateTime.now(),
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/services/ai_service.dart pubspec.yaml
git commit -m "feat: add AI analysis service with mock data"
```

---

#### Task 7: 维生素图表组件
**Objective:** 使用 fl_chart 实现饼图和柱状图
**Files:**
- Create: `lib/widgets/vitamin_chart.dart`
- Add dependency: `fl_chart: ^0.66.0` in `pubspec.yaml`

**Step 1: 添加依赖**
```yaml
dependencies:
  fl_chart: ^0.66.0
```

**Step 2: 实现图表组件**
```dart
// lib/widgets/vitamin_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/vitamin_data.dart';

class VitaminPieChart extends StatelessWidget {
  final List<VitaminData> vitamins;
  const VitaminPieChart({super.key, required this.vitamins});
  
  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: vitamins.map((v) => PieChartSectionData(
          value: v.amount,
          title: v.name,
          radius: 80,
        )).toList(),
      ),
    );
  }
}
```

**Step 3: Commit**
```bash
flutter pub get
git add lib/widgets/vitamin_chart.dart pubspec.yaml
git commit -m "feat: add vitamin chart widget with fl_chart"
```

---

#### Task 8: 分析结果页面
**Objective:** 展示食物维生素分析结果
**Files:**
- Create: `lib/screens/result_screen.dart`

**Step 1: 创建结果页**
```dart
// lib/screens/result_screen.dart
class ResultScreen extends StatelessWidget {
  final AnalysisResult result;
  const ResultScreen({super.key, required this.result});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(result.food.name)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 食物信息卡片
              Card(
                child: ListTile(
                  leading: const Icon(Icons.food_bank, size: 48),
                  title: Text(result.food.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  subtitle: Text('分析时间: ${result.analyzedAt}'),
                ),
              ),
              const SizedBox(height: 16),
              
              // 图表
              SizedBox(height: 250, child: VitaminPieChart(vitamins: result.vitamins)),
              const SizedBox(height: 16),
              
              // 维生素列表
              ...result.vitamins.map((v) => _buildVitaminTile(v)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildVitaminTile(VitaminData v) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _getColor(v.code), child: Text(v.code[0].toUpperCase())),
        title: Text(v.name),
        trailing: Text('${v.amount}${v.unit}'),
        subtitle: v.dailyValue != null ? LinearProgressIndicator(value: v.dailyValue! / 100) : null,
      ),
    );
  }
  
  Color _getColor(String code) { ... }
}
```

**Step 2: Commit**
```bash
git add lib/screens/result_screen.dart
git commit -m "feat: add analysis result screen with charts"
```

---

#### Task 9: 拍照/选图页面
**Objective:** 实现移动端相机和相册选择，Web端文件选择
**Files:**
- Create: `lib/screens/camera_screen.dart`
- Create: `lib/services/image_service.dart`
- Add dependency: `image_picker: ^1.0.7` in `pubspec.yaml`

**Step 1: 添加依赖**
```yaml
dependencies:
  image_picker: ^1.0.7
```

**Step 2: 实现图片服务**
```dart
// lib/services/image_service.dart
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  
  Future<String?> pickFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    return image?.path;
  }
  
  Future<String?> pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    return image?.path;
  }
}
```

**Step 3: 创建相机页面**
```dart
// lib/screens/camera_screen.dart
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(context, true),
              icon: const Icon(Icons.camera_alt),
              label: const Text('拍照'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _pickImage(context, false),
              icon: const Icon(Icons.photo_library),
              label: const Text('从相册选择'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImage(BuildContext context, bool fromCamera) async {
    final service = ImageService();
    final path = fromCamera ? await service.pickFromCamera() : await service.pickFromGallery();
    if (path != null && context.mounted) {
      // TODO: 导航到分析页或预览页
    }
  }
}
```

**Step 4: Commit**
```bash
flutter pub get
git add lib/screens/camera_screen.dart lib/services/image_service.dart pubspec.yaml
git commit -m "feat: add camera and gallery image picker"
```

---

#### Task 10: 历史记录页面
**Objective:** 展示本地存储的分析历史
**Files:**
- Modify: `lib/screens/history_screen.dart`
- Modify: `lib/services/database_service.dart` (添加CRUD)

**Step 1: 更新数据库服务**
```dart
// 在 DatabaseService 中添加：
Future<void> saveAnalysis(AnalysisResult result) async {
  final db = await database;
  await db.insert('history', {
    'id': result.id,
    'food_name': result.food.name,
    'food_id': result.food.id,
    'analyzed_at': result.analyzedAt.toIso8601String(),
    'image_path': result.imagePath,
  });
}

Future<List<Map<String, dynamic>>> getHistory() async {
  final db = await database;
  return await db.query('history', orderBy: 'analyzed_at DESC');
}
```

**Step 2: 实现历史页面**
```dart
// lib/screens/history_screen.dart
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  
  Future<void> _loadHistory() async {
    final data = await DatabaseService().getHistory();
    setState(() => _history = data);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: _history.isEmpty
        ? const Center(child: Text('暂无记录'))
        : ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(item['food_name']),
                subtitle: Text(item['analyzed_at']),
              );
            },
          ),
    );
  }
}
```

**Step 3: Commit**
```bash
git add lib/screens/history_screen.dart lib/services/database_service.dart
git commit -m "feat: add history screen with local storage"
```

---

#### Task 11: 设置页面与主题
**Objective:** 实现设置页，支持主题切换
**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Step 1: 创建设置页面**
```dart
// lib/screens/settings_screen.dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题'),
            subtitle: const Text('跟随系统'),
            onTap: () { /* TODO: 主题选择 */ },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('清除缓存'),
            onTap: () async {
              await DatabaseService().clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除')));
              }
            },
          ),
          const AboutListTile(
            icon: Icon(Icons.info),
            applicationName: '维生素分析仪',
            applicationVersion: '1.0.0',
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add settings screen with theme and cache options"
```

---

#### Task 12: 端到端联调与测试
**Objective:** 确保所有页面导航正常，数据流正确
**Files:**
- Modify: 各页面间的导航逻辑
- Run: `flutter test`, `flutter run`

**Step 1: 联调导航**
- 首页 → 文字输入 → 结果页
- 首页 → 拍照 → 结果页
- 历史记录 → 结果页
- 设置页功能验证

**Step 2: 运行测试**
```bash
flutter analyze
flutter test
flutter run -d ios  # 或 android / chrome
```

**Step 3: Commit**
```bash
git add .
git commit -m "feat: complete MVP with end-to-end flow"
```

---

## 四、后续迭代计划

### V1.1 (第3-4周)
- [ ] 接入真实 AI API (OpenAI/Claude/Gemini)
- [ ] 接入图像识别 API (Google Vision)
- [ ] 完善营养数据库（USDA/中国食物成分表）
- [ ] 结果页分享功能（生成图片）

### V1.2 (第5-6周)
- [ ] 用户账号系统（可选同步）
- [ ] 多语言支持（英文）
- [ ] 每日营养摄入追踪
- [ ] 健康建议个性化

### V2.0 (第7-8周)
- [ ] 离线 AI 模型（端侧推理）
- [ ] 批量分析（一餐多菜）
- [ ] 社区功能（分享食谱）
- [ ] 订阅 monetization

---

## 五、附录

### A. 依赖清单
```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0           # SQLite 数据库
  path: ^1.8.3              # 路径处理
  path_provider: ^2.1.1     # 获取应用目录
  http: ^1.1.0              # HTTP 请求
  fl_chart: ^0.66.0         # 图表
  image_picker: ^1.0.7      # 图片选择
  shared_preferences: ^2.2.2  # 轻量配置存储
```

### B. API 设计草案
```
POST /api/analyze/text
Body: { "food_name": "苹果" }
Response: { "food": {}, "vitamins": [] }

POST /api/analyze/image
Body: multipart/form-data (image)
Response: { "food": {}, "vitamins": [] }
```

### C. 设计稿参考
- 主色: #4CAF50 (绿色)
- 辅色: #81C784 (浅绿)
- 背景: #F5F5F5 (浅灰)
- 卡片圆角: 16dp
- 字体: PingFang SC / Roboto
