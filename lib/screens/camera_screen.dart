import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../utils/theme.dart';
import 'result_screen.dart';

/// 拍照/选图页面 - 支持真实图片分析
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final AIService _aiService = AIService();
  bool _isAnalyzing = false;
  String? _selectedImagePath;
  Uint8List? _imageBytes; // 用于显示本地图片
  String? _analyzingStep; // 分析步骤提示

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照识别'),
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
            // 图片预览区域
            Expanded(
              child: _selectedImagePath != null
                  ? _buildImagePreview()
                  : _buildEmptyState(),
            ),
            const SizedBox(height: 20),

            // 分析状态提示
            if (_isAnalyzing && _analyzingStep != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _analyzingStep!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 操作按钮
            if (_selectedImagePath == null) ...[
              _buildActionButton(
                icon: Icons.camera_alt,
                label: '拍照',
                color: AppTheme.primaryColor,
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.photo_library,
                label: '从相册选择',
                color: AppTheme.infoColor,
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ] else ...[
              _buildActionButton(
                icon: _isAnalyzing ? null : Icons.analytics,
                label: _isAnalyzing ? '分析中...' : '开始分析',
                color: AppTheme.primaryColor,
                onPressed: _isAnalyzing ? null : _analyzeImage,
                isLoading: _isAnalyzing,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _clearImage,
                icon: const Icon(Icons.refresh),
                label: const Text('重新选择'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondaryLight.withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: AppTheme.textSecondaryLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '拍摄或选择食物照片',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI 将自动识别并分析维生素和微量元素',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryLight.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          // 能力说明标签
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildCapabilityChip('🔍 食物识别'),
              _buildCapabilityChip('🧬 维生素分析'),
              _buildCapabilityChip('⚗️ 微量元素'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    // 使用合适的图片显示方式
    ImageProvider imageProvider;
    if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } else if (_selectedImagePath!.startsWith('http')) {
      imageProvider = NetworkImage(_selectedImagePath!);
    } else {
      imageProvider = FileImage(File(_selectedImagePath!));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
      child: _isAnalyzing
          ? Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'AI 正在识别食物中...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '分析维生素和微量元素含量',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildActionButton({
    required IconData? icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        // 读取图片字节用于显示
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImagePath = image.path;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImagePath = null;
      _imageBytes = null;
    });
  }

  Future<void> _analyzeImage() async {
    if (_selectedImagePath == null) return;

    setState(() {
      _isAnalyzing = true;
      _analyzingStep = '正在读取图片...';
    });

    try {
      // 步骤1: 准备图片
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _analyzingStep = 'AI 识别食物中...');

      // 步骤2: 调用 AI 分析
      final result = await _aiService.analyzeByImage(_selectedImagePath!);

      setState(() => _analyzingStep = '分析完成，保存结果...');

      // 步骤3: 保存到历史记录
      await HistoryService.saveHistory(result);

      if (!mounted) return;

      // 步骤4: 导航到结果页
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            imageBytes: _imageBytes, // 传递图片用于结果页展示
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analyzingStep = null;
        });
      }
    }
  }
}
