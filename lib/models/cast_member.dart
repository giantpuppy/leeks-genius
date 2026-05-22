class CastMember {
  int? id;
  int performanceId;
  String role;
  String actorName;
  String? createdAt;

  CastMember({
    this.id,
    required this.performanceId,
    required this.role,
    required this.actorName,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'performance_id': performanceId,
      'role': role,
      'actor_name': actorName,
      'created_at': createdAt,
    };
  }

  factory CastMember.fromMap(Map<String, dynamic> map) {
    return CastMember(
      id: map['id'] as int?,
      performanceId: map['performance_id'] as int,
      role: map['role'] as String,
      actorName: map['actor_name'] as String,
      createdAt: map['created_at'] as String?,
    );
  }

  CastMember copyWith({
    int? id,
    int? performanceId,
    String? role,
    String? actorName,
    String? createdAt,
  }) {
    return CastMember(
      id: id ?? this.id,
      performanceId: performanceId ?? this.performanceId,
      role: role ?? this.role,
      actorName: actorName ?? this.actorName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
