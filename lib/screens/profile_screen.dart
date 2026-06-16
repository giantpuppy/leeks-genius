import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../utils/page_transitions.dart';
import '../models/actor.dart';
import '../models/cast_member.dart';
import '../models/profile_stats.dart';
import '../services/user_service.dart';
import '../widgets/charts/chart_theme.dart';
import '../widgets/charts/simple_bar_chart.dart';
import '../widgets/charts/horizontal_bar_chart.dart';
import '../widgets/charts/donut_chart.dart';
import 'add_show_screen.dart';
import 'calendar_screen.dart';
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

  TimeSlice _currentSlice = TimeSlice.all;
  ProfileStats _stats = _emptyStats(TimeSlice.all);
  bool _isActorDonut = false;

  static ProfileStats _emptyStats(TimeSlice slice) {
    return ProfileStats(
      timeSlice: slice,
      totalSessions: 0,
      watchedSessions: 0,
      upcomingSessions: 0,
      totalPaid: 0,
      faceValue: 0,
      savedValue: 0,
      totalDurationHours: 0,
      showsTracked: 0,
      monthlySessions: List.generate(12, (_) => 0),
      actorRanking: const [],
      theaterDistribution: const [],
      timeSlotDistribution: const {'下午场': 0, '傍晚场': 0, '晚场': 0},
    );
  }

  int get _upcomingCount {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));
    return _performances.where((p) {
      if (p.status != 'bought') return false;
      final date = DateTime.tryParse(p.date);
      return date != null &&
          date.isAfter(now) &&
          date.isBefore(sevenDaysLater);
    }).length;
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
    fontSize: 10,
    fontFamily: 'monospace',
    color: ChartTheme.muted,
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
      _stats = ProfileStats.fromData(
        slice: _currentSlice,
        performances: performances,
        shows: shows,
        castMembers: castMembers,
      );
      _isLoading = false;
    });
  }

  void _recomputeStats() {
    setState(() {
      _stats = ProfileStats.fromData(
        slice: _currentSlice,
        performances: _performances,
        shows: _shows,
        castMembers: _castMembers,
      );
    });
  }

  void _navigateToCalendar(CalendarFilter filter, {DateTime? focusedDay}) {
    Navigator.push(
      context,
      SlideFadeRoute(
        page: CalendarScreen(
          initialFilter: filter,
          initialFocusedDay: focusedDay,
        ),
      ),
    );
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

  void _openSettings() {
    Navigator.push(
      context,
      SlideFadeRoute(page: const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildHeroMetrics()),
                SliverToBoxAdapter(child: _buildChartsSection()),
                SliverToBoxAdapter(child: _buildManagementSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
        children: [
          _buildTimeSliceFilterButton(),
          const Spacer(),
          GestureDetector(
            onTap: _openSettings,
            child: Row(
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ChartTheme.muted,
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withValues(alpha:0.2),
                  child: Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSliceFilterButton() {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ChartTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ChartTheme.grid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentSlice.label,
              style: const TextStyle(
                fontSize: 13,
                color: ChartTheme.label,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: ChartTheme.muted),
          ],
        ),
      ),
      onPressed: _isLoading ? null : _showTimeSliceMenu,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  void _showTimeSliceMenu() async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.topLeft(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<TimeSlice>(
      context: context,
      position: position,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: TimeSlice.values.map((slice) => _buildTimeSliceMenuItem(slice)).toList(),
    );

    if (result != null && result != _currentSlice) {
      setState(() => _currentSlice = result);
      _recomputeStats();
    }
  }

  PopupMenuItem<TimeSlice> _buildTimeSliceMenuItem(TimeSlice slice) {
    final isSelected = _currentSlice == slice;
    return PopupMenuItem(
      value: slice,
      child: Row(
        children: [
          Text(
            slice.label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.white : ChartTheme.label,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 16, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroMetrics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '已观演',
                  value: '${_stats.watchedSessions}',
                  onTap: () => _navigateToCalendar(CalendarFilter.watched),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: '已购买',
                  value: '${_stats.upcomingSessions}',
                  onTap: () => _navigateToCalendar(CalendarFilter.bought),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: '观演时长',
                  value: '${_stats.totalDurationHours.toStringAsFixed(1)}h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '花费',
                  value: '¥${_formatCurrency(_stats.totalPaid)}',
                  subtitle: '票面 ¥${_formatCurrency(_stats.faceValue)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: '关注剧目场次',
                  value: '${_stats.showsTracked}',
                  onTap: () => _navigateToCalendar(CalendarFilter.bought),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: '已买场次',
                  value: '$_upcomingCount',
                  accentColor: _upcomingCount > 0
                      ? ChartTheme.primary
                      : null,
                  onTap: () => _navigateToCalendar(CalendarFilter.bought),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stats.totalSessions == 0
              ? _buildEmptyChartPlaceholder(title: '月度观演节奏')
              : SimpleBarChart(
                  data: List.generate(
                    12,
                    (index) => ChartData(
                      label: '${index + 1}月',
                      value: _stats.monthlySessions[index],
                    ),
                  ),
                  title: '月度观演节奏',
                  activeColor: ChartTheme.primary,
                  highlightIndex: DateTime.now().month - 1,
                  onBarTap: (index) => _navigateToCalendar(
                    CalendarFilter.bought,
                    focusedDay: DateTime(DateTime.now().year, index + 1, 1),
                  ),
                ),
          const SizedBox(height: 16),
          _buildActorChart(),
          const SizedBox(height: 16),
          _stats.theaterDistribution.isEmpty
              ? _buildEmptyChartPlaceholder(title: '剧场分布')
              : HorizontalBarChart(
                  data: _stats.theaterDistribution
                      .map((e) => ChartData(label: e.key, value: e.value))
                      .toList(),
                  title: '剧场分布',
                  accentColor: ChartTheme.bought,
                  displayCount: 5,
                ),
          const SizedBox(height: 16),
          _stats.totalSessions == 0
              ? _buildEmptyChartPlaceholder(title: '时段偏好')
              : DonutChart(
                  data: _stats.timeSlotDistribution,
                  title: '时段偏好',
                  colors: const [
                    ChartTheme.watched,
                    ChartTheme.primary,
                    ChartTheme.bought,
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildActorChart() {
    if (_stats.actorRanking.isEmpty) {
      return _buildEmptyChartPlaceholder(title: '演员出场排名');
    }

    final actorData = _stats.actorRanking
        .map((e) => ChartData(label: e.key, value: e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.all(ChartTheme.cardPadding),
      decoration: BoxDecoration(
        color: ChartTheme.background,
        borderRadius: BorderRadius.circular(ChartTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '演员出场排名',
                style: TextStyle(
                  fontSize: ChartTheme.titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: ChartTheme.label,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isActorDonut = !_isActorDonut),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartTheme.grid.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isActorDonut ? Icons.bar_chart : Icons.donut_large,
                    size: 16,
                    color: ChartTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isActorDonut)
            _buildActorDonutChart(actorData)
          else
            HorizontalBarChart(
              data: actorData,
              accentColor: ChartTheme.watched,
              displayCount: 5,
            ),
        ],
      ),
    );
  }

  Widget _buildActorDonutChart(List<ChartData> data) {
    const topCount = 5;
    final topItems = data.take(topCount).toList();
    final othersCount = data.skip(topCount).fold(0, (sum, item) => sum + item.value);

    final Map<String, int> chartData = {
      for (final item in topItems) item.label: item.value,
    };
    if (othersCount > 0) {
      chartData['其他'] = othersCount;
    }

    return DonutChart(
      data: chartData,
      colors: const [
        ChartTheme.watched,
        ChartTheme.primary,
        ChartTheme.bought,
        Color(0xFF8A8F98),
        Color(0xFF6B5BCD),
        Color(0xFFD4A853),
      ],
    );
  }

  Widget _buildEmptyChartPlaceholder({required String title}) {
    return Container(
      padding: const EdgeInsets.all(ChartTheme.cardPadding),
      decoration: BoxDecoration(
        color: ChartTheme.background,
        borderRadius: BorderRadius.circular(ChartTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: ChartTheme.titleFontSize,
              fontWeight: FontWeight.w600,
              color: ChartTheme.label,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: ChartTheme.muted.withValues(alpha:0.4),
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  '暂无数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: ChartTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('管理', style: _monoLabel),
          const SizedBox(height: 12),
          _buildAssetTile(
            icon: Icons.theaters,
            label: '我的剧目',
            count: _shows.length,
            onTap: () => _showShowsSheet(),
          ),
          _buildAssetTile(
            icon: Icons.people,
            label: '演员名单',
            count: _actors.length,
            onTap: () => _showActorsSheet(),
          ),
          _buildAssetTile(
            icon: Icons.settings,
            label: '设置',
            subtitle: '账户、OCR、备份',
            onTap: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTile({
    required IconData icon,
    required String label,
    int? count,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary.withValues(alpha:0.8),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: ChartTheme.muted,
              ),
            )
          : Text(
              '$count 项',
              style: const TextStyle(
                fontSize: 12,
                color: ChartTheme.muted,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: ChartTheme.muted,
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
                    ? const Center(
                        child: Text(
                          '暂无剧目',
                          style: TextStyle(color: ChartTheme.muted),
                        ),
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '演员名单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _actors.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无演员',
                          style: TextStyle(color: ChartTheme.muted),
                        ),
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? accentColor;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    this.subtitle,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ChartTheme.background,
        borderRadius: BorderRadius.circular(ChartTheme.cardRadius),
        boxShadow: accentColor != null
            ? [
                BoxShadow(
                  color: accentColor!.withValues(alpha:0.12),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: ChartTheme.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                height: 1.1,
                color: ChartTheme.value,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: ChartTheme.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}
