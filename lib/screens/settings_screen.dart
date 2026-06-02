import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _followSystemTheme = true;
  int _historyCount = 0;
  bool _isLoading = false;
  String? _apiKey;
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // 延迟加载历史数量，避免测试时数据库未初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistoryCount();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _followSystemTheme = prefs.getBool('follow_system_theme') ?? true;
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _apiKey = prefs.getString('dashscope_api_key');
      _apiKeyController.text = _apiKey ?? '';
    });
    // 设置 API Key 到 AI 服务
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      AIService().setApiKey(_apiKey!);
    }
  }

  Future<void> _loadHistoryCount() async {
    final count = await DatabaseService().getHistoryCount();
    setState(() => _historyCount = count);
  }

  Future<void> _saveThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('follow_system_theme', _followSystemTheme);
    await prefs.setBool('dark_mode', _isDarkMode);
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashscope_api_key', key);
    AIService().setApiKey(key);
    setState(() => _apiKey = key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key 已保存')),
      );
    }
  }

  Future<void> _testApiConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先输入 API Key'), backgroundColor: AppTheme.warningColor),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    // 临时设置 key 测试
    AIService().setApiKey(key);
    final result = await AIService().testConnection();

    setState(() => _isLoading = false);

    if (mounted) {
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功！API Key 有效'), backgroundColor: AppTheme.primaryColor),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接失败，请检查 API Key 是否正确'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有缓存数据吗？包括历史记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await DatabaseService().clearHistory();
      await _loadHistoryCount();
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 外观设置
          _buildSectionHeader('外观'),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_auto),
            title: const Text('跟随系统主题'),
            subtitle: const Text('自动切换浅色/深色模式'),
            value: _followSystemTheme,
            onChanged: (value) {
              setState(() {
                _followSystemTheme = value;
              });
              _saveThemeSettings();
            },
          ),
          if (!_followSystemTheme)
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('深色模式'),
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                });
                _saveThemeSettings();
              },
            ),
          const Divider(),

          // AI 服务配置
          _buildSectionHeader('AI 服务'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AIService().isConfigured ? Icons.check_circle : Icons.warning,
                        color: AIService().isConfigured ? AppTheme.primaryColor : AppTheme.warningColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AIService().isConfigured ? 'AI 服务已配置' : 'AI 服务未配置',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AIService().isConfigured ? AppTheme.primaryColor : AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      hintText: '输入 DashScope API Key',
                      labelText: 'API Key',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: '测试连接',
                            onPressed: _testApiConnection,
                          ),
                          IconButton(
                            icon: const Icon(Icons.save),
                            tooltip: '保存',
                            onPressed: _saveApiKey,
                          ),
                        ],
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '配置后首次查询会调用 AI 分析，结果自动保存到本地，后续可离线查询',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryLight.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),

          // 数据管理
          _buildSectionHeader('数据管理'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('历史记录'),
            subtitle: Text('共 $_historyCount 条记录'),
            trailing: TextButton(
              onPressed: _historyCount > 0 ? _clearCache : null,
              child: const Text('清空'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: AppTheme.errorColor),
            title: const Text('清除所有缓存'),
            subtitle: const Text('删除历史记录和临时文件'),
            onTap: _isLoading ? null : _clearCache,
          ),
          const Divider(),

          // 关于
          _buildSectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: Text(AppConstants.appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            subtitle: const Text('数据仅存储在本地'),
            onTap: () => _showPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('使用帮助'),
            onTap: () => _showHelp(context),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: TextStyle(
                color: AppTheme.textSecondaryLight.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私政策'),
        content: const SingleChildScrollView(
          child: Text(
            '维生素分析仪尊重您的隐私。\n\n'
            '1. 数据存储：所有分析数据仅存储在您的设备本地，不会上传到任何服务器。\n\n'
            '2. 图片处理：拍照识别的图片仅用于本地分析，不会保存或传输。\n\n'
            '3. 权限使用：相机权限仅用于拍照识别功能，相册权限仅用于选择图片。\n\n'
            '4. 第三方服务：当前版本不使用任何第三方分析服务。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助'),
        content: const SingleChildScrollView(
          child: Text(
            '如何使用维生素分析仪：\n\n'
            '1. 文字输入：在首页点击"文字输入"，输入食物名称（如"苹果"），即可查看维生素分析。\n\n'
            '2. 拍照识别：点击"拍照识别"，拍摄或选择食物照片，AI 将分析其营养成分。\n\n'
            '3. 查看结果：分析结果包含维生素含量、比例分布图表和每日摄入量对比。\n\n'
            '4. 历史记录：所有分析记录保存在"历史"页面，可随时查看。\n\n'
            '支持的食物：苹果、西兰花、橙子、胡萝卜、鸡蛋、三文鱼、菠菜、香蕉、杏仁、牛奶等。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
