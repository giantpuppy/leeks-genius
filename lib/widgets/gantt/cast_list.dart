import 'package:flutter/material.dart';
import '../../models/cast_member.dart';

/// 排期板聚焦卡片中的卡司列表。
///
/// 规则：
/// - 优先显示 `isFeatured` 角色；
/// - 最多显示 [maxCount] 条；
/// - 角色名更淡，演员名更亮，形成对比。
class FeaturedCastList extends StatelessWidget {
  final List<CastMember> casts;
  final int maxCount;
  final double width;
  final double height;

  const FeaturedCastList({
    super.key,
    required this.casts,
    required this.width,
    required this.height,
    this.maxCount = 3,
  });

  List<CastMember> get _displayCasts {
    if (casts.length <= maxCount) return casts;
    final featured = casts.where((c) => c.isFeatured == true).toList();
    final others = casts.where((c) => c.isFeatured != true).toList();
    return [...featured, ...others].take(maxCount).toList();
  }

  @override
  Widget build(BuildContext context) {
    final display = _displayCasts;
    if (display.isEmpty) return const SizedBox.shrink();

    // 用一个较大的基准字号，FittedBox 会自动缩放到可用宽度
    final baseFontSize = width * 0.10;

    final roleStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.75),
      fontSize: baseFontSize,
      fontWeight: FontWeight.w400,
      shadows: const [
        Shadow(color: Colors.black, blurRadius: 4),
      ],
    );

    final actorStyle = TextStyle(
      color: Colors.white,
      fontSize: baseFontSize,
      fontWeight: FontWeight.w600,
      shadows: const [
        Shadow(color: Colors.black, blurRadius: 4),
      ],
    );

    final dividerStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: baseFontSize,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: display.map((c) {
        final cleanRole = c.role
            .replaceAll(RegExp(r'[《》「」『』【】\[\]（）()]+'), '')
            .trim();
        return Padding(
          padding: EdgeInsets.only(bottom: height * 0.01),
          child: SizedBox(
            width: width * 0.80,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cleanRole.isEmpty ? '-' : cleanRole,
                    style: roleStyle,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('|', style: dividerStyle),
                  ),
                  Text(
                    c.actorName.isEmpty ? '-' : c.actorName,
                    style: actorStyle,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
