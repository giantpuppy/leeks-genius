class Actor {
  int? id;
  String name;
  String? note;
  String? createdAt;

  Actor({
    this.id,
    required this.name,
    this.note,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory Actor.fromMap(Map<String, dynamic> map) {
    return Actor(
      id: map['id'] as int?,
      name: map['name'] as String,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Actor copyWith({
    int? id,
    String? name,
    String? note,
    String? createdAt,
  }) {
    return Actor(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
