/// 附件索引模型（真相源是文件本身 + 记录内的相对路径；本表可重建）。
library;

class Attachment {
  final String id;

  /// 关联记录 id（可空：如个人照片直挂 profile）。
  final String? recordId;

  /// 相对同步根的路径，如 attachments/2026/ab12cd34-cert.jpg。
  final String relPath;
  final String filename;
  final String? mime;
  final int size;

  /// 内容 sha1（用于去重/检测变化）。
  final String sha1;
  final String? caption;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    this.recordId,
    required this.relPath,
    required this.filename,
    this.mime,
    this.size = 0,
    required this.sha1,
    this.caption,
    required this.createdAt,
  });

  Attachment copyWith({String? recordId, String? caption}) => Attachment(
        id: id,
        recordId: recordId ?? this.recordId,
        relPath: relPath,
        filename: filename,
        mime: mime,
        size: size,
        sha1: sha1,
        caption: caption ?? this.caption,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'record_id': recordId,
        'rel_path': relPath,
        'filename': filename,
        'mime': mime,
        'size': size,
        'sha1': sha1,
        'caption': caption,
        'created_at': createdAt.toIso8601String(),
      };

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] as String,
        recordId: j['record_id'] as String?,
        relPath: j['rel_path'] as String,
        filename: (j['filename'] ?? '') as String,
        mime: j['mime'] as String?,
        size: (j['size'] as num?)?.toInt() ?? 0,
        sha1: (j['sha1'] ?? '') as String,
        caption: j['caption'] as String?,
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );
}
