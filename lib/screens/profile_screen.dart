import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../utils/page_transitions.dart';
import '../utils/data_backup.dart';
import '../models/actor.dart';
import '../services/user_service.dart';
import 'add_show_screen.dart';
import 'ocr_settings_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Show> _shows = [];
  List<Performance> _performances = [];
  List<Actor> _actors = [];
  bool _isLoading = true;
  String? _currentUser;

  int get _wantToSeeCount =>
      _performances.where((p) => p.status == 'want_to_see').length;

  int get _boughtCount =>
      _performances.where((p) => p.status == 'bought').length;

  int get _upcomingCount {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));
    return _performances.where((p) {
      if (p.status != 'bought') return false;
      try {
        final date = DateTime.parse(p.date);
        return date.isAfter(now) && date.isBefore(sevenDaysLater);
      } catch (_) {
        return false;
      }
    }).length;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    final performances = await db.getAllPerformances();
    final actors = await db.getAllActors();
    final currentUser = await UserService.getCurrentUsername();

    setState(() {
      _shows = shows;
      _performances = performances;
      _actors = actors;
      _currentUser = currentUser;
      _isLoading = false;
    });
  }

  Future<void> _deleteShow(int showId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除剧目将同时删除其所有场次记录，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      final perfs = await db.getPerformancesByShowId(showId);
      for (final p in perfs) {
        await db.deleteCastMembersByPerformanceId(p.id!);
        await db.deletePerformance(p.id!);
      }
      await db.deleteShow(showId);
      _loadData();
    }
  }

  Future<void> _deleteActor(int actorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定从演员列表中删除吗？不会影响已有场次记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteActor(actorId);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 用户信息
                SliverToBoxAdapter(
                  child: _buildUserHeader(),
                ),
                // 统计卡片
                SliverToBoxAdapter(
                  child: _buildStatsSection(),
                ),
                // 即将演出
                if (_upcomingCount > 0)
                  SliverToBoxAdapter(
                    child: _buildUpcomingSection(),
                  ),
                // 管理入口
                SliverToBoxAdapter(
                  child: _buildManagementSection(),
                ),
              ],
            ),
    );
  }

  Widget _buildUserHeader() {
    final displayName = _currentUser ?? '未登录';
    final isLoggedIn = _currentUser != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF6B5BCD).withValues(alpha: 0.2),
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B5BCD),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoggedIn ? '已登录用户' : '本地使用',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8F98),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _switchUser,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('切换'),
          ),
        ],
      ),
    );
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

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _buildStatCard(
            label: '想看',
            value: '$_wantToSeeCount',
            color: const Color(0xFF811FE2),
            icon: Icons.star_border,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: '已买',
            value: '$_boughtCount',
            color: const Color(0xFF34D399),
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: '即将演出',
            value: '$_upcomingCount',
            color: const Color(0xFFF54A45),
            icon: Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    final now = DateTime.now();
    final upcoming = _performances.where((p) {
      if (p.status != 'bought') return false;
      try {
        final date = DateTime.parse(p.date);
        return date.isAfter(now) &&
            date.isBefore(now.add(const Duration(days: 7)));
      } catch (_) {
        return false;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '未来7天',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...upcoming.map((perf) {
          final show = _shows.firstWhere(
            (s) => s.id == perf.showId,
            orElse: () => Show(name: '未知'),
          );
          final date = DateTime.parse(perf.date);
          final weekday = ['一', '二', '三', '四', '五', '六', '日'];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.month}/${date.day}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF34D399),
                          ),
                        ),
                        Text(
                          '周${weekday[date.weekday - 1]}',
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF34D399).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${perf.time?.substring(0, 5) ?? ''}  ${show.theater ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFB3B3B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (perf.seat != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        perf.seat!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildManagementSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '管理',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildManageCard(
            icon: Icons.theaters,
            title: '我的剧目',
            subtitle: '${_shows.length} 部',
            onTap: () => _showShowsSheet(),
          ),
          const SizedBox(height: 8),
          _buildManageCard(
            icon: Icons.people,
            title: '演员名单',
            subtitle: '${_actors.length} 人',
            onTap: () => _showActorsSheet(),
          ),
          const SizedBox(height: 24),
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildManageCard(
            icon: Icons.document_scanner,
            title: 'OCR 识别设置',
            subtitle: '配置百度 OCR API Key',
            onTap: () => Navigator.push(
              context,
              SlideFadeRoute(page: const OcrSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '数据',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
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
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF8A8F98)),
        onTap: onTap,
      ),
    );
  }

  void _showShowsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '我的剧目',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          SlideFadeRoute(
                            page: const AddShowScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _shows.isEmpty
                    ? Center(
                        child: Text('暂无剧目',
                            style: const TextStyle(color: Color(0xFF8A8F98))),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _shows.length,
                        itemBuilder: (context, index) {
                          final show = _shows[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(
                                show.name.substring(0, 1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(show.name),
                            subtitle: show.theater != null
                                ? Text(show.theater!)
                                : null,
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red[300]),
                              onPressed: () => _deleteShow(show.id!),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showActorsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  '演员名单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _actors.isEmpty
                    ? Center(
                        child: Text('暂无演员',
                            style: const TextStyle(color: Color(0xFF8A8F98))),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _actors.length,
                        itemBuilder: (context, index) {
                          final actor = _actors[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Text(
                                actor.name.substring(0, 1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                            title: Text(actor.name),
                            subtitle: actor.note != null
                                ? Text(actor.note!)
                                : null,
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red[300]),
                              onPressed: () => _deleteActor(actor.id!),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
