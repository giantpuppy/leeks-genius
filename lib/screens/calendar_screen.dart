import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/database_helper.dart';
import 'show_detail_screen.dart';

enum CalendarFilter { all, wantToSee, bought }

extension CalendarFilterExt on CalendarFilter {
  String get label {
    switch (this) {
      case CalendarFilter.all:
        return '全部';
      case CalendarFilter.wantToSee:
        return '想看';
      case CalendarFilter.bought:
        return '已买';
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarFilter _filter = CalendarFilter.all;
  List<Map<String, dynamic>> _performances = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('yyyy年M月');
  final DateFormat _weekdayFormat = DateFormat('EEEE', 'zh_CN');

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForMonth(_focusedDay);
    _loadPerformancesForDate(_focusedDay);
  }

  bool _shouldInclude(Map<String, dynamic> perf) {
    final status = perf['status'] as String? ?? 'unmarked';
    if (status == 'unmarked') return false;
    switch (_filter) {
      case CalendarFilter.all:
        return status == 'want_to_see' || status == 'bought';
      case CalendarFilter.wantToSee:
        return status == 'want_to_see';
      case CalendarFilter.bought:
        return status == 'bought';
    }
  }

  Future<void> _loadEventsForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final db = DatabaseHelper.instance;
    final performances = await db.getPerformancesByDateRange(
      _dateFormat.format(startOfMonth),
      _dateFormat.format(endOfMonth),
    );

    final events = <DateTime, List<Map<String, dynamic>>>{};
    for (final p in performances) {
      if (!_shouldInclude(p.toMap())) continue;
      final dateStr = p.date;
      final date = _dateFormat.parse(dateStr);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!events.containsKey(normalizedDate)) {
        events[normalizedDate] = [];
      }
      events[normalizedDate]!.add(p.toMap());
    }

    setState(() {
      _events = events;
    });
  }

  Future<void> _loadPerformancesForDate(DateTime date) async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    final dateStr = _dateFormat.format(date);
    final performances = await db.getPerformancesWithShowByDate(dateStr);

    setState(() {
      _performances = performances.where(_shouldInclude).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayFormat.format(_focusedDay)),
      ),
      body: Column(
        children: [
          // 筛选栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<CalendarFilter>(
              segments: [
                ButtonSegment(
                  value: CalendarFilter.all,
                  label: Text(CalendarFilter.all.label),
                ),
                ButtonSegment(
                  value: CalendarFilter.wantToSee,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF811FE2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(CalendarFilter.wantToSee.label),
                    ],
                  ),
                ),
                ButtonSegment(
                  value: CalendarFilter.bought,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(CalendarFilter.bought.label),
                    ],
                  ),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (set) {
                setState(() => _filter = set.first);
                _loadEventsForMonth(_focusedDay);
                _loadPerformancesForDate(_selectedDay ?? _focusedDay);
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),

          // Calendar
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: '月',
                  CalendarFormat.twoWeeks: '双周',
                  CalendarFormat.week: '周',
                },
                eventLoader: (day) {
                  final normalized = DateTime(day.year, day.month, day.day);
                  return _events[normalized] ?? [];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _loadPerformancesForDate(selectedDay);
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                  _loadEventsForMonth(focusedDay);
                },
                onFormatChanged: (format) {
                  setState(() => _calendarFormat = format);
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: events.take(3).map((e) {
                          final status = (e as Map<String, dynamic>)['status'] as String? ?? 'unmarked';
                          final color = status == 'want_to_see'
                              ? const Color(0xFF811FE2)
                              : const Color(0xFF34D399);
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  markerSize: 6,
                  markersMaxCount: 3,
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                ),
                locale: 'zh_CN',
              ),
            ),
          ),

          // Selected date performances
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_selectedDay?.day ?? _focusedDay.day}日 ${_weekdayFormat.format(_selectedDay ?? _focusedDay)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_performances.length} 场',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _performances.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _performances.length,
                        itemBuilder: (context, index) {
                          final perf = _performances[index];
                          final status = perf['status'] as String? ?? 'unmarked';
                          final isWantToSee = status == 'want_to_see';
                          final statusColor = isWantToSee
                              ? const Color(0xFF811FE2)
                              : const Color(0xFF34D399);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        perf['time']?.substring(0, 5) ?? '--:--',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Icon(
                                        isWantToSee
                                            ? Icons.star_border
                                            : Icons.check_circle,
                                        size: 10,
                                        color: statusColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              title: Text(
                                perf['show_name'] ?? '未知剧目',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                perf['theater'] ?? '未知剧场',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isWantToSee ? '想看' : '已买',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ShowDetailScreen(
                                      performanceId: perf['id'] as int,
                                    ),
                                  ),
                                ).then((_) {
                                  _loadPerformancesForDate(
                                      _selectedDay ?? _focusedDay);
                                  _loadEventsForMonth(_focusedDay);
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '今日无标记场次',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Text(
            '在甘特图标记「想看」或「已买」后，\n场次会显示在这里',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[350],
            ),
          ),
        ],
      ),
    );
  }
}
