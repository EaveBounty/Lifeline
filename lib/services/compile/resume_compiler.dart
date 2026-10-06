/// 简历编译器：Profile + 记录 -> ResumeDocument（纯函数，无 IO）。
library;

import '../../data/models/profile.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../../data/models/resume_doc.dart';

class ResumeCompiler {
  const ResumeCompiler();

  ResumeDocument compile({
    required Profile profile,
    required List<ProfileRecord> records,
    String language = 'zh',
    Map<String, dynamic> meta = const {},
    bool tailored = false,
  }) {
    final en = language == 'en';
    final identity = profile.sections[ProfileSections.identity] ?? const {};
    final contact = profile.sections[ProfileSections.contact] ?? const {};

    String pick(
      List<Map<String, ProfileField>> maps,
      List<String> keys,
    ) {
      for (final map in maps) {
        for (final key in keys) {
          final text = _asText(map[key]?.value);
          if (text.isNotEmpty) return text;
        }
      }
      return '';
    }

    final name = pick([identity], _FieldKeys.name);
    final englishName = pick([identity], _FieldKeys.englishName);
    final headline = pick([identity], _FieldKeys.headline);

    final contacts = <ResumeContact>[];
    void addContact(String label, List<String> keys, {String? prefixUrl}) {
      final value = pick([contact, identity], keys);
      if (value.isEmpty) return;
      contacts.add(ResumeContact(
        label: label,
        value: value,
        url: prefixUrl == null ? null : '$prefixUrl$value',
      ));
    }

    addContact(en ? 'Phone' : '电话', _FieldKeys.phone, prefixUrl: 'tel:');
    addContact(en ? 'Email' : '邮箱', _FieldKeys.email, prefixUrl: 'mailto:');
    addContact(en ? 'Location' : '所在地', _FieldKeys.location);
    addContact(en ? 'Website' : '网站', _FieldKeys.website);
    addContact('LinkedIn', _FieldKeys.linkedin);
    addContact('GitHub', _FieldKeys.github);

    final header = ResumeHeader(
      name: name,
      englishName: englishName.isEmpty ? null : englishName,
      headline: headline.isEmpty ? null : headline,
      photoPath: profile.photoPath,
      contacts: contacts,
    );

    final summary = _pickSectionValue(
      profile.sections[ProfileSections.summary],
      _FieldKeys.summary,
    );

    final strengths = _collectValues(
      profile.sections[ProfileSections.strengths],
      _FieldKeys.strengths,
    );

    final sections = <ResumeSection>[];
    for (final category in RecordCategory.values) {
      final items = records
          .where((r) => r.category == category && r.status == 'active')
          .toList()
        ..sort((a, b) {
          final c = a.order.compareTo(b.order);
          return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
        });
      if (items.isEmpty) continue;
      sections.add(ResumeSection(
        key: category.sectionKey,
        title: en ? category.slug : category.labelZh,
        order: category.defaultOrder,
        items: items.map(_toItem).toList(),
      ));
    }
    sections.sort((a, b) => a.order.compareTo(b.order));

    return ResumeDocument(
      header: header,
      summary: summary,
      strengths: strengths,
      sections: sections,
      generatedAt: DateTime.now(),
      language: language,
      meta: meta,
      tailored: tailored,
    );
  }

  ResumeItem _toItem(ProfileRecord record) {
    final parts = <String>[
      if ((record.organization ?? '').isNotEmpty) record.organization!,
      if ((record.role ?? '').isNotEmpty) record.role!,
      if ((record.location ?? '').isNotEmpty) record.location!,
      if (_dateRange(record.startDate, record.endDate) != null)
        _dateRange(record.startDate, record.endDate)!,
    ];
    final meta = parts.isEmpty ? null : parts.join(' · ');
    return ResumeItem(
      id: record.id,
      title: record.title,
      subtitle: record.organization,
      meta: meta,
      description: record.description.isEmpty ? null : record.description,
      bullets: record.highlights,
      fields: record.fields,
      attachments: record.attachments,
      tags: record.tags,
      sourceRecordId: record.id,
      categorySlug: record.category.slug,
      weight: 1.0,
    );
  }

  String? _dateRange(String? start, String? end) {
    if (start == null && end == null) return null;
    if (start != null && end != null) return '$start ~ $end';
    if (start != null) return '$start ~ …';
    return '~ $end';
  }

  String? _pickSectionValue(
    Map<String, ProfileField>? section,
    List<String> keys,
  ) {
    if (section == null) return null;
    for (final key in keys) {
      final text = _asText(section[key]?.value);
      if (text.isNotEmpty) return text;
    }
    for (final field in section.values) {
      final text = _asText(field.value);
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  List<String> _collectValues(
    Map<String, ProfileField>? section,
    List<String> keys,
  ) {
    if (section == null) return const [];
    final out = <String>[];
    void add(dynamic value) {
      if (value is List) {
        for (final v in value) {
          final text = _asText(v);
          if (text.isNotEmpty) out.add(text);
        }
      } else {
        final text = _asText(value);
        if (text.isNotEmpty) out.add(text);
      }
    }

    final ordered = <ProfileField>[
      for (final key in keys)
        if (section[key] != null) section[key]!,
      for (final entry in section.entries)
        if (!keys.contains(entry.key)) entry.value,
    ];
    for (final field in ordered) {
      add(field.value);
    }
    return out;
  }

  static String _asText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      return value
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .join('、');
    }
    return '$value'.trim();
  }
}

class _FieldKeys {
  static const name = ['name', 'full_name', 'fullName', 'real_name', '姓名'];
  static const englishName = [
    'english_name',
    'englishName',
    'en_name',
    'pinyin',
    '拼音',
  ];
  static const headline = [
    'headline',
    'title',
    'job_title',
    'position',
    '职位',
    '头衔',
  ];
  static const phone = ['phone', 'mobile', 'tel', 'telephone', '电话', '手机'];
  static const email = ['email', 'mail', 'e_mail', '邮箱', '电子邮件'];
  static const location = ['location', 'city', 'address', '所在地', '城市', '现居地'];
  static const website = ['website', 'homepage', 'blog', '主页', '个人网站'];
  static const linkedin = ['linkedin', '领英'];
  static const github = ['github', 'gitee', '码云'];
  static const summary = [
    'summary',
    'text',
    'content',
    '个人简介',
    '简介',
    '自我评价',
  ];
  static const strengths = ['strengths', 'items', 'values', '优势', '亮点'];
}
