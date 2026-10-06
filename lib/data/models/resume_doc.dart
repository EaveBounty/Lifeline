/// 简历中间表示（IR）：平台无关，供首页渲染与所有导出渲染器共用。
library;

/// 头部联系人项。
class ResumeContact {
  final String label;
  final String value;
  final String? url;
  const ResumeContact({required this.label, required this.value, this.url});

  Map<String, dynamic> toJson() => {'label': label, 'value': value, 'url': url};
}

/// 头部。
class ResumeHeader {
  final String name;
  final String? englishName;
  final String? headline;
  final String? photoPath;
  final List<ResumeContact> contacts;
  const ResumeHeader({
    required this.name,
    this.englishName,
    this.headline,
    this.photoPath,
    this.contacts = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'english_name': englishName,
        'headline': headline,
        'photo_path': photoPath,
        'contacts': contacts.map((c) => c.toJson()).toList(),
      };
}

/// 一个条目。
class ResumeItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? meta;
  final String? description;
  final List<String> bullets;
  final Map<String, dynamic> fields;
  final List<String> attachments;
  final List<String> tags;

  /// 回指来源记录，便于追溯与定向裁剪。
  final String? sourceRecordId;
  final String categorySlug;

  /// 定向裁剪时可标记保留/丢弃；用于 AI 排序。
  final double weight;

  const ResumeItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.meta,
    this.description,
    this.bullets = const [],
    this.fields = const {},
    this.attachments = const [],
    this.tags = const [],
    this.sourceRecordId,
    required this.categorySlug,
    this.weight = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'meta': meta,
        'description': description,
        'bullets': bullets,
        'fields': fields,
        'attachments': attachments,
        'tags': tags,
        'source_record_id': sourceRecordId,
        'category_slug': categorySlug,
        'weight': weight,
      };
}

/// 章节。
class ResumeSection {
  final String key;
  final String title;
  final List<ResumeItem> items;
  final int order;
  const ResumeSection({
    required this.key,
    required this.title,
    this.items = const [],
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'items': items.map((i) => i.toJson()).toList(),
        'order': order,
      };
}

/// 简历文档。
class ResumeDocument {
  /// schema 版本（B5）。
  final int schemaVersion;
  final ResumeHeader header;
  final String? summary;
  final List<String> strengths;
  final List<ResumeSection> sections;
  final DateTime generatedAt;

  /// 语言：zh | en。
  final String language;

  /// 元信息（定向导出时记录岗位等）。
  final Map<String, dynamic> meta;

  /// 是否为定向裁剪版本。
  final bool tailored;

  const ResumeDocument({
    this.schemaVersion = 1,
    required this.header,
    this.summary,
    this.strengths = const [],
    this.sections = const [],
    required this.generatedAt,
    this.language = 'zh',
    this.meta = const {},
    this.tailored = false,
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'header': header.toJson(),
        'summary': summary,
        'strengths': strengths,
        'sections': sections.map((s) => s.toJson()).toList(),
        'generated_at': generatedAt.toIso8601String(),
        'language': language,
        'meta': meta,
        'tailored': tailored,
      };

  factory ResumeDocument.fromJson(Map<String, dynamic> j) {
    final h = (j['header'] as Map?)?.cast<String, dynamic>() ?? {};
    return ResumeDocument(
      schemaVersion: (j['schema_version'] as num?)?.toInt() ?? 1,
      header: ResumeHeader(
        name: (h['name'] ?? '') as String,
        englishName: h['english_name'] as String?,
        headline: h['headline'] as String?,
        photoPath: h['photo_path'] as String?,
        contacts: (h['contacts'] as List?)
                ?.map((e) {
                  final m = (e as Map).cast<String, dynamic>();
                  return ResumeContact(
                    label: '${m['label'] ?? ''}',
                    value: '${m['value'] ?? ''}',
                    url: m['url'] as String?,
                  );
                })
                .toList() ??
            const [],
      ),
      summary: j['summary'] as String?,
      strengths: (j['strengths'] as List?)?.map((e) => '$e').toList() ?? const [],
      sections: (j['sections'] as List?)
              ?.map((e) {
                final m = (e as Map).cast<String, dynamic>();
                return ResumeSection(
                  key: '${m['key'] ?? ''}',
                  title: '${m['title'] ?? ''}',
                  order: (m['order'] as num?)?.toInt() ?? 0,
                  items: (m['items'] as List?)
                          ?.map((ie) {
                            final im = (ie as Map).cast<String, dynamic>();
                            return ResumeItem(
                              id: '${im['id'] ?? ''}',
                              title: '${im['title'] ?? ''}',
                              subtitle: im['subtitle'] as String?,
                              meta: im['meta'] as String?,
                              description: im['description'] as String?,
                              bullets:
                                  (im['bullets'] as List?)?.map((b) => '$b').toList() ?? const [],
                              fields: (im['fields'] as Map?)?.cast<String, dynamic>() ?? const {},
                              attachments:
                                  (im['attachments'] as List?)?.map((b) => '$b').toList() ?? const [],
                              tags: (im['tags'] as List?)?.map((b) => '$b').toList() ?? const [],
                              sourceRecordId: im['source_record_id'] as String?,
                              categorySlug: '${im['category_slug'] ?? ''}',
                              weight: (im['weight'] as num?)?.toDouble() ?? 1.0,
                            );
                          })
                          .toList() ??
                      const [],
                );
              })
              .toList() ??
          const [],
      generatedAt: DateTime.tryParse('${j['generated_at']}') ?? DateTime.now(),
      language: (j['language'] ?? 'zh') as String,
      meta: (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
      tailored: (j['tailored'] ?? false) as bool,
    );
  }
}
