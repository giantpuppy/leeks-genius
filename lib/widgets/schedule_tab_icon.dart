import 'package:flutter/material.dart';

/// 排期页底部 tab 的自定义图标模式
enum ScheduleTabIconMode { threeDay, sevenDay }

/// 排期 tab 自定义图标
///
/// 3天聚焦模式：3 条等距横线
/// 7天宏观模式：7 条等距横线
class ScheduleTabIcon extends StatelessWidget {
  final ScheduleTabIconMode mode;
  final double size;
  final Color? color;

  const ScheduleTabIcon({
    super.key,
    required this.mode,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(
      size: Size(size, size),
      painter: _ScheduleTabIconPainter(
        lineCount: mode == ScheduleTabIconMode.threeDay ? 3 : 7,
        color: effectiveColor,
      ),
    );
  }
}

class _ScheduleTabIconPainter extends CustomPainter {
  final int lineCount;
  final Color color;

  _ScheduleTabIconPainter({
    required this.lineCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isThreeDay = lineCount == 3;

    // 横线宽度：3 天模式更粗，7 天模式更细
    final strokeWidth = isThreeDay ? size.height * 0.10 : size.height * 0.05;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // 上下留出边距，中间均匀分布
    final padding = size.height * 0.12;
    final availableHeight = size.height - padding * 2;
    final step = availableHeight / (lineCount - 1);

    for (int i = 0; i < lineCount; i++) {
      final y = padding + step * i;
      canvas.drawLine(
        Offset(size.width * 0.12, y),
        Offset(size.width * 0.88, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScheduleTabIconPainter old) {
    return old.lineCount != lineCount || old.color != color;
  }
}
