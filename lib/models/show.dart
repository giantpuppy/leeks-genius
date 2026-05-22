class Show {
  int? id;
  String name;
  String? theater;
  String? createdAt;

  Show({
    this.id,
    required this.name,
    this.theater,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'theater': theater,
      'created_at': createdAt,
    };
  }

  factory Show.fromMap(Map<String, dynamic> map) {
    return Show(
      id: map['id'] as int?,
      name: map['name'] as String,
      theater: map['theater'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Show copyWith({
    int? id,
    String? name,
    String? theater,
    String? createdAt,
  }) {
    return Show(
      id: id ?? this.id,
      name: name ?? this.name,
      theater: theater ?? this.theater,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
