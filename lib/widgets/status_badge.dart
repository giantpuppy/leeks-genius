import 'package:flutter/material.dart';

/// 状态胶囊标签
///
/// 用于排期板、月历票根卡片等场景，显示「想看」「已买」「已观演」等状态。
/// 样式：半透明背景 + 同色系细边框 + 圆角胶囊。
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double fontSize;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.fontSize = 11,
    this.borderRadius = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    if (onTap == null) return badge;

    return GestureDetector(
      onTap: onTap,
      child: badge,
    );
  }
}
