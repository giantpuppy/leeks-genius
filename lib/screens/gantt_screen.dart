import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/performance.dart';
import 'add_show_screen.dart';

enum ViewMode { day, week, month }

class GanttScreen extends StatefulWidget {
  const GanttScreen({super.key});

  @override
  State<GanttScreen> createState() => _GanttScreenState();
}

class _GanttScreenState extends State<GanttScreen> {
  List<Map<String, dynamic>> _performances = [];
  bool _isLoading = true;

  ViewMode _viewMode = ViewMode.week;

  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  final ScrollController _hScrollController = ScrollController();

  static const double _rowHeight = 56;
  static const double _headerHeight = 44;
  static const double _leftPanelWidth = 200;

  double get _cellWidth {
    switch (_viewMode) {
      case ViewMode.day:
        return 72;
      case ViewMode.week:
        return 48;
      case ViewMode.month:
        return 32;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final performances = await db.getAllPerformancesWithShow();
    setState(() {
      _performances = performances;
      _isLoading = false;
    });
  }

  DateTimeRange _getDisplayRange() {
    if (_performances.isEmpty) {
      final today = DateTime.now();
      return DateTimeRange(
        start: today.subtract(const Duration(days: 7)),
        end: today.add(const Duration(days: 60)),
      );
    }

    final dates = _performances
        .map((p) => DateTime.parse(p['date'] as String))
        .toList();
    dates.sort();

    final minDate = dates.first;
    final maxDate = dates.last;
    final today = DateTime.now();

    final startBuffer = Duration(days: _viewMode == ViewMode.month ? 14 : 7);
    var start = minDate.isBefore(today.subtract(startBuffer))
        ? minDate
        : today.subtract(startBuffer);

    final endBuffer = Duration(days: _viewMode == ViewMode.month ? 120 : 45);
    var end = maxDate.isAfter(today.add(endBuffer))
        ? maxDate
        : today.add(endBuffer);

    if (_viewMode == ViewMode.month) {
      start = DateTime(start.year, start.month, 1);
      end = DateTime(end.year, end.month + 1, 0);
    }

    return DateTimeRange(start: start, end: end);
  }

  double _getTodayOffset(DateTime startDate) {
    final today = DateTime.now();
    final daysDiff = DateTime(today.year, today.month, today.day)
        .difference(
            DateTime(startDate.year, startDate.month, startDate.day))
        .inDays;
    return daysDiff * _cellWidth;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scrollToToday() {
    final range = _getDisplayRange();
    final offset = _getTodayOffset(range.start);
    final screenWidth = MediaQuery.of(context).size.width - _leftPanelWidth;
    _hScrollController.animateTo(
      (offset - screenWidth / 2).clamp(
        0.0,
        _hScrollController.hasClients
            ? _hScrollController.position.maxScrollExtent
            : double.infinity,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Color _getShowColor(int showId) {
    final colors = [
      const Color(0xFF3370FF),
      const Color(0xFF34D399),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
      const Color(0xFFF97316),
    ];
    return colors[showId.abs() % colors.length];
  }

  void _showPerformanceDetail(Map<String, dynamic> perf) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildDetailSheet(perf),
    );
  }

  Widget _buildDetailSheet(Map<String, dynamic> perf) {
    final showName = perf['show_name'] as String? ?? '未知';
    final theater = perf['theater'] as String? ?? '';
    final date = perf['date'] as String? ?? '';
    final time = perf['time'] as String? ?? '';
    final seat = perf['seat'] as String? ?? '';
    final price = perf['price'] != null ? '¥${perf['price']}' : '';

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      Navigator.pop(context);
                      _editPerformance(perf);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                    onPressed: () => _confirmDelete(perf),
                  ),
                ],
              ),
              if (theater.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(theater,
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildInfoItem(Icons.calendar_today, '日期', date),
                    _buildInfoItem(Icons.access_time, '时间',
                        time.isNotEmpty ? time : '未设置'),
                    if (seat.isNotEmpty)
                      _buildInfoItem(Icons.event_seat, '座位', seat),
                    if (price.isNotEmpty)
                      _buildInfoItem(Icons.attach_money, '票价', price),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _editPerformance(Map<String, dynamic> perf) async {
    final currentDate = DateTime.parse(perf['date'] as String);
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );
    if (newDate == null) return;

    TimeOfDay? newTime;
    if (perf['time'] != null && (perf['time'] as String).isNotEmpty) {
      final parts = (perf['time'] as String).split(':');
      newTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      );
    } else {
      newTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 19, minute: 30),
      );
    }

    final db = DatabaseHelper.instance;
    final performance = Performance(
      id: perf['id'] as int,
      showId: perf['show_id'] as int,
      date: _fullDateFormat.format(newDate),
      time: newTime != null
          ? '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}'
          : perf['time'] as String?,
      seat: perf['seat'] as String?,
      price: perf['price'] != null ? (perf['price'] as num).toDouble() : null,
      createdAt: perf['created_at'] as String? ??
          DateTime.now().toIso8601String(),
    );
    await db.updatePerformance(performance);
    _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新成功')),
      );
    }
  }

  void _confirmDelete(Map<String, dynamic> perf) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              final db = DatabaseHelper.instance;
              await db.deletePerformance(perf['id'] as int);
              await db.deleteCastMembersByPerformanceId(perf['id'] as int);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _quickAddPerformance(int showId) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );
    if (date == null) return;

    final db = DatabaseHelper.instance;
    await db.createPerformance(Performance(
      showId: showId,
      date: _fullDateFormat.format(date),
      time: '19:30',
      createdAt: DateTime.now().toIso8601String(),
    ));

    _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('场次添加成功')),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排期甘特图'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _performances.isEmpty
              ? _buildEmptyState()
              : _buildGanttChart(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.view_timeline_outlined,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('暂无排期',
              style: TextStyle(fontSize: 18, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('点击右下角添加剧目',
              style: TextStyle(fontSize: 14, color: Colors.grey[350])),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddShowScreen()),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.add),
            label: const Text('添加剧目'),
          ),
        ],
      ),
    );
  }

  Widget _buildGanttChart() {
    final range = _getDisplayRange();
    final totalDays = range.end.difference(range.start).inDays + 1;
    final todayOffset = _getTodayOffset(range.start);

    final showGroups = <int, List<Map<String, dynamic>>>{};
    for (final perf in _performances) {
      final showId = perf['show_id'] as int;
      showGroups.putIfAbsent(showId, () => []);
      showGroups[showId]!.add(perf);
    }

    final contentHeight = showGroups.length * _rowHeight;

    return Column(
      children: [
        _buildToolbar(),
        // 表头
        Container(
          height: _headerHeight,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            color: const Color(0xFFF5F6F7),
          ),
          child: Row(
            children: [
              Container(
                width: _leftPanelWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: const Text(
                  '剧目 / 剧场',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1F2329)),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _hScrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: totalDays * _cellWidth,
                    child: Row(
                      children: List.generate(totalDays, (index) {
                        final date = range.start.add(Duration(days: index));
                        final isToday = _isSameDay(date, DateTime.now());
                        final isWeekend = date.weekday >= 6;

                        return Container(
                          width: _cellWidth,
                          height: _headerHeight,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey[200]!),
                            ),
                            color: isToday
                                ? const Color(0xFFFFF0F0)
                                : (isWeekend
                                    ? const Color(0xFFF5F6F7)
                                    : null),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${date.month}/${date.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isToday
                                      ? const Color(0xFFF54A45)
                                      : (isWeekend
                                          ? Colors.grey[500]
                                          : const Color(0xFF1F2329)),
                                ),
                              ),
                              Text(
                                ['一', '二', '三', '四', '五', '六', '日']
                                    [date.weekday - 1],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isToday
                                      ? const Color(0xFFF54A45)
                                          .withOpacity(0.7)
                                      : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 数据区域
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧列表
                Container(
                  width: _leftPanelWidth,
                  decoration: BoxDecoration(
                    border:
                        Border(right: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Column(
                    children: showGroups.entries.map((entry) {
                      final showId = entry.key;
                      final perfs = entry.value;
                      final showName =
                          perfs.first['show_name'] as String? ?? '未知';
                      final showTheater =
                          perfs.first['theater'] as String? ?? '';
                      final color = _getShowColor(showId);

                      return Container(
                        height: _rowHeight,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: Colors.grey[100]!)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    showName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1F2329),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (showTheater.isNotEmpty)
                                    Text(
                                      showTheater,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _quickAddPerformance(showId),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.add_circle_outline,
                                    size: 18,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // 右侧时间轴
                Expanded(
                  child: SizedBox(
                    height: contentHeight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hScrollController,
                      child: SizedBox(
                        width: totalDays * _cellWidth,
                        child: Stack(
                          children: [
                            // 背景格子和甘特条行
                            Column(
                              children:
                                  showGroups.entries.map((entry) {
                                final showId = entry.key;
                                final perfs = entry.value;
                                final color = _getShowColor(showId);

                                return Container(
                                  height: _rowHeight,
                                  decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey[100]!)),
                                  ),
                                  child: Stack(
                                    children: [
                                      // 背景格子
                                      Row(
                                        children: List.generate(
                                            totalDays, (index) {
                                          final date = range.start
                                              .add(Duration(days: index));
                                          final isToday = _isSameDay(
                                              date, DateTime.now());
                                          final isWeekend =
                                              date.weekday >= 6;

                                          return Container(
                                            width: _cellWidth,
                                            height: _rowHeight,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: BorderSide(
                                                    color: Colors
                                                        .grey[100]!),
                                              ),
                                              color: isToday
                                                  ? const Color(
                                                          0xFFFFF0F0)
                                                      .withOpacity(0.4)
                                                  : (isWeekend
                                                      ? const Color(
                                                              0xFFFAFAFA)
                                                      : null),
                                            ),
                                          );
                                        }),
                                      ),
                                      // 甘特条
                                      ...perfs.map((perf) {
                                        final perfDate = DateTime.parse(
                                            perf['date'] as String);
                                        final dayIndex = DateTime(
                                                perfDate.year,
                                                perfDate.month,
                                                perfDate.day)
                                            .difference(DateTime(
                                                range.start.year,
                                                range.start.month,
                                                range.start.day))
                                            .inDays;

                                        if (dayIndex < 0 ||
                                            dayIndex >= totalDays) {
                                          return const SizedBox.shrink();
                                        }

                                        return Positioned(
                                          left: dayIndex * _cellWidth +
                                              (_cellWidth > 40 ? 6 : 2),
                                          top: 12,
                                          child: GestureDetector(
                                            onTap: () =>
                                                _showPerformanceDetail(
                                                    perf),
                                            child: Container(
                                              width: _cellWidth -
                                                  (_cellWidth > 40
                                                      ? 12
                                                      : 4),
                                              height: _rowHeight - 24,
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        4),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: color
                                                        .withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(
                                                        0, 1),
                                                  ),
                                                ],
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                (perf['time']
                                                            as String?)
                                                        ?.substring(
                                                            0,
                                                            perf['time']!
                                                                        .length >=
                                                                    5
                                                                ? 5
                                                                : perf['time']!
                                                                    .length) ??
                                                    '',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            // 今天线
                            if (todayOffset >= 0 &&
                                todayOffset <=
                                    totalDays * _cellWidth)
                              Positioned(
                                left: todayOffset,
                                top: 0,
                                bottom: 0,
                                child: Column(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF54A45),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                      child: const Text(
                                        '今天',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: const Color(0xFFF54A45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _scrollToToday,
            icon: const Icon(Icons.today, size: 16),
            label: const Text('今天'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<ViewMode>(
            segments: const [
              ButtonSegment(value: ViewMode.day, label: Text('日')),
              ButtonSegment(value: ViewMode.week, label: Text('周')),
              ButtonSegment(value: ViewMode.month, label: Text('月')),
            ],
            selected: {_viewMode},
            onSelectionChanged: (set) {
              setState(() => _viewMode = set.first);
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddShowScreen()),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加剧目'),
          ),
        ],
      ),
    );
  }
}
