class Performance {
  int? id;
  int showId;
  String date;
  String? time;
  String? seat;
  double? price;
  String? createdAt;

  Performance({
    this.id,
    required this.showId,
    required this.date,
    this.time,
    this.seat,
    this.price,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'show_id': showId,
      'date': date,
      'time': time,
      'seat': seat,
      'price': price,
      'created_at': createdAt,
    };
  }

  factory Performance.fromMap(Map<String, dynamic> map) {
    return Performance(
      id: map['id'] as int?,
      showId: map['show_id'] as int,
      date: map['date'] as String,
      time: map['time'] as String?,
      seat: map['seat'] as String?,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      createdAt: map['created_at'] as String?,
    );
  }

  Performance copyWith({
    int? id,
    int? showId,
    String? date,
    String? time,
    String? seat,
    double? price,
    String? createdAt,
  }) {
    return Performance(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      date: date ?? this.date,
      time: time ?? this.time,
      seat: seat ?? this.seat,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
