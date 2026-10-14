/// 照片库模型：证件照 / 个人照，含用于「智能选图」的元数据与标签。
library;

/// 一张照片。
class Photo {
  final String id;

  /// 相对同步根的路径（复制进 attachments/）。
  final String relPath;
  final String filename;

  /// 文件字节数。
  final int size;

  /// 内容 sha1（去重）。
  final String sha1;

  /// 像素尺寸（读取失败为 null）。
  final int? width;
  final int? height;

  /// 拍摄 / 签名时间（EXIF 缺失时用文件修改时间，可由用户修正）。
  final DateTime? takenAt;

  /// 人工标签（如 证件照 / 正装 / 白底 / 生活照 / 休闲）。
  final List<String> tags;

  /// 是否为证件照（用于版式与权重）。
  final bool idPhoto;

  /// 可选视觉模型打分 0–1（对专业度/着装/构图的判断）。
  final double? aiScore;
  final String? aiNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Photo({
    required this.id,
    required this.relPath,
    required this.filename,
    this.size = 0,
    this.sha1 = '',
    this.width,
    this.height,
    this.takenAt,
    this.tags = const [],
    this.idPhoto = false,
    this.aiScore,
    this.aiNote,
    required this.createdAt,
    required this.updatedAt,
  });

  Photo copyWith({
    String? relPath,
    String? filename,
    int? size,
    String? sha1,
    int? width,
    int? height,
    DateTime? takenAt,
    List<String>? tags,
    bool? idPhoto,
    double? aiScore,
    String? aiNote,
    DateTime? updatedAt,
  }) =>
      Photo(
        id: id,
        relPath: relPath ?? this.relPath,
        filename: filename ?? this.filename,
        size: size ?? this.size,
        sha1: sha1 ?? this.sha1,
        width: width ?? this.width,
        height: height ?? this.height,
        takenAt: takenAt ?? this.takenAt,
        tags: tags ?? this.tags,
        idPhoto: idPhoto ?? this.idPhoto,
        aiScore: aiScore ?? this.aiScore,
        aiNote: aiNote ?? this.aiNote,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rel_path': relPath,
        'filename': filename,
        'size': size,
        'sha1': sha1,
        'width': width,
        'height': height,
        'taken_at': takenAt?.toIso8601String(),
        'tags': tags,
        'id_photo': idPhoto,
        'ai_score': aiScore,
        'ai_note': aiNote,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        id: '${j['id'] ?? ''}',
        relPath: '${j['rel_path'] ?? ''}',
        filename: '${j['filename'] ?? ''}',
        size: (j['size'] as num?)?.toInt() ?? 0,
        sha1: '${j['sha1'] ?? ''}',
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        takenAt: DateTime.tryParse('${j['taken_at']}'),
        tags: (j['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
        idPhoto: (j['id_photo'] ?? false) as bool,
        aiScore: (j['ai_score'] as num?)?.toDouble(),
        aiNote: j['ai_note'] as String?,
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
        updatedAt: DateTime.tryParse('${j['updated_at']}') ?? DateTime.now(),
      );

  /// 宽高比（宽/高），未知返回 null。
  double? get aspect =>
      (width == null || height == null || height == 0) ? null : width! / height!;
}
