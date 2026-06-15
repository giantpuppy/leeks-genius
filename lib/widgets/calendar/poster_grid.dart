import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/status_colors.dart';

/// 月历有演出日期格子中的海报网格。
///
/// 根据场次数量自动选择布局：
/// - 1 场：单张填满
/// - 2 场：1×2 横向均分
/// - 3 场：1×3 横向均分
/// - 4 场：2×2 网格
/// - 5+ 场：2×2 网格，第四格显示 +N 遮罩
class PosterGrid extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final bool isOutside;
  final double outerRadius;
  final double innerRadius;

  const PosterGrid({
    super.key,
    required this.events,
    this.isOutside = false,
    this.outerRadius = 6.0,
    this.innerRadius = 4.0,
  });

  static const _gapColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final count = events.length;

    if (count == 1) {
      return _PosterThumbnail(
        event: events.first,
        isOutside: isOutside,
        borderRadius: outerRadius,
        topmost: true,
      );
    }

    if (count == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(outerRadius),
        child: Row(
          children: [
            Expanded(child: _PosterThumbnail(event: events[0], isOutside: isOutside)),
            Container(width: 1, color: _gapColor),
            Expanded(child: _PosterThumbnail(event: events[1], isOutside: isOutside)),
          ],
        ),
      );
    }

    if (count == 3) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(outerRadius),
        child: Row(
          children: [
            Expanded(child: _PosterThumbnail(event: events[0], isOutside: isOutside)),
            Container(width: 1, color: _gapColor),
            Expanded(child: _PosterThumbnail(event: events[1], isOutside: isOutside)),
            Container(width: 1, color: _gapColor),
            Expanded(child: _PosterThumbnail(event: events[2], isOutside: isOutside)),
          ],
        ),
      );
    }

    // 4 场及以上：2×2 网格
    final showPlusOverlay = count > 4;
    return ClipRRect(
      borderRadius: BorderRadius.circular(outerRadius),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _PosterThumbnail(event: events[0], isOutside: isOutside)),
                Container(width: 1, color: _gapColor),
                Expanded(child: _PosterThumbnail(event: events[1], isOutside: isOutside)),
              ],
            ),
          ),
          Container(height: 1, color: _gapColor),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _PosterThumbnail(event: events[2], isOutside: isOutside)),
                Container(width: 1, color: _gapColor),
                Expanded(
                  child: showPlusOverlay
                      ? _PosterThumbnail(
                          event: events[3],
                          isOutside: isOutside,
                          overlayText: '+${count - 3}',
                        )
                      : _PosterThumbnail(event: events[3], isOutside: isOutside),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterThumbnail extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isOutside;
  final double borderRadius;
  final bool topmost;
  final String? overlayText;

  const _PosterThumbnail({
    required this.event,
    this.isOutside = false,
    this.borderRadius = 4.0,
    this.topmost = false,
    this.overlayText,
  });

  @override
  Widget build(BuildContext context) {
    final status = event['status'] as String? ?? 'unmarked';
    final color = statusColor(status);
    final coverPath = event['cover_path'] as String?;
    final showName = event['show_name'] as String? ?? '未知';

    Widget content = coverPath != null && coverPath.isNotEmpty
        ? Image.file(
            File(coverPath),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _PosterFallback(showName: showName, color: color),
          )
        : _PosterFallback(showName: showName, color: color);

    if (isOutside) {
      content = Opacity(opacity: 0.5, child: content);
    }

    return Container(
      decoration: BoxDecoration(
        border: topmost
            ? Border.all(color: color.withValues(alpha: 0.6), width: 1)
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
        color: color.withValues(alpha: isOutside ? 0.08 : 0.15),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (overlayText != null)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Text(
                overlayText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final String showName;
  final Color color;

  const _PosterFallback({required this.showName, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Text(
          showName.length >= 2 ? showName.substring(0, 2) : showName,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
