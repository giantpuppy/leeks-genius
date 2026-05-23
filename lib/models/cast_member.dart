class CastMember {
  int? id;
  int performanceId;
  String role;
  String actorName;
  bool? isFeatured;
  String? createdAt;

  CastMember({
    this.id,
    required this.performanceId,
    required this.role,
    required this.actorName,
    this.isFeatured,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'performance_id': performanceId,
      'role': role,
      'actor_name': actorName,
      'is_featured': isFeatured == true ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory CastMember.fromMap(Map<String, dynamic> map) {
    return CastMember(
      id: map['id'] as int?,
      performanceId: map['performance_id'] as int,
      role: map['role'] as String,
      actorName: map['actor_name'] as String,
      isFeatured: map['is_featured'] == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  CastMember copyWith({
    int? id,
    int? performanceId,
    String? role,
    String? actorName,
    bool? isFeatured,
    String? createdAt,
  }) {
    return CastMember(
      id: id ?? this.id,
      performanceId: performanceId ?? this.performanceId,
      role: role ?? this.role,
      actorName: actorName ?? this.actorName,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
