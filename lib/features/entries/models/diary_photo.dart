class DiaryPhoto {
  const DiaryPhoto({
    this.id,
    required this.localPath,
    this.thumbPath,
    this.width,
    this.height,
    this.takenAt,
    required this.sortOrder,
    required this.createdAt,
  });

  final int? id;
  final String localPath;
  final String? thumbPath;
  final int? width;
  final int? height;
  final DateTime? takenAt;
  final int sortOrder;
  final DateTime createdAt;

  DiaryPhoto copyWith({
    int? id,
    String? localPath,
    String? thumbPath,
    int? width,
    int? height,
    DateTime? takenAt,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return DiaryPhoto(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      thumbPath: thumbPath ?? this.thumbPath,
      width: width ?? this.width,
      height: height ?? this.height,
      takenAt: takenAt ?? this.takenAt,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
