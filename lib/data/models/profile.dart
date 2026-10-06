/// 单例 Profile：尽量全面的「信息表」，每个字段带来源与附件，一切可追溯。
library;

import 'profile_record.dart';

/// 已知分区键（可扩展，未知键照常渲染）。
class ProfileSections {
  static const identity = 'identity';
  static const contact = 'contact';
  static const careerObjective = 'career_objective';
  static const summary = 'summary';
  static const online = 'online';
  static const strengths = 'strengths';
  static const languagesOverview = 'languages_overview';
  static const interestsOverview = 'interests_overview';
  static const referencesOverview = 'references_overview';
  static const custom = 'custom';
}

/// 一个 profile 字段：值 + 出处 + 附件。
class ProfileField {
  final String key;
  final dynamic value; // String | num | bool | List | Map
  final List<String> attachments;
  final RecordSource source;

  const ProfileField({
    required this.key,
    this.value,
    this.attachments = const [],
    this.source = const RecordSource(),
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'attachments': attachments,
        'source': source.toJson(),
      };

  factory ProfileField.fromJson(Map<String, dynamic> j) => ProfileField(
        key: (j['key'] ?? '') as String,
        value: j['value'],
        attachments: (j['attachments'] as List?)?.map((e) => '$e').toList() ?? const [],
        source: j['source'] != null
            ? RecordSource.fromJson((j['source'] as Map).cast<String, dynamic>())
            : const RecordSource(),
      );
}

/// 个人档案单例。
class Profile {
  /// schema 版本（B5）。
  final int schemaVersion;

  /// section -> (fieldKey -> field)。
  final Map<String, Map<String, ProfileField>> sections;

  /// 头像/证件照，相对同步根路径。
  final String? photoPath;
  final DateTime updatedAt;

  const Profile({
    this.schemaVersion = 1,
    this.sections = const {},
    this.photoPath,
    required this.updatedAt,
  });

  Profile copyWith({
    int? schemaVersion,
    Map<String, Map<String, ProfileField>>? sections,
    String? photoPath,
    DateTime? updatedAt,
  }) =>
      Profile(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        sections: sections ?? this.sections,
        photoPath: photoPath ?? this.photoPath,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'sections': sections.map((k, v) =>
            MapEntry(k, v.map((fk, fv) => MapEntry(fk, fv.toJson())))),
        'photo_path': photoPath,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> j) {
    final rawSections = (j['sections'] as Map?)?.cast<String, dynamic>() ?? {};
    final sections = <String, Map<String, ProfileField>>{};
    rawSections.forEach((sk, sv) {
      final m = (sv as Map).cast<String, dynamic>();
      sections[sk] = m.map(
        (fk, fv) => MapEntry(fk, ProfileField.fromJson((fv as Map).cast<String, dynamic>())),
      );
    });
    return Profile(
      schemaVersion: (j['schema_version'] as num?)?.toInt() ?? 1,
      sections: sections,
      photoPath: j['photo_path'] as String?,
      updatedAt: DateTime.tryParse('${j['updated_at']}') ?? DateTime.now(),
    );
  }

  static Profile empty() => Profile(updatedAt: DateTime.now());

  /// 便捷取值。
  dynamic valueOf(String section, String key) => sections[section]?[key]?.value;

  String stringOf(String section, String key, [String fallback = '']) {
    final v = valueOf(section, key);
    return v == null ? fallback : '$v';
  }
}
