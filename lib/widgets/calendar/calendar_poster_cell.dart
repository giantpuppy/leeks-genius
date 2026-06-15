import 'package:flutter/material.dart';
import '../../utils/status_colors.dart';
import '../today_spotlight.dart';
import 'poster_grid.dart';

/// 月历中有演出场次的日期单元格。
///
/// 包含：海报网格、日期圆标、开场时间胶囊、选中态信息浮层、外发光阴影。
class CalendarPosterCell extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> events;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;

  const CalendarPosterCell({
    super.key,
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    this.isOutside = false,
  });

  static const double _outerRadius = 6.0;
  static const double _innerRadius = 4.0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final showCount = events.length;

    // 取最早一场的开场时间
    final earliestEvent = events.reduce((a, b) {
      final aTime = a['time'] as String? ?? '';
      final bTime = b['time'] as String? ?? '';
      return aTime.compareTo(bTime) <= 0 ? a : b;
    });
    final earliestTime = earliestEvent['time'] as String? ?? '';
    final timeText = earliestTime.length >= 5
        ? earliestTime.substring(0, 5)
        : earliestTime;
    final statusColor = statusColorForEvent(earliestEvent);

    // 底部信息浮层内容
    final firstShowName = events.first['show_name'] as String? ?? '未知剧目';
    final firstTheater = events.first['theater'] as String? ?? '未知剧场';
    final displayShowName = showCount > 1 ? '$firstShowName 等 $showCount 场' : firstShowName;

    Widget cell = Opacity(
      opacity: isOutside ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_outerRadius),
          boxShadow: isSelected
              ? [
                  // 外层晕开
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                  // 内层聚焦
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_outerRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 海报网格
              PosterGrid(
                events: events,
                isOutside: isOutside,
                outerRadius: _outerRadius,
                innerRadius: _innerRadius,
              ),

              // 选中蒙层
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ),

              // 日期圆标 + 时间胶囊
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (timeText.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xCC000000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 底部信息浮层（选中态时显示）
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(6, 16, 6, 5),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(_outerRadius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayShowName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          firstTheater,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isToday) {
      cell = TodaySpotlight(
        color: primaryColor,
        child: cell,
      );
    }

    return cell;
  }

  Color statusColorForEvent(Map<String, dynamic> event) {
    final status = event['status'] as String? ?? 'unmarked';
    return statusColor(status);
  }
}
