import 'package:flutter/material.dart';

/// 根据场次状态返回对应的颜色。
///
/// - want_to_see: 紫色 (#811FE2)
/// - watched: 金色 (#D4A853)
/// - 其他（bought / unmarked）: 绿色 (#34D399)
Color statusColor(String status) {
  return switch (status) {
    'want_to_see' => const Color(0xFF811FE2),
    'watched' => const Color(0xFFD4A853),
    _ => const Color(0xFF34D399),
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
