import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../utils/theme.dart';
import 'result_screen.dart';

/// 文字输入页面
class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _db = DatabaseService();
  final AIService _ai = AIService();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _errorMessage = null;
      });
      return;
    }

    final results = await _db.searchFoods(text);
    setState(() {
      _suggestions = results;
    });
  }

  void _selectFood(Map<String, dynamic> food) {
    _controller.text = food['name'] as String;
    setState(() {
      _suggestions = [];
    });
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = '请输入食物名称');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 使用 AIService：优先本地数据库，本地没有则调 LLM
      final result = await _ai.analyzeByText(text);

      // 保存到历史记录
      await HistoryService.saveHistory(result);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = '分析出错: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('输入食物名称'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 搜索框
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '例如：苹果、西兰花、鸡蛋...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _suggestions = [];
                            _errorMessage = null;
                          });
                        },
                      )
                    : null,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _analyze(),
            ),
            const SizedBox(height: 8),

            // 错误提示
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // 联想列表
            if (_suggestions.isNotEmpty)
              Expanded(
                child: Card(
                  child: ListView.builder(
                    itemCount: _suggestions.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final food = _suggestions[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          child: const Icon(Icons.food_bank, color: AppTheme.primaryColor),
                        ),
                        title: Text(food['name'] as String),
                        subtitle: food['category'] != null
                            ? Text(food['category'] as String)
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _selectFood(food),
                      );
                    },
                  ),
                ),
              ),

            // 空状态提示
            if (_suggestions.isEmpty && _controller.text.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: AppTheme.textSecondaryLight.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '输入食物名称开始查询',
                        style: TextStyle(
                          color: AppTheme.textSecondaryLight,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '支持：苹果、西兰花、鸡蛋、三文鱼等',
                        style: TextStyle(
                          color: AppTheme.textSecondaryLight.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 分析按钮
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyze,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.analytics),
              label: Text(_isLoading ? '分析中...' : '开始分析'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
