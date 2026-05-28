class OcrCorrection {
  int? id;
  String ocrText;
  String correctedText;
  String category;
  int useCount;
  String? createdAt;

  OcrCorrection({
    this.id,
    required this.ocrText,
    required this.correctedText,
    required this.category,
    this.useCount = 1,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ocr_text': ocrText,
      'corrected_text': correctedText,
      'category': category,
      'use_count': useCount,
      'created_at': createdAt,
    };
  }

  factory OcrCorrection.fromMap(Map<String, dynamic> map) {
    return OcrCorrection(
      id: map['id'] as int?,
      ocrText: map['ocr_text'] as String,
      correctedText: map['corrected_text'] as String,
      category: map['category'] as String,
      useCount: (map['use_count'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] as String?,
    );
  }

  OcrCorrection copyWith({
    int? id,
    String? ocrText,
    String? correctedText,
    String? category,
    int? useCount,
    String? createdAt,
  }) {
    return OcrCorrection(
      id: id ?? this.id,
      ocrText: ocrText ?? this.ocrText,
      correctedText: correctedText ?? this.correctedText,
      category: category ?? this.category,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
