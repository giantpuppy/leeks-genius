class Performance {
  int? id;
  int showId;
  String date;
  String? time;
  String? seat;
  double? price;
  String? status; // unmarked | want_to_see | bought
  String? createdAt;

  Performance({
    this.id,
    required this.showId,
    required this.date,
    this.time,
    this.seat,
    this.price,
    this.status,
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
      'status': status ?? 'unmarked',
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
      status: map['status'] as String? ?? 'unmarked',
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
    String? status,
    String? createdAt,
  }) {
    return Performance(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      date: date ?? this.date,
      time: time ?? this.time,
      seat: seat ?? this.seat,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
