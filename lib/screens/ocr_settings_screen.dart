import 'package:flutter/material.dart';
import '../utils/ocr_service.dart';

class OcrSettingsScreen extends StatefulWidget {
  const OcrSettingsScreen({super.key});

  @override
  State<OcrSettingsScreen> createState() => _OcrSettingsScreenState();
}

class _OcrSettingsScreenState extends State<OcrSettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _quotaController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _hasKey = false;
  int _usage = 0;
  int _quota = 1000;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final keys = await BaiduOcrConfig.load();
    final usage = await BaiduOcrUsage.getUsage();
    final quota = await BaiduOcrUsage.getQuota();
    setState(() {
      _apiKeyController.text = keys.apiKey ?? '';
      _secretKeyController.text = keys.secretKey ?? '';
      _quota = quota;
      _quotaController.text = '$_quota';
      _hasKey = keys.isConfigured;
      _usage = usage;
      _isLoading = false;
    });
  }

  Future<void> _saveKeys() async {
    final apiKey = _apiKeyController.text.trim();
    final secretKey = _secretKeyController.text.trim();
    final quotaText = _quotaController.text.trim();
    final quota = int.tryParse(quotaText) ?? BaiduOcrConfig.defaultQuota;

    if (apiKey.isEmpty || secretKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写完整的 API Key 和 Secret Key')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      await BaiduOcrConfig.save(apiKey: apiKey, secretKey: secretKey, quota: quota);
      if (mounted) {
        setState(() {
          _hasKey = true;
          _quota = quota;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final result = await testBaiduOcrConnection();
      if (mounted) {
        final isSuccess = result.contains('成功');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: isSuccess ? const Color(0xFF34D399) : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _clearKeys() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('清除后将使用本地 OCR（识别效果较差），确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '清除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BaiduOcrConfig.clear();
      setState(() {
        _apiKeyController.clear();
        _secretKeyController.clear();
        _hasKey = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除')),
        );
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR 识别设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 状态卡片
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasKey
                        ? const Color(0xFF34D399).withValues(alpha: 0.08)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasKey
                          ? const Color(0xFF34D399).withValues(alpha: 0.3)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasKey ? Icons.check_circle : Icons.info_outline,
                            color: _hasKey
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasKey ? '已配置百度 OCR' : '未配置百度 OCR',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _hasKey
                                      ? '将使用百度云端识别，效果更好'
                                      : '当前使用本地 Tesseract 识别，复杂排期表效果较差',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF8A8F98),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_hasKey) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '本月已用额度',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        '$_usage / $_quota 次',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _usage >= _quota
                                              ? const Color(0xFFF54A45)
                                              : const Color(0xFF34D399),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _quota > 0 ? _usage / _quota : 0,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFF2A2A2A),
                                      valueColor: AlwaysStoppedAnimation(
                                        _usage >= _quota
                                            ? const Color(0xFFF54A45)
                                            : const Color(0xFF34D399),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 说明
                const Text(
                  '百度智能云 OCR',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. 访问 cloud.baidu.com 注册账号\n'
                  '2. 进入「产品服务 → 文字识别 → 通用文字识别」\n'
                  '3. 创建应用，获取 API Key 和 Secret Key\n'
                  '4. 每人有 1000 次/月免费额度',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A8F98),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // API Key
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: '如：a1b2c3d4e5f6...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Secret Key
                TextField(
                  controller: _secretKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Secret Key',
                    hintText: '如：x9y8z7w6v5u4...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // 每月额度
                TextField(
                  controller: _quotaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '每月额度（次）',
                    hintText: '如：1000',
                    helperText: '百度标准版默认 1000 次/月，如购买额外包请自行修改',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // 保存按钮
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveKeys,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存配置'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check, size: 18),
                  label: const Text('测试连接'),
                ),

                if (_hasKey) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _clearKeys,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('清除配置'),
                  ),
                ],

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  '隐私说明',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '你的 API Key 仅保存在本机，不会上传到任何服务器。'
                  '图片直接发送给百度 OCR 服务进行识别。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8F98),
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }
}
