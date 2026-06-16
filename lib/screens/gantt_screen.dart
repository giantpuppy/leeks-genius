import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../utils/page_transitions.dart';
import '../utils/status_colors.dart';
import '../models/actor.dart';
import '../widgets/status_badge.dart';
import '../widgets/warm_spotlight.dart';
import 'unified_show_detail_screen.dart';
import 'monthly_workbench_screen.dart';

enum PerformanceStatus { unmarked, wantToSee, bought }

extension PerformanceStatusExt on PerformanceStatus {
  String get value {
    switch (this) {
      case PerformanceStatus.unmarked:
        return 'unmarked';
      case PerformanceStatus.wantToSee:
        return 'want_to_see';
      case PerformanceStatus.bought:
        return 'bought';
    }
  }

  String get label {
    switch (this) {
      case PerformanceStatus.unmarked:
        return '未标记';
      case PerformanceStatus.wantToSee:
        return '想看';
      case PerformanceStatus.bought:
        return '已买';
    }
  }

  Color get color {
    switch (this) {
      case PerformanceStatus.unmarked:
        return const Color(0xFF9CA3AF);
      case PerformanceStatus.wantToSee:
        return const Color(0xFF811FE2);
      case PerformanceStatus.bought:
        return const Color(0xFF34D399);
    }
  }
}

PerformanceStatus statusFromString(String? s) {
  switch (s) {
    case 'want_to_see':
      return PerformanceStatus.wantToSee;
    case 'bought':
      return PerformanceStatus.bought;
    default:
      return PerformanceStatus.unmarked;
  }
}

/// 剧场流时间轴模式
enum TimelineMode { focus3Day, micro7Day }

class GanttScreen extends StatefulWidget {
  const GanttScreen({super.key});

  @override
  State<GanttScreen> createState() => GanttScreenState();
}

class GanttScreenState extends State<GanttScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _performances = [];
  Map<int, List<CastMember>> _castMap = {};
  bool _isLoading = true;

  TimelineMode _mode = TimelineMode.focus3Day;
  final ValueNotifier<TimelineMode> modeNotifier = ValueNotifier(TimelineMode.focus3Day);

  // 连续滚动
  late List<DateTime> _days;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isSnapping = false;
  Timer? _snapTimer;
  bool _isTransitioning = false; // 模式切换过渡中，封锁重复切换
  bool _justSwitched = false;     // 刚刚切换完，短暂封锁磁吸避免干扰

  // 动态行高：由 LayoutBuilder 实时更新
  double _availableHeight = 800.0; // 默认值，首次布局后更新

  // 左上角月份标题，随滚动实时更新
  final ValueNotifier<String> _monthTitle = ValueNotifier('');

  double get _focusRowHeight => _availableHeight / 3;
  double get _microRowHeight => _availableHeight / 7;
  double get _currentRowHeight => _mode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;

  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    modeNotifier.value = _mode;
    _initDays();
    _loadData();
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_updateMonthTitle);
  }

  void _updateMonthTitle() {
    if (!_scrollController.hasClients || _days.isEmpty) return;
    final idx = (_scrollController.offset / _currentRowHeight).floor().clamp(0, _days.length - 1);
    final d = _days[idx];
    _monthTitle.value = '${d.year}年${d.month}月';
  }

  /// 初始化日期列表：今天前30天 + 后60天
  void _initDays() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 30));
    _days = List.generate(91, (i) => DateTime(start.year, start.month, start.day + i));
  }

  /// 滚动到顶部/底部时追加更多天
  void _onScroll() {
    if (_isLoadingMore || _isSnapping || _isTransitioning) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _appendDays();
    } else if (_scrollController.position.pixels <= 200) {
      _prependDays();
    }
  }

  void _appendDays() {
    _isLoadingMore = true;
    final lastDay = _days.last;
    final newDays = List.generate(30, (i) => DateTime(lastDay.year, lastDay.month, lastDay.day + i + 1));
    setState(() => _days.addAll(newDays));
    _isLoadingMore = false;
  }

  void _prependDays() {
    _isLoadingMore = true;
    final firstDay = _days.first;
    final newDays = List.generate(30, (i) => DateTime(firstDay.year, firstDay.month, firstDay.day - 30 + i));
    final offsetBefore = _scrollController.offset;
    setState(() => _days.insertAll(0, newDays));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(offsetBefore + 30 * _currentRowHeight);
      _isLoadingMore = false;
    });
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final performances = await db.getAllPerformancesWithShow();
    final castMap = <int, List<CastMember>>{};
    for (final perf in performances) {
      final perfId = perf['id'] as int;
      final casts = await db.getCastMembersByPerformanceId(perfId);
      castMap[perfId] = casts;
    }
    if (mounted) {
      setState(() {
        _performances = performances;
        _castMap = castMap;
        _isLoading = false;
      });
      // 数据加载完成后，滚动到今天为第一个可见行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(30 * _currentRowHeight);
          _updateMonthTitle();
        }
      });
    }
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _monthTitle.dispose();
    modeNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 根据距离 today 的天数返回暗化透明度
  double _dimAlphaForDay(DateTime day, DateTime today) {
    final days = day.difference(today).inDays.abs();
    if (days == 0) return 0.0;
    if (days == 1) return 0.10;
    if (days <= 3) return 0.25;
    if (days <= 7) return 0.40;
    return 0.50;
  }

  /// 获取某天的所有演出（含 show 信息）
  List<Map<String, dynamic>> _getPerformancesForDay(DateTime day) {
    final dateStr = _fullDateFormat.format(day);
    return _performances.where((p) => p['date'] == dateStr).toList()
      ..sort((a, b) => ((a['time'] as String?) ?? '').compareTo((b['time'] as String?) ?? ''));
  }

  // ==================== 状态操作 ====================

  Future<void> _updateStatus(int perfId, String status) async {
    final db = DatabaseHelper.instance;
    final perf = await db.getPerformanceById(perfId);
    if (perf == null) return;
    await db.updatePerformance(perf.copyWith(status: status));
    _loadData();
  }

  Future<void> _showBoughtForm(int perfId) async {
    final seatController = TextEditingController();
    final priceController = TextEditingController();
    final actualPriceController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('补充购票信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: seatController,
              decoration: const InputDecoration(
                labelText: '座位',
                hintText: '如: 1楼-3排-5号',
                prefixIcon: Icon(Icons.event_seat_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '票面价格',
                hintText: '如: 580',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: actualPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '实付价格',
                hintText: '如: 480',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = DatabaseHelper.instance;
      final perf = await db.getPerformanceById(perfId);
      if (perf != null) {
        await db.updatePerformance(perf.copyWith(
          status: 'bought',
          seat: seatController.text.isNotEmpty ? seatController.text : null,
          price: priceController.text.isNotEmpty
              ? double.tryParse(priceController.text)
              : null,
          actualPrice: actualPriceController.text.isNotEmpty
              ? double.tryParse(actualPriceController.text)
              : null,
        ));
        _loadData();
      }
    } else if (result == false) {
      await _updateStatus(perfId, 'bought');
    }

    seatController.dispose();
    priceController.dispose();
    actualPriceController.dispose();
  }

  // ==================== 详情面板 ====================

  void _showPerformanceDetail(Map<String, dynamic> perf) async {
    final perfId = perf['id'] as int;
    final result = await Navigator.push(
      context,
      SlideFadeRoute(page: UnifiedShowDetailScreen(
        performanceId: perfId,
      )),
    );
    if (result == true) {
      _loadData();
    }
  }

  // ==================== 删除 ====================

  void _confirmDelete(Map<String, dynamic> perf) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              final db = DatabaseHelper.instance;
              await db.deletePerformance(perf['id'] as int);
              await db.deleteCastMembersByPerformanceId(perf['id'] as int);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: _buildMonthTitle(),
        actions: [
          // 管理台入口：直接跳转当前显示月份的海报网格
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: kBrandPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _openMonthlyWorkbenchFromCurrentTitle,
              icon: const Icon(Icons.grid_view, size: 22),
              color: Colors.white,
              tooltip: '管理台',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _performances.isEmpty
              ? _buildEmptyState()
              : _buildTimeline(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BreathingIcon(icon: Icons.view_timeline_outlined),
          const SizedBox(height: 16),
          const Text('暂无排期', style: TextStyle(fontSize: 18, color: Color(0xFF8A8F98))),
          const SizedBox(height: 8),
          const Text('点击右上角进入管理台', style: TextStyle(fontSize: 14, color: Color(0xFF7C7C7C))),
        ],
      ),
    );
  }

  // ==================== 动态月份标题 ====================

  void _openMonthlyWorkbench(int year, int month) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthlyWorkbenchScreen(year: year, month: month),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _openMonthlyWorkbenchFromCurrentTitle() {
    final title = _monthTitle.value;
    final parts = title.split('年');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1].replaceFirst('月', ''));
      if (year != null && month != null) {
        _openMonthlyWorkbench(year, month);
      }
    }
  }

  Widget _buildMonthTitle() {
    return ValueListenableBuilder<String>(
      valueListenable: _monthTitle,
      builder: (context, title, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                fontWeight: FontWeight.w600,
              ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.calendar_month,
                size: screenWidth * 0.045,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          );
      },
    );
  }

  // ==================== 剧场流时间轴 ====================

  Widget _buildTimeline() {
    final today = DateTime.now();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && !_isSnapping && !_isTransitioning && !_justSwitched) {
          _snapTimer?.cancel();
          _snapTimer = Timer(const Duration(milliseconds: 150), _snapToNearestRow);
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _availableHeight = constraints.maxHeight;
          return ListView.builder(
            key: ValueKey<TimelineMode>(_mode),
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: _days.length,
            itemBuilder: (context, index) {
              return _buildDayRow(index, today);
            },
          );
        },
      ),
    );
  }

  // ==================== 磁吸滚动 ====================

  void _snapToNearestRow() {
    if (!_scrollController.hasClients || _isTransitioning || _justSwitched) return;
    final offset = _scrollController.offset;
    final targetIndex = (offset / _currentRowHeight).round().clamp(0, _days.length - 1);
    final targetOffset = targetIndex * _currentRowHeight;

    if ((offset - targetOffset).abs() > 2) {
      _isSnapping = true;
      _scrollController
          .animateTo(targetOffset, duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
          .then((_) => _isSnapping = false);
    }
  }

  // ==================== 丝滑模式切换 ====================

  void _switchMode(TimelineMode newMode) {
    if (_mode == newMode || _isTransitioning) return;

    _snapTimer?.cancel();

    // 保存切换前的关键状态
    final previousOffset = _scrollController.offset;
    final previousMode = _mode;

    _isTransitioning = true;
    setState(() => _mode = newMode);
    modeNotifier.value = newMode;

    // 所有计算和滚动调整在布局完成后执行，确保使用最新的行高和 maxScrollExtent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // 在 post frame 中重新计算行高，确保 _availableHeight 已更新
        final oldRowHeight = previousMode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;
        final newRowHeight = _mode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;

        // 用 floor 更保守：确保视口顶部始终是同一个 item
        final firstVisibleIndex = (previousOffset / oldRowHeight).floor().clamp(0, _days.length - 1);
        final targetOffset = firstVisibleIndex * newRowHeight;

        _scrollController.jumpTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
      // jumpTo 后强制 rebuild，让 _buildMonthTitle 使用新的 offset 计算正确月份
      if (mounted) setState(() {});
      _isTransitioning = false;
      // 短暂标记刚刚切换完，阻止磁吸干扰 jumpTo 后的位置
      _justSwitched = true;
      Future.delayed(const Duration(milliseconds: 300), () => _justSwitched = false);
    });
  }

  /// 公开给底部导航的切换入口：当前聚焦3天则切到7天宏观，反之亦然。
  void toggleMode() {
    _switchMode(
      _mode == TimelineMode.focus3Day
          ? TimelineMode.micro7Day
          : TimelineMode.focus3Day,
    );
  }

  // ==================== 统一日期行（行高瞬间切换，避免 ListView 滚动冲突） ====================

  Widget _buildDayRow(int index, DateTime today) {
    final day = _days[index];
    final isToday = _isSameDay(day, today);
    final dayPerfs = _getPerformancesForDay(day);
    final isFocus = _mode == TimelineMode.focus3Day;
    final targetHeight = isFocus ? _focusRowHeight : _microRowHeight;
    final screenWidth = MediaQuery.of(context).size.width;
    final labelWidth = screenWidth * (isFocus ? 0.18 : 0.13);
    final dimAlpha = _dimAlphaForDay(day, today);

    // today 行外层包裹 WarmSpotlight（矩形，borderRadius 0）
    Widget rowContent = Container(
      height: targetHeight,
      decoration: BoxDecoration(
        color: isToday ? kBrandPurple.withValues(alpha: 0.04) : const Color(0xFF121212),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 左侧日期标签
          Container(
            width: labelWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: isToday
                  ? kBrandPurple.withValues(alpha: 0.08)
                  : const Color(0xFF1A1A1A),
              border: Border(
                right: BorderSide(
                  color: isToday
                      ? kBrandPurple.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.015,
              vertical: targetHeight * 0.035,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 大日期：聚焦模式显示 MM-DD，微观模式显示几号
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: isFocus ? 14 : 16,
                    fontWeight: isFocus ? FontWeight.w700 : FontWeight.w800,
                    color: isToday ? kBrandPurple : Colors.white.withValues(alpha: 0.9),
                  ),
                  child: Text(isFocus
                      ? '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}'
                      : '${day.day}'),
                ),
                SizedBox(height: targetHeight * 0.008),
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: isFocus ? 10 : 9,
                    fontWeight: FontWeight.w500,
                    color: isToday ? kBrandPurple.withValues(alpha: 0.8) : const Color(0xFF6B7280),
                  ),
                  child: Text(isFocus
                      ? ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day.weekday - 1]
                      : '周${['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1]}'),
                ),
                // 今天指示（淡紫色光点，无文字）
                Opacity(
                  opacity: isFocus ? 1.0 : 0.0,
                  child: _buildTodayBadge(day, isToday, screenWidth),
                ),
              ],
            ),
          ),
          // 右侧内容区
          Expanded(
            child: dayPerfs.isEmpty
                ? (isFocus
                    ? Center(
                        child: Text('无排期',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 12)),
                      )
                    : const SizedBox())
                : isFocus
                    ? _buildFocusContent(dayPerfs, targetHeight, labelWidth, screenWidth, isToday)
                    : _buildMicroContent(dayPerfs, targetHeight, screenWidth, isToday),
          ),
        ],
      ),
    );

    // 叠加远近明暗层（dimAlpha > 0 时）
    if (dimAlpha > 0) {
      rowContent = Stack(
        children: [
          rowContent,
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: dimAlpha),
            ),
          ),
        ],
      );
    }

    // today 行包裹 WarmSpotlight（矩形呼吸光晕）
    if (isToday) {
      rowContent = WarmSpotlight(
        borderRadius: 0,
        color: kBrandPurple,
        minAlpha: 0.08,
        maxAlpha: 0.16,
        minBlur: 8,
        maxBlur: 16,
        shouldAnimate: true,
        child: rowContent,
      );
    }

    // today 行侧边光（最左侧垂直渐变）
    if (isToday) {
      rowContent = Stack(
        children: [
          rowContent,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    kBrandPurple.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return rowContent;
  }

  Widget _buildTodayBadge(DateTime day, bool isToday, double screenWidth) {
    if (!isToday) return const SizedBox.shrink();
    // 今天：去掉文字，用淡紫色小光点/短横线标识
    return Padding(
      padding: EdgeInsets.only(top: screenWidth * 0.008),
      child: Container(
        width: screenWidth * 0.04,
        height: 3,
        decoration: BoxDecoration(
          color: kBrandPurple.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: kBrandPurple.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 聚焦模式内容（大海报卡片） ====================

  Widget _buildFocusContent(
    List<Map<String, dynamic>> dayPerfs,
    double rowHeight,
    double labelWidth,
    double screenWidth,
    bool isToday,
  ) {
    final cardWidth = (screenWidth - labelWidth) * 0.45;
    final cardHeight = rowHeight - rowHeight * 0.08;
    final cardSpacing = cardWidth * 0.04;
    final cardBorderRadius = cardHeight * 0.055;
    final horizontalPadding = screenWidth * 0.02;
    final verticalPadding = rowHeight * 0.035;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      itemCount: dayPerfs.length,
      itemBuilder: (context, index) => _buildFocusCard(
        dayPerfs[index],
        cardWidth,
        cardHeight,
        cardSpacing,
        cardBorderRadius,
        isToday,
      ),
    );
  }

  Widget _buildFocusCard(
    Map<String, dynamic> perf,
    double cardWidth,
    double cardHeight,
    double cardSpacing,
    double cardBorderRadius,
    bool isToday,
  ) {
    final showId = perf['show_id'] as int;
    final showName = perf['show_name'] as String? ?? '未知';
    final theater = perf['theater'] as String? ?? '';
    final time = (perf['time'] as String?)?.substring(0, 5) ?? '';
    final coverPath = perf['cover_path'] as String?;
    final color = coverColorForShow(showId);
    final perfId = perf['id'] as int;
    final status = perf['status'] as String? ?? 'unmarked';

    // 卡司：全部显示
    final allCasts = _castMap[perfId] ?? [];

    final hasCover = coverPath != null && coverPath.isNotEmpty;

    // 卡片容器：带彩色光晕 + 暗描边
    Widget card = Container(
      width: cardWidth,
      height: cardHeight,
      margin: EdgeInsets.only(right: cardSpacing),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          // 彩色光晕
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          // 底部投影，增加卡片与背景的分离感
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: 海报底图（无海报时用深色渐变）
            if (hasCover)
              Image.file(File(coverPath!), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, coverColorForShow(showId + 3)],
                    ),
                  ),
                ))
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, coverColorForShow(showId + 3)],
                  ),
                ),
              ),
            // Layer 2: 全屏蒙版（从 0.5 降到 0.28）
            Container(color: Colors.black.withValues(alpha: 0.28)),
            // Layer 2.5: 顶部加重渐变，确保文字在复杂海报上可读
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Layer 3: 信息
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: cardWidth * 0.05,
                  vertical: cardHeight * 0.04,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 时间 + 状态
                    Row(
                      children: [
                        if (time.isNotEmpty)
                          Text('🕒 $time',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 4, offset: const Offset(0, 1)),
                              ],
                            )),
                        const Spacer(),
                        if (status == 'want_to_see' || status == 'bought')
                          StatusBadge(
                            label: status == 'bought' ? '已买' : '想看',
                            color: statusColor(status),
                            fontSize: 10,
                            borderRadius: 10,
                          ),
                      ],
                    ),
                    // 卡司列表（视觉主体，上移）
                    if (allCasts.isNotEmpty) ...[
                      SizedBox(height: cardHeight * 0.02),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(),
                          itemCount: allCasts.length,
                          itemBuilder: (context, i) {
                            final c = allCasts[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(c.role,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 11,
                                        shadows: [
                                          Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 3),
                                        ],
                                      ),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text('|', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(c.actorName,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.92),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 3),
                                          ],
                                        ),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ] else
                      const Spacer(),
                    // 底部信息：无海报显示剧名，有海报只显示剧场
                    if (!hasCover && showName != '未知') ...[
                      Text(showName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 3)],
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (theater.isNotEmpty) SizedBox(height: cardHeight * 0.005),
                    ],
                    if (theater.isNotEmpty)
                      Text(theater,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 3)],
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            // today 卡片脚灯条：底部渐变条
            if (isToday)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: cardHeight * 0.04,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(cardBorderRadius),
                      bottomRight: Radius.circular(cardBorderRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        kWarmGold.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // today 卡片增加暖色 BoxShadow 呼吸效果
    if (isToday) {
      card = WarmSpotlight(
        borderRadius: cardBorderRadius,
        minAlpha: 0.08,
        maxAlpha: 0.16,
        minBlur: 8,
        maxBlur: 16,
        shouldAnimate: true,
        child: card,
      );
    }

    return GestureDetector(
      onTap: () => _showPerformanceDetail(perf),
      child: card,
    );
  }

  // ==================== 微观模式内容（邮票墙） ====================

  Widget _buildMicroContent(
    List<Map<String, dynamic>> dayPerfs,
    double rowHeight,
    double screenWidth,
    bool isToday,
  ) {
    final cardHeight = rowHeight - rowHeight * 0.08;
    final horizontalPadding = screenWidth * 0.015;
    final verticalPadding = rowHeight * 0.02;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      itemCount: dayPerfs.length,
      itemBuilder: (context, index) => _buildMicroCard(
        dayPerfs[index],
        cardHeight,
        screenWidth,
        isToday,
      ),
    );
  }

  Widget _buildMicroCard(
    Map<String, dynamic> perf,
    double cardHeight,
    double screenWidth,
    bool isToday,
  ) {
    final showId = perf['show_id'] as int;
    final time = (perf['time'] as String?)?.substring(0, 5) ?? '';
    final coverPath = perf['cover_path'] as String?;
    final color = coverColorForShow(showId);
    final cardWidth = cardHeight * 0.75; // 3:4 比例
    final cardSpacing = cardWidth * 0.04;
    final cardBorderRadius = cardHeight * 0.05;

    return GestureDetector(
      onTap: () => _showPerformanceDetail(perf),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: EdgeInsets.only(right: cardSpacing),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            // 微弱彩色光晕
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            // 底部投影
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              coverPath != null && coverPath.isNotEmpty
                  ? Image.file(File(coverPath), fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color, color.withValues(alpha: 0.6)],
                        ),
                      ),
                    ),
              // 黑色蒙版（从 0.35 降到 0.22）
              Container(
                alignment: Alignment.center,
                color: Colors.black.withValues(alpha: 0.22),
                child: Text(time,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 4),
                    ],
                  )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 剧目管理面板 ====================

enum _ShowFilter { all, wantToSee, bought, watched }

class _ShowManagementSheet extends StatefulWidget {
  final int showId;
  final String showName;
  final String? showTheater;
  final List<Performance> performances;
  final VoidCallback onDataChanged;
  final void Function(int showId) onQuickAdd;
  final void Function(Map<String, dynamic>) onEditPerformance;

  const _ShowManagementSheet({
    required this.showId,
    required this.showName,
    this.showTheater,
    required this.performances,
    required this.onDataChanged,
    required this.onQuickAdd,
    required this.onEditPerformance,
  });

  @override
  State<_ShowManagementSheet> createState() => _ShowManagementSheetState();
}

class _ShowManagementSheetState extends State<_ShowManagementSheet> {
  late String _showName;
  late String? _showTheater;
  bool _isEditing = false;
  _ShowFilter _filter = _ShowFilter.all;
  late List<Performance> _performances;

  final _nameController = TextEditingController();
  final _theaterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _showName = widget.showName;
    _showTheater = widget.showTheater;
    _performances = List.from(widget.performances);
    _nameController.text = _showName;
    _theaterController.text = _showTheater ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _theaterController.dispose();
    super.dispose();
  }

  bool _isWatched(Performance perf) {
    if (perf.status != 'bought') return false;
    final perfDate = DateTime.parse(perf.date);
    final today = DateTime.now();
    return perfDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  List<Performance> get _filteredPerformances {
    switch (_filter) {
      case _ShowFilter.all:
        return _performances;
      case _ShowFilter.wantToSee:
        return _performances.where((p) => p.status == 'want_to_see').toList();
      case _ShowFilter.bought:
        return _performances.where((p) => p.status == 'bought' && !_isWatched(p)).toList();
      case _ShowFilter.watched:
        return _performances.where((p) => _isWatched(p)).toList();
    }
  }

  Future<void> _saveShowInfo() async {
    final db = DatabaseHelper.instance;
    final show = await db.getShowById(widget.showId);
    if (show != null) {
      await db.updateShow(show.copyWith(
        name: _nameController.text.trim(),
        theater: _theaterController.text.trim().isEmpty ? null : _theaterController.text.trim(),
      ));
      setState(() {
        _showName = _nameController.text.trim();
        _showTheater = _theaterController.text.trim().isEmpty ? null : _theaterController.text.trim();
        _isEditing = false;
      });
      widget.onDataChanged();
    }
  }

  Future<void> _deleteShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除剧目'),
        content: Text('删除「$_showName」将同时删除其所有场次和卡司记录，确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      for (final perf in _performances) {
        if (perf.id != null) {
          await db.deleteCastMembersByPerformanceId(perf.id!);
          await db.deletePerformance(perf.id!);
        }
      }
      await db.deleteShow(widget.showId);
      widget.onDataChanged();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleStatus(Performance perf) async {
    final next = perf.status == 'bought'
        ? 'unmarked'
        : perf.status == 'want_to_see'
            ? 'bought'
            : 'want_to_see';
    await DatabaseHelper.instance.updatePerformance(perf.copyWith(status: next));
    setState(() {
      _performances = _performances.map((p) {
        if (p.id == perf.id) return p.copyWith(status: next);
        return p;
      }).toList();
    });
    widget.onDataChanged();
  }

  Future<void> _deletePerformance(int perfId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后不可恢复，确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteCastMembersByPerformanceId(perfId);
      await DatabaseHelper.instance.deletePerformance(perfId);
      setState(() {
        _performances.removeWhere((p) => p.id == perfId);
      });
      widget.onDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // 顶部拖拽条
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2))),
          ),
          // 剧目信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isEditing ? _buildEditForm() : _buildShowInfo(),
          ),
          const SizedBox(height: 12),
          // 筛选栏
          _buildFilterBar(),
          const SizedBox(height: 8),
          // 分隔线
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.06)),
          // 场次列表
          Expanded(
            child: _filteredPerformances.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy, size: 40, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 12),
                        Text(_filter == _ShowFilter.all ? '暂无排期' : '暂无符合条件的排期',
                            style: const TextStyle(color: Color(0xFF8A8F98), fontSize: 14)),
                      ],
                    ),
                  ))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredPerformances.length,
                    itemBuilder: (context, index) => _buildPerfItem(_filteredPerformances[index]),
                  ),
          ),
          // 底部删除按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteShow,
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                label: Text('删除剧目', style: TextStyle(color: Colors.red[300])),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[300],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfItem(Performance perf) {
    final isWatched = _isWatched(perf);
    final status = statusFromString(perf.status);
    final displayLabel = isWatched ? '已观演' : status.label;
    final displayColor = isWatched ? const Color(0xFF9CA3AF) : status.color;
    final displayIcon = isWatched
        ? Icons.visibility
        : (perf.status == 'bought' ? Icons.check_circle : perf.status == 'want_to_see' ? Icons.star : Icons.circle_outlined);
    final timeStr = perf.time?.substring(0, 5) ?? '';

    return GestureDetector(
      onTap: () => widget.onEditPerformance(perf.toMap()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // 状态图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(displayIcon, size: 18, color: displayColor),
            ),
            const SizedBox(width: 12),
            // 日期时间 + 座位
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(perf.date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(timeStr, style: TextStyle(fontSize: 14, color: displayColor, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                  if (perf.seat != null && perf.seat!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('座位: ${perf.seat}', style: const TextStyle(fontSize: 12, color: Color(0xFF8A8F98))),
                  ],
                ],
              ),
            ),
            // 状态标签
            _StatusBadge(label: displayLabel, color: displayColor, onTap: () => _toggleStatus(perf)),
            const SizedBox(width: 4),
            // 删除
            GestureDetector(
              onTap: () => _deletePerformance(perf.id!),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_showName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_showTheater != null && _showTheater!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF8A8F98)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(_showTheater!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF8A8F98)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // 编辑按钮
        GestureDetector(
          onTap: () => setState(() => _isEditing = true),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF8A8F98)),
          ),
        ),
        const SizedBox(width: 8),
        // 添加场次按钮
        GestureDetector(
          onTap: () => widget.onQuickAdd(widget.showId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B5BCD).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: Color(0xFF6B5BCD)),
                SizedBox(width: 4),
                Text('添加', style: TextStyle(fontSize: 13, color: Color(0xFF6B5BCD), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: '剧目名称', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)), style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 10),
        TextField(controller: _theaterController, decoration: const InputDecoration(labelText: '演出地点', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)), style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _isEditing = false), child: const Text('取消'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: _saveShowInfo, child: const Text('保存'))),
        ]),
      ],
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      (_ShowFilter.all, '全部', null),
      (_ShowFilter.wantToSee, '想看', const Color(0xFF811FE2)),
      (_ShowFilter.bought, '已买', const Color(0xFF34D399)),
      (_ShowFilter.watched, '已观演', const Color(0xFF9CA3AF)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final isActive = _filter == f.$1;
          final color = f.$3 ?? const Color(0xFF6B5BCD);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? color.withValues(alpha: 0.4) : const Color(0xFF2A2A2A),
                    width: 1,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: isActive ? color : const Color(0xFF8A8F98),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==================== 状态标签组件 ====================

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _StatusBadge({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ==================== 编辑场次 Sheet ====================

class _EditPerformanceSheet extends StatefulWidget {
  final Map<String, dynamic> perf;
  final List<CastMember> existingCasts;
  final VoidCallback onSaved;

  const _EditPerformanceSheet({required this.perf, required this.existingCasts, required this.onSaved});

  @override
  State<_EditPerformanceSheet> createState() => _EditPerformanceSheetState();
}

class _EditCastRow {
  TextEditingController roleController;
  TextEditingController actorController;
  bool isFeatured;

  _EditCastRow({String? role, String? actor, bool? featured})
      : roleController = TextEditingController(text: role ?? ''),
        actorController = TextEditingController(text: actor ?? ''),
        isFeatured = featured ?? false;

  void dispose() {
    roleController.dispose();
    actorController.dispose();
  }
}

class _EditPerformanceSheetState extends State<_EditPerformanceSheet> {
  late String _date;
  late String _time;
  final List<_EditCastRow> _castRows = [];
  bool _isSaving = false;
  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _date = widget.perf['date'] as String;
    _time = widget.perf['time'] as String? ?? '19:30';
    for (final c in widget.existingCasts) {
      _castRows.add(_EditCastRow(role: c.role, actor: c.actorName, featured: c.isFeatured));
    }
    if (_castRows.isEmpty) _castRows.add(_EditCastRow());
  }

  @override
  void dispose() {
    for (final r in _castRows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) setState(() => _date = _fullDateFormat.format(picked));
  }

  Future<void> _pickTime() async {
    const presets = ['14:00', '14:30', '19:00', '19:30'];
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4D4D4D), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('选择开场时间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  ...presets.map((t) => ActionChip(label: Text(t), onPressed: () => Navigator.pop(context, t))),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: const Text('自定义'),
                    onPressed: () async {
                      final parts = _time.split(':');
                      final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                      if (picked != null && context.mounted) {
                        Navigator.pop(context, '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (result != null) setState(() => _time = result);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper.instance;
      final perfId = widget.perf['id'] as int;
      final performance = await db.getPerformanceById(perfId);
      if (performance != null) {
        await db.updatePerformance(performance.copyWith(date: _date, time: _time));
      }
      await db.deleteCastMembersByPerformanceId(perfId);
      for (final row in _castRows) {
        final role = row.roleController.text.trim();
        final actor = row.actorController.text.trim();
        if (role.isNotEmpty && actor.isNotEmpty) {
          await db.createCastMember(CastMember(performanceId: perfId, role: role, actorName: actor, isFeatured: row.isFeatured, createdAt: DateTime.now().toIso8601String()));
          try { await db.createActor(Actor(name: actor, createdAt: DateTime.now().toIso8601String())); } catch (_) {}
        }
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4D4D4D), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('编辑场次', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: '日期', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)), child: Text(_date, style: const TextStyle(fontSize: 15))))),
                const SizedBox(width: 12),
                Expanded(child: InkWell(onTap: _pickTime, child: InputDecorator(decoration: const InputDecoration(labelText: '时间', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)), child: Text(_time, style: const TextStyle(fontSize: 15))))),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Text('卡司', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(onPressed: () => setState(() => _castRows.add(_EditCastRow())), icon: const Icon(Icons.add, size: 18), label: const Text('添加角色')),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _castRows.length,
                  itemBuilder: (context, index) {
                    final row = _castRows[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(flex: 2, child: TextField(controller: row.roleController, decoration: const InputDecoration(labelText: '角色', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: TextField(controller: row.actorController, decoration: const InputDecoration(labelText: '演员', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
                          const SizedBox(width: 8),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Checkbox(value: row.isFeatured, onChanged: (v) => setState(() => row.isFeatured = v ?? false)),
                            GestureDetector(onTap: () => setState(() => row.isFeatured = !row.isFeatured), child: const Text('★', style: TextStyle(fontSize: 14, color: Color(0xFF811FE2)))),
                          ]),
                          if (_castRows.length > 1)
                            IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]), onPressed: () => setState(() { row.dispose(); _castRows.removeAt(index); })),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('取消'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _isSaving ? null : _save, child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('保存'))),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _BreathingIcon extends StatefulWidget {
  final IconData icon;
  const _BreathingIcon({required this.icon});

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 4).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(offset: Offset(0, -_animation.value), child: child),
      child: Icon(widget.icon, size: 72, color: const Color(0xFF4D4D4D)),
    );
  }
}
