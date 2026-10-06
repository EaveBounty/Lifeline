/// 信息记录（信息表的一行）：所有分类共用同一结构。
library;

import 'record_category.dart';

/// 外部链接。
class RecordLink {
  final String label;
  final String url;
  const RecordLink({this.label = '', required this.url});

  Map<String, dynamic> toJson() => {'label': label, 'url': url};
  factory RecordLink.fromJson(Map<String, dynamic> j) =>
      RecordLink(label: (j['label'] ?? '') as String, url: (j['url'] ?? '') as String);
}

/// 来源标记：一切信息可追溯。
class RecordSource {
  /// manual | ai | import
  final String type;
  final String? raw;
  final String? ref;
  const RecordSource({this.type = 'manual', this.raw, this.ref});

  Map<String, dynamic> toJson() => {'type': type, 'raw': raw, 'ref': ref};
  factory RecordSource.fromJson(Map<String, dynamic> j) => RecordSource(
        type: (j['type'] ?? 'manual') as String,
        raw: j['raw'] as String?,
        ref: j['ref'] as String?,
      );
}

/// AI 元数据。
class RecordAiMeta {
  final String? model;
  final double confidence;
  final bool reviewed;
  const RecordAiMeta({this.model, this.confidence = 0, this.reviewed = false});

  Map<String, dynamic> toJson() =>
      {'model': model, 'confidence': confidence, 'reviewed': reviewed};
  factory RecordAiMeta.fromJson(Map<String, dynamic> j) => RecordAiMeta(
        model: j['model'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        reviewed: (j['reviewed'] ?? false) as bool,
      );
}

/// 一条信息记录。
class ProfileRecord {
  /// schema 版本（B5）。
  final int schemaVersion;
  final String id;
  final RecordCategory category;
  final String title;
  final String? organization;
  final String? role;
  final String? location;

  /// YYYY-MM 或 YYYY-MM-DD 或 null。
  final String? startDate;

  /// YYYY-MM 或 YYYY-MM-DD 或 null（null = 至今/进行中）。
  final String? endDate;

  /// Markdown 正文。
  final String description;
  final List<String> highlights;
  final List<String> tags;

  /// 分类专属结构化键值（如 major/gpa/journal）。
  final Map<String, dynamic> fields;

  /// 附件相对路径（相对同步根）。
  final List<String> attachments;
  final List<RecordLink> links;
  final RecordSource source;
  final RecordAiMeta ai;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// active | archived
  final String status;
  final int order;

  const ProfileRecord({
    this.schemaVersion = 1,
    required this.id,
    required this.category,
    required this.title,
    this.organization,
    this.role,
    this.location,
    this.startDate,
    this.endDate,
    this.description = '',
    this.highlights = const [],
    this.tags = const [],
    this.fields = const {},
    this.attachments = const [],
    this.links = const [],
    this.source = const RecordSource(),
    this.ai = const RecordAiMeta(),
    required this.createdAt,
    required this.updatedAt,
    this.status = 'active',
    this.order = 0,
  });

  ProfileRecord copyWith({
    int? schemaVersion,
    String? title,
    String? organization,
    String? role,
    String? location,
    String? startDate,
    String? endDate,
    String? description,
    List<String>? highlights,
    List<String>? tags,
    Map<String, dynamic>? fields,
    List<String>? attachments,
    List<RecordLink>? links,
    RecordSource? source,
    RecordAiMeta? ai,
    DateTime? updatedAt,
    String? status,
    int? order,
    RecordCategory? category,
  }) {
    return ProfileRecord(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id,
      category: category ?? this.category,
      title: title ?? this.title,
      organization: organization ?? this.organization,
      role: role ?? this.role,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      highlights: highlights ?? this.highlights,
      tags: tags ?? this.tags,
      fields: fields ?? this.fields,
      attachments: attachments ?? this.attachments,
      links: links ?? this.links,
      source: source ?? this.source,
      ai: ai ?? this.ai,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      status: status ?? this.status,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'id': id,
        'category': category.slug,
        'title': title,
        'organization': organization,
        'role': role,
        'location': location,
        'start_date': startDate,
        'end_date': endDate,
        'description': description,
        'highlights': highlights,
        'tags': tags,
        'fields': fields,
        'attachments': attachments,
        'links': links.map((l) => l.toJson()).toList(),
        'source': source.toJson(),
        'ai': ai.toJson(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'status': status,
        'order': order,
      };

  factory ProfileRecord.fromJson(Map<String, dynamic> j) {
    return ProfileRecord(
      schemaVersion: (j['schema_version'] as num?)?.toInt() ?? 1,
      id: j['id'] as String,
      category: RecordCategory.fromSlug(j['category'] as String?) ?? RecordCategory.custom,
      title: (j['title'] ?? '') as String,
      organization: j['organization'] as String?,
      role: j['role'] as String?,
      location: j['location'] as String?,
      startDate: j['start_date'] as String?,
      endDate: j['end_date'] as String?,
      description: (j['description'] ?? '') as String,
      highlights: (j['highlights'] as List?)?.map((e) => '$e').toList() ?? const [],
      tags: (j['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
      fields: (j['fields'] as Map?)?.cast<String, dynamic>() ?? const {},
      attachments: (j['attachments'] as List?)?.map((e) => '$e').toList() ?? const [],
      links: (j['links'] as List?)
              ?.map((e) => RecordLink.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      source: j['source'] != null
          ? RecordSource.fromJson((j['source'] as Map).cast<String, dynamic>())
          : const RecordSource(),
      ai: j['ai'] != null
          ? RecordAiMeta.fromJson((j['ai'] as Map).cast<String, dynamic>())
          : const RecordAiMeta(),
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${j['updated_at']}') ?? DateTime.now(),
      status: (j['status'] ?? 'active') as String,
      order: (j['order'] as num?)?.toInt() ?? 0,
    );
  }
}
