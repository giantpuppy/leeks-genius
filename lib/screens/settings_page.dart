import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../utils/data_backup.dart';
import '../utils/page_transitions.dart';
import 'login_screen.dart';
import 'ocr_settings_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await UserService.getCurrentUsername();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  Future<void> _switchUser() async {
    await UserService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 账户管理
                _buildSectionHeader('账户'),
                _buildManageCard(
                  icon: Icons.account_circle,
                  title: '当前用户',
                  subtitle: _currentUser ?? '未登录',
                  trailing: TextButton.icon(
                    onPressed: _switchUser,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('切换用户'),
                  ),
                ),
                const SizedBox(height: 16),

                // OCR 识别设置
                _buildSectionHeader('识别'),
                _buildManageCard(
                  icon: Icons.document_scanner,
                  title: 'OCR 识别设置',
                  subtitle: '配置百度 OCR API Key',
                  onTap: () => Navigator.push(
                    context,
                    SlideFadeRoute(page: const OcrSettingsScreen()),
                  ),
                ),
                const SizedBox(height: 16),

                // 数据备份与恢复
                _buildSectionHeader('数据'),
                _buildManageCard(
                  icon: Icons.download,
                  title: '导出备份',
                  subtitle: 'JSON 格式',
                  onTap: () async {
                    await DataBackup.exportToJson();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('备份已下载')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildManageCard(
                  icon: Icons.upload,
                  title: '导入恢复',
                  subtitle: '选择 JSON 备份文件',
                  onTap: () async {
                    final result = await DataBackup.importFromJson();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result ?? '已取消')),
                      );
                    }
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8A8F98),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildManageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: Color(0xFF8A8F98))
                : null),
        onTap: onTap,
      ),
    );
  }
}
