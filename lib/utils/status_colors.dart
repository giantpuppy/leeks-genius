import 'package:flutter/material.dart';

/// 暖金色（today 光晕 / 脚灯 / 侧边光）
const Color kWarmGold = Color(0xFFD4A853);

/// 状态紫色（品牌色）
const Color kBrandPurple = Color(0xFF6B5BCD);

/// today 红色
const Color kTodayRed = Color(0xFFF54A45);

/// 8 色海报兜底渐变板
const List<Color> kCoverColors = [
  Color(0xFF1A1A2E),
  Color(0xFF16213E),
  Color(0xFF0F3460),
  Color(0xFF533483),
  Color(0xFF2C3333),
  Color(0xFF2D4040),
  Color(0xFF3A3A3A),
  Color(0xFF2D1B69),
];

/// 根据 showId 返回稳定的海报兜底色
Color coverColorForShow(int showId) {
  return kCoverColors[showId.abs() % kCoverColors.length];
}

/// 根据场次状态返回对应的颜色。
///
/// - want_to_see: 紫色 (#811FE2)
/// - watched: 金色 (#D4A853)
/// - bought: 绿色 (#34D399)
/// - unmarked: 白色
Color statusColor(String status) {
  return switch (status) {
    'want_to_see' => const Color(0xFF811FE2),
    'watched' => const Color(0xFFD4A853),
    'bought' => const Color(0xFF34D399),
    _ => Colors.white,
  };
}

/// 根据场次状态返回对应的图标。
///
/// - want_to_see: 星星
/// - watched: 眼睛
/// - 其他：对勾
IconData statusIcon(String status) {
  return switch (status) {
    'want_to_see' => Icons.star_border,
    'watched' => Icons.visibility_outlined,
    _ => Icons.check_circle,
  };
}
