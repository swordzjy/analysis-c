import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../services/history_service.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AnalysisResult> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要删除所有历史记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirm == true) {
      await HistoryService.clearHistory();
      _loadHistory();
    }
  }

  Future<void> _deleteItem(String foodName) async {
    await HistoryService.removeHistory(foodName);
    _loadHistory();
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: _history.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clearAll,
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final item = _history[i];
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteItem(item.food.name),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.source == 'image'
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            item.source == 'image' ? Icons.camera_alt : Icons.text_fields,
                            color: item.source == 'image' ? Colors.orange : Colors.green,
                            size: 20,
                          ),
                        ),
                        title: Text(item.food.name),
                        subtitle: Text(
                          '${item.vitamins.length}种维生素 · ${_timeAgo(item.analyzedAt)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultScreen(result: item),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('暂无历史记录', style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('分析的食物会出现在这里', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}
