import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';
import 'add_show_screen.dart';

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

class GanttScreen extends StatefulWidget {
  const GanttScreen({super.key});

  @override
  State<GanttScreen> createState() => _GanttScreenState();
}

class _GanttScreenState extends State<GanttScreen> {
  List<Map<String, dynamic>> _performances = [];
  Map<int, List<CastMember>> _castMap = {};
  bool _isLoading = true;

  DateTime _weekStart = _getWeekStart(DateTime.now());

  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  static const double _layerHeight = 64;
  static const double _layerGap = 3;
  static const double _rowPadding = 8;
  static const double _headerHeight = 48;
  static const double _leftPanelWidth = 90;

  static DateTime _getWeekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
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
    setState(() {
      _performances = performances;
      _castMap = castMap;
      _isLoading = false;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _prevWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      _weekStart = _getWeekStart(DateTime.now());
    });
  }

  int _getLayers(int showId, List<Map<String, dynamic>> perfs) {
    final dayCounts = <String, int>{};
    for (final p in perfs) {
      if (p['show_id'] != showId) continue;
      final date = p['date'] as String;
      dayCounts[date] = (dayCounts[date] ?? 0) + 1;
    }
    if (dayCounts.isEmpty) return 1;
    return dayCounts.values.reduce((a, b) => a > b ? a : b);
  }

  double _getRowHeight(int layers) {
    return _rowPadding +
        layers * _layerHeight +
        (layers - 1) * _layerGap +
        _rowPadding;
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
                hintText: '如: 1排1座',
                prefixIcon: Icon(Icons.event_seat_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '票价',
                hintText: '如: 180',
                prefixIcon: Icon(Icons.attach_money),
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
        ));
        _loadData();
      }
    } else if (result == false) {
      await _updateStatus(perfId, 'bought');
    }

    seatController.dispose();
    priceController.dispose();
  }

  // ==================== 详情面板 ====================

  void _showPerformanceDetail(Map<String, dynamic> perf) {
    final status = statusFromString(perf['status'] as String?);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildDetailSheet(perf, status),
    );
  }

  Widget _buildDetailSheet(Map<String, dynamic> perf, PerformanceStatus status) {
    final showName = perf['show_name'] as String? ?? '未知';
    final theater = perf['theater'] as String? ?? '';
    final date = perf['date'] as String? ?? '';
    final time = perf['time'] as String? ?? '';
    final seat = perf['seat'] as String? ?? '';
    final price = perf['price'] != null ? '¥${perf['price']}' : '';
    final perfId = perf['id'] as int;
    final casts = _castMap[perfId] ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.8,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: status.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
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
              const SizedBox(height: 16),
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
              if (casts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('卡司',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: casts.map((c) {
                    final isFeatured = c.isFeatured == true;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isFeatured
                            ? const Color(0xFF811FE2).withValues(alpha: 0.08)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: isFeatured
                            ? Border.all(
                                color: const Color(0xFF811FE2)
                                    .withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Text(
                        '${c.role}: ${c.actorName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isFeatured
                              ? const Color(0xFF811FE2)
                              : Colors.grey[700],
                          fontWeight:
                              isFeatured ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Text('标记状态',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusButton(
                    label: '想看',
                    icon: Icons.star_border,
                    color: PerformanceStatus.wantToSee.color,
                    isActive: status == PerformanceStatus.wantToSee,
                    onTap: () async {
                      Navigator.pop(context);
                      await _updateStatus(perfId, 'want_to_see');
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildStatusButton(
                    label: '已买',
                    icon: Icons.check_circle_outline,
                    color: PerformanceStatus.bought.color,
                    isActive: status == PerformanceStatus.bought,
                    onTap: () async {
                      Navigator.pop(context);
                      await _showBoughtForm(perfId);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildStatusButton(
                    label: '取消',
                    icon: Icons.remove_circle_outline,
                    color: PerformanceStatus.unmarked.color,
                    isActive: status == PerformanceStatus.unmarked,
                    onTap: () async {
                      Navigator.pop(context);
                      await _updateStatus(perfId, 'unmarked');
                    },
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editPerformance(perf);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('编辑'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(perf),
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: Colors.red[400]),
                      label: Text('删除',
                          style: TextStyle(color: Colors.red[400])),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color : Colors.grey[300]!,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isActive ? color : Colors.grey[400], size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? color : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
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

  // ==================== 编辑 / 删除 / 添加 ====================

  void _editPerformance(Map<String, dynamic> perf) async {
    final db = DatabaseHelper.instance;
    final perfId = perf['id'] as int;
    final existingCasts = await db.getCastMembersByPerformanceId(perfId);

    // ignore: use_build_context_synchronously
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return _EditPerformanceSheet(
          perf: perf,
          existingCasts: existingCasts,
          onSaved: () {
            _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更新成功')),
              );
            }
          },
        );
      },
    );
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

  Future<String?> _pickTimeQuick(BuildContext context,
      {String? initial}) async {
    const presets = ['14:00', '14:30', '19:00', '19:30'];
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('选择开场时间',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...presets.map((t) => ActionChip(
                        label: Text(t),
                        onPressed: () => Navigator.pop(context, t),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: const Text('自定义'),
                    onPressed: () async {
                      final parts = (initial ?? '19:30').split(':');
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        ),
                      );
                      if (picked != null && context.mounted) {
                        Navigator.pop(
                          context,
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                        );
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

    final time = await _pickTimeQuick(context);
    if (time == null) return;

    final db = DatabaseHelper.instance;
    await db.createPerformance(Performance(
      showId: showId,
      date: _fullDateFormat.format(date),
      time: time,
      status: 'unmarked',
      createdAt: DateTime.now().toIso8601String(),
    ));

    _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('场次添加成功')),
      );
    }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - _leftPanelWidth) / 7;
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final today = DateTime.now();
    final isCurrentWeek = _isSameDay(_getWeekStart(today), _weekStart);

    // 按剧目分组
    final showGroups = <int, List<Map<String, dynamic>>>{};
    for (final perf in _performances) {
      final showId = perf['show_id'] as int;
      showGroups.putIfAbsent(showId, () => []);
      showGroups[showId]!.add(perf);
    }

    // 计算每行高度
    final rowHeights = <int, double>{};
    double totalHeight = 0;
    for (final entry in showGroups.entries) {
      final layers = _getLayers(entry.key, entry.value);
      final h = _getRowHeight(layers);
      rowHeights[entry.key] = h;
      totalHeight += h;
    }

    return Column(
      children: [
        _buildToolbar(cellWidth, weekEnd),
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
                  '剧目',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1F2329)),
                ),
              ),
              Expanded(
                child: Row(
                  children: List.generate(7, (index) {
                    final date = _weekStart.add(Duration(days: index));
                    final isToday = _isSameDay(date, today);
                    final isWeekend = date.weekday >= 6;

                    return Container(
                      width: cellWidth,
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
                              fontSize: 12,
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
                                      .withValues(alpha: 0.7)
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        // 数据区域
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! > 200) {
                  _prevWeek();
                } else if (details.primaryVelocity! < -200) {
                  _nextWeek();
                }
              }
            },
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
                        final h = rowHeights[showId] ?? _getRowHeight(1);

                        return Container(
                          height: h,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey[100]!)),
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
                                  onTap: () =>
                                      _quickAddPerformance(showId),
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
                      height: totalHeight,
                      child: Stack(
                        children: [
                          // 背景格子和甘特条
                          Column(
                            children: showGroups.entries.map((entry) {
                              final showId = entry.key;
                              final perfs = entry.value;
                              final layers = _getLayers(showId, perfs);
                              final rowH = rowHeights[showId] ?? _getRowHeight(1);

                              // 按 dayIndex 分组
                              final dayGroups = <int, List<Map<String, dynamic>>>{};
                              for (final p in perfs) {
                                final d = DateTime.parse(p['date'] as String);
                                final idx = DateTime(d.year, d.month, d.day)
                                    .difference(DateTime(
                                        _weekStart.year,
                                        _weekStart.month,
                                        _weekStart.day))
                                    .inDays;
                                if (idx < 0 || idx >= 7) continue;
                                dayGroups.putIfAbsent(idx, () => []);
                                dayGroups[idx]!.add(p);
                              }

                              // 排序每个日期的场次
                              for (final list in dayGroups.values) {
                                list.sort((a, b) {
                                  final ta = (a['time'] as String?) ?? '';
                                  final tb = (b['time'] as String?) ?? '';
                                  return ta.compareTo(tb);
                                });
                              }

                              return Container(
                                height: rowH,
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey[100]!)),
                                ),
                                child: Stack(
                                  children: [
                                    // 背景格子
                                    Row(
                                      children: List.generate(7, (index) {
                                        final date = _weekStart
                                            .add(Duration(days: index));
                                        final isToday = _isSameDay(
                                            date, DateTime.now());
                                        final isWeekend =
                                            date.weekday >= 6;

                                        return Container(
                                          width: cellWidth,
                                          height: rowH,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: BorderSide(
                                                  color: Colors
                                                      .grey[100]!),
                                            ),
                                            color: isToday
                                                ? const Color(
                                                        0xFFFFF0F0)
                                                    .withValues(
                                                        alpha: 0.4)
                                                : (isWeekend
                                                    ? const Color(
                                                            0xFFFAFAFA)
                                                    : null),
                                          ),
                                        );
                                      }),
                                    ),
                                    // 甘特条（按层渲染）
                                    ...dayGroups.entries.expand((dayEntry) {
                                      final dayIndex = dayEntry.key;
                                      final dayPerfs = dayEntry.value;
                                      final barColor = _getShowColor(showId);

                                      return dayPerfs
                                          .asMap()
                                          .entries
                                          .map((perfEntry) {
                                        final layer = perfEntry.key;
                                        final perf = perfEntry.value;
                                        final status = statusFromString(
                                            perf['status'] as String?);
                                        final isUnmarked = status ==
                                            PerformanceStatus.unmarked;
                                        final statusColor = isUnmarked
                                            ? const Color(0xFF9CA3AF)
                                            : (status ==
                                                    PerformanceStatus
                                                        .wantToSee
                                                ? const Color(
                                                    0xFF811FE2)
                                                : const Color(
                                                    0xFF34D399));

                                        final top = _rowPadding +
                                            layer *
                                                (_layerHeight +
                                                    _layerGap);
                                        final perfId = perf['id'] as int;
                                        final featuredCasts =
                                            (_castMap[perfId] ?? [])
                                                .where((c) =>
                                                    c.isFeatured == true)
                                                .take(2)
                                                .toList();

                                        return Positioned(
                                          left: dayIndex * cellWidth +
                                              2,
                                          top: top,
                                          child: GestureDetector(
                                            onTap: () =>
                                                _showPerformanceDetail(
                                                    perf),
                                            child: Container(
                                              width: cellWidth - 4,
                                              height: _layerHeight,
                                              decoration: BoxDecoration(
                                                color: isUnmarked
                                                    ? statusColor
                                                        .withValues(
                                                            alpha: 0.25)
                                                    : statusColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        4),
                                                border: Border.all(
                                                  color: isUnmarked
                                                      ? statusColor
                                                          .withValues(
                                                              alpha: 0.4)
                                                      : statusColor
                                                          .withValues(
                                                              alpha: 0.8),
                                                  width: 0.5,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.all(3),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                children: [
                                                  // 时间行
                                                  Row(
                                                    children: [
                                                      if (!isUnmarked)
                                                        Icon(
                                                          status == PerformanceStatus.wantToSee
                                                              ? Icons.star
                                                              : Icons.check,
                                                          size: 9,
                                                          color: Colors
                                                              .white
                                                              .withValues(
                                                                  alpha:
                                                                      0.9),
                                                        ),
                                                      if (!isUnmarked)
                                                        const SizedBox(
                                                            width: 2),
                                                      Text(
                                                        (perf['time'] as String?)
                                                                ?.substring(
                                                                    0,
                                                                    5) ??
                                                            '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700,
                                                          color: isUnmarked
                                                              ? const Color(
                                                                  0xFF4B5563)
                                                              : Colors
                                                                  .white,
                                                          height: 1.1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  // 卡司行
                                                  if (featuredCasts
                                                      .isNotEmpty)
                                                    ...featuredCasts
                                                        .map((c) {
                                                      return Text(
                                                        '${c.role}:${c.actorName}',
                                                        style:
                                                            TextStyle(
                                                          fontSize: 10,
                                                          color: isUnmarked
                                                              ? const Color(
                                                                  0xFF6B7280)
                                                              : Colors
                                                                  .white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.9),
                                                          height: 1.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      );
                                                    }),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                    }).toList(),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          // 今天线
                          if (isCurrentWeek)
                            Positioned(
                              left: (today.weekday - 1) * cellWidth +
                                  cellWidth / 2 -
                                  1,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: const Color(0xFFF54A45)
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(double cellWidth, DateTime weekEnd) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevWeek,
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一周',
          ),
          OutlinedButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 16),
            label: const Text('今天'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: _nextWeek,
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一周',
          ),
          const SizedBox(width: 12),
          Text(
            '${_weekStart.month}/${_weekStart.day} - ${weekEnd.month}/${weekEnd.day}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2329),
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

// ==================== 编辑场次 Sheet ====================

class _EditPerformanceSheet extends StatefulWidget {
  final Map<String, dynamic> perf;
  final List<CastMember> existingCasts;
  final VoidCallback onSaved;

  const _EditPerformanceSheet({
    required this.perf,
    required this.existingCasts,
    required this.onSaved,
  });

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
      _castRows.add(_EditCastRow(
        role: c.role,
        actor: c.actorName,
        featured: c.isFeatured,
      ));
    }
    if (_castRows.isEmpty) {
      _castRows.add(_EditCastRow());
    }
  }

  @override
  void dispose() {
    for (final r in _castRows) {
      r.dispose();
    }
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
    if (picked != null) {
      setState(() => _date = _fullDateFormat.format(picked));
    }
  }

  Future<void> _pickTime() async {
    const presets = ['14:00', '14:30', '19:00', '19:30'];
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('选择开场时间',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...presets.map((t) => ActionChip(
                        label: Text(t),
                        onPressed: () => Navigator.pop(context, t),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: const Text('自定义'),
                    onPressed: () async {
                      final parts = _time.split(':');
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        ),
                      );
                      if (picked != null && context.mounted) {
                        Navigator.pop(context,
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                        );
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
    if (result != null) {
      setState(() => _time = result);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper.instance;
      final perfId = widget.perf['id'] as int;

      // 更新场次
      final performance = await db.getPerformanceById(perfId);
      if (performance != null) {
        await db.updatePerformance(performance.copyWith(
          date: _date,
          time: _time,
        ));
      }

      // 删除旧卡司
      await db.deleteCastMembersByPerformanceId(perfId);

      // 创建新卡司
      for (final row in _castRows) {
        final role = row.roleController.text.trim();
        final actor = row.actorController.text.trim();
        if (role.isNotEmpty && actor.isNotEmpty) {
          await db.createCastMember(CastMember(
            performanceId: perfId,
            role: role,
            actorName: actor,
            isFeatured: row.isFeatured,
            createdAt: DateTime.now().toIso8601String(),
          ));
          try {
            await db.createActor(Actor(
              name: actor,
              createdAt: DateTime.now().toIso8601String(),
            ));
          } catch (_) {}
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              const Text('编辑场次',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // 日期 + 时间
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '日期',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(_date, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '时间',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(_time, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 卡司表格
              Row(
                children: [
                  Text('卡司',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _castRows.add(_EditCastRow())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加角色'),
                  ),
                ],
              ),
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
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.roleController,
                                decoration: const InputDecoration(
                                  labelText: '角色',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row.actorController,
                                decoration: const InputDecoration(
                                  labelText: '演员',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: row.isFeatured,
                                  onChanged: (v) => setState(
                                      () => row.isFeatured = v ?? false),
                                ),
                                GestureDetector(
                                  onTap: () => setState(
                                      () => row.isFeatured = !row.isFeatured),
                                  child: const Text('★',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF811FE2))),
                                ),
                              ],
                            ),
                            if (_castRows.length > 1)
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red[300]),
                                onPressed: () => setState(() {
                                  row.dispose();
                                  _castRows.removeAt(index);
                                }),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
