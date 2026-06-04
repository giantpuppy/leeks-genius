import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../utils/page_transitions.dart';
import '../models/actor.dart';
import '../models/cast_member.dart';
import '../services/user_service.dart';
import 'add_show_screen.dart';
import 'settings_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Show> _shows = [];
  List<Performance> _performances = [];
  List<Actor> _actors = [];
  List<CastMember> _castMembers = [];
  bool _isLoading = true;
  String? _currentUser;
  bool _needsRefresh = true;

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

  // ===== 画廊墙数据计算 =====

  int get _totalSessions =>
      _performances.where((p) => p.status == 'bought').length;

  double get _totalPaid {
    return _performances
        .where((p) => p.status == 'bought')
        .fold(0.0, (sum, p) => sum + (p.actualPrice ?? p.price ?? 0));
  }

  double get _faceValue {
    return _performances
        .where((p) => p.status == 'bought')
        .fold(0.0, (sum, p) => sum + (p.price ?? 0));
  }

  double get _savedValue {
    final diff = _faceValue - _totalPaid;
    return diff > 0 ? diff : 0;
  }

  int get _showsTracked {
    final boughtShowIds = _performances
        .where((p) => p.status == 'bought')
        .map((p) => p.showId)
        .toSet();
    return boughtShowIds.length;
  }

  List<MapEntry<String, int>> get _topCastCredits {
    final boughtPerfIds = _performances
        .where((p) => p.status == 'bought')
        .map((p) => p.id)
        .whereType<int>()
        .toSet();

    final counts = <String, int>{};
    for (final cm in _castMembers) {
      if (boughtPerfIds.contains(cm.performanceId)) {
        counts[cm.actorName] = (counts[cm.actorName] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  String get _dotMatrix {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final boughtDates = <String>{};
    for (final p in _performances) {
      if (p.status == 'bought') boughtDates.add(p.date);
    }

    final buffer = StringBuffer();
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      buffer.write(boughtDates.contains(dateStr) ? '●' : '·');
      if (i % 10 == 0 && i != 0) buffer.write('\n');
    }
    return buffer.toString();
  }

  String _formatCurrency(double value) {
    if (value == 0) return '0';
    final s = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  static const TextStyle _monoLabel = TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    color: Color(0xFF8A8F98),
    letterSpacing: 0.5,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_needsRefresh) {
      _needsRefresh = false;
      _loadData();
    }
  }

  @override
  void deactivate() {
    _needsRefresh = true;
    super.deactivate();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    final performances = await db.getAllPerformances();
    final actors = await db.getAllActors();
    final castMembers = await db.getAllCastMembers();
    final currentUser = await UserService.getCurrentUsername();

    setState(() {
      _shows = shows;
      _performances = performances;
      _actors = actors;
      _castMembers = castMembers;
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 新顶栏：大字标题 + 头像入口
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                // 画廊墙：非对称数据视觉流
                SliverToBoxAdapter(
                  child: _buildGalleryWall(),
                ),
                // 底部资产入口
                SliverToBoxAdapter(
                  child: _buildAssetSection(),
                ),
                // 底部安全区
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final displayName = _currentUser ?? '未登录';
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, statusBarHeight + 16, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          // 右侧头像入口
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              SlideFadeRoute(page: const SettingsPage()),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF6B5BCD).withValues(alpha: 0.2),
              child: Text(
                displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B5BCD),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryWall() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          // ===== 第一排：左高右低 =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左栏：场次痕迹
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SESSIONS', style: _monoLabel),
                    const SizedBox(height: 8),
                    Text(
                      '$_totalSessions',
                      style: const TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 微点阵
                    Text(
                      _dotMatrix,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        height: 1.4,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // 右栏：票房账本
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL PAID', style: _monoLabel),
                    const SizedBox(height: 8),
                    Text(
                      '¥${_formatCurrency(_totalPaid)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'FACE VALUE: ¥${_formatCurrency(_faceValue)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A8F98),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SAVED VALUE: ¥${_formatCurrency(_savedValue)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A8F98),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ===== 艺术感非对称分割线 =====
          const Divider(
            thickness: 1,
            height: 48,
            color: Colors.white10,
            endIndent: 120.0,
          ),
          // ===== 第二排：左低右高 =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左栏：打卡剧目
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SHOWS', style: _monoLabel),
                    const SizedBox(height: 8),
                    Text(
                      '$_showsTracked',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // 右栏：因缘职员表
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CAST CREDITS', style: _monoLabel),
                    const SizedBox(height: 12),
                    if (_topCastCredits.isEmpty)
                      const Text(
                        '暂无数据',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A8F98),
                          fontFamily: 'monospace',
                          height: 2.0,
                        ),
                      )
                    else
                      ..._topCastCredits.map((entry) => Text(
                        '${entry.key} × ${entry.value}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          height: 2.0,
                        ),
                      )),
                  ],
                ),
              ),
            ],
          ),
          // ===== 衔接底部资产清单 =====
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAssetSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildAssetTile(
            icon: Icons.theaters,
            label: '我的剧目',
            count: _shows.length,
            onTap: () => _showShowsSheet(),
          ),
          const Divider(
            height: 1,
            indent: 48,
            color: Color(0xFF2A2A2A),
          ),
          _buildAssetTile(
            icon: Icons.people,
            label: '演员名单',
            count: _actors.length,
            onTap: () => _showActorsSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTile({
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '$count 项',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF8A8F98),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: Color(0xFF8A8F98),
      ),
      onTap: onTap,
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
