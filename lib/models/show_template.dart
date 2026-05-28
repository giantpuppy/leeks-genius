import 'dart:convert';

class ShowTemplate {
  int? id;
  String name;
  String? theater;
  List<String> roles;
  int performanceCount;
  String? createdAt;
  String? updatedAt;

  ShowTemplate({
    this.id,
    required this.name,
    this.theater,
    required this.roles,
    this.performanceCount = 1,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'theater': theater,
      'roles': jsonEncode(roles),
      'performance_count': performanceCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ShowTemplate.fromMap(Map<String, dynamic> map) {
    List<String> parsedRoles = [];
    final rawRoles = map['roles'];
    if (rawRoles is String) {
      try {
        parsedRoles = List<String>.from(jsonDecode(rawRoles));
      } catch (_) {}
    } else if (rawRoles is List) {
      parsedRoles = List<String>.from(rawRoles);
    }
    return ShowTemplate(
      id: map['id'] as int?,
      name: map['name'] as String,
      theater: map['theater'] as String?,
      roles: parsedRoles,
      performanceCount: (map['performance_count'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  ShowTemplate copyWith({
    int? id,
    String? name,
    String? theater,
    List<String>? roles,
    int? performanceCount,
    String? createdAt,
    String? updatedAt,
  }) {
    return ShowTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      theater: theater ?? this.theater,
      roles: roles ?? this.roles,
      performanceCount: performanceCount ?? this.performanceCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 合并另一个模板的角色列表（取并集）
  ShowTemplate mergeRoles(List<String> otherRoles) {
    final merged = [...roles];
    for (final role in otherRoles) {
      if (!merged.contains(role)) {
        merged.add(role);
      }
    }
    return copyWith(roles: merged, performanceCount: performanceCount + 1);
  }
}
