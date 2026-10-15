/// 数据导出：把档案与全部记录压成干净 YAML（一行一条经历，去除分类/标签）。
///
/// 目标：纯文本、可直接复制/粘贴再编辑；不含软件内部结构（分类 slug、tags）。
library;

import '../../data/models/profile.dart';
import '../../data/models/profile_record.dart';

class DataExporter {
  const DataExporter();

  String build({
    required Profile profile,
    required List<ProfileRecord> records,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final b = StringBuffer();
    b.writeln('# 履痕数据导出');
    b.writeln('# 生成时间: ${_stamp(ts)}');
    b.writeln('# 格式: 一行一条经历（年月 + 事件）；不含分类与标签，便于复制/再编辑。');
    b.writeln('# 注意: 含个人敏感信息（可能含证件号），请妥善保管。');
    b.writeln();

    final identity = profile.sections[ProfileSections.identity] ?? const {};
    final contact = profile.sections[ProfileSections.contact] ?? const {};
    if (identity.isNotEmpty) {
      b.writeln('身份:');
      identity.forEach((k, f) => _kv(b, k, _asText(f.value)));
      b.writeln();
    }
    if (contact.isNotEmpty) {
      b.writeln('联系方式:');
      contact.forEach((k, f) => _kv(b, k, _asText(f.value)));
      b.writeln();
    }

    final summary = _firstValue(profile.sections[ProfileSections.summary]);
    if (summary.isNotEmpty) {
      b.writeln('简介: ${_q(summary)}');
      b.writeln();
    }
    final strengths = _collect(profile.sections[ProfileSections.strengths]);
    if (strengths.isNotEmpty) {
      b.writeln('亮点:');
      for (final s in strengths) {
        b.writeln('  - ${_q(s)}');
      }
      b.writeln();
    }

    final active = records.where((r) => r.status == 'active').toList()
      ..sort((a, b) {
        final da = a.startDate ?? a.endDate ?? '';
        final db = b.startDate ?? b.endDate ?? '';
        final c = db.compareTo(da);
        return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
      });

    b.writeln('时间线:  # ${active.length} 条');
    for (final r in active) {
      b.writeln('  - ${_q(_line(r))}');
    }
    return b.toString();
  }

  String _line(ProfileRecord r) {
    final date = _date(r);
    final head = [if (date.isNotEmpty) date, r.title]
        .where((e) => e.trim().isNotEmpty)
        .join(' · ');
    final org = _cleanToken(r.organization);
    final role = _cleanToken(r.role);
    final who = [if (org.isNotEmpty) org, if (role.isNotEmpty) role].join(' · ');

    final segs = <String>[];
    if (who.isNotEmpty) segs.add('（$who）');
    if (r.highlights.isNotEmpty) segs.add(r.highlights.join('；'));
    if (r.description.trim().isNotEmpty && r.highlights.isEmpty) {
      segs.add(_cleanText(r.description));
    }
    final fields = r.fields.entries
        .where((e) => '${e.value}'.trim().isNotEmpty)
        .where((e) => !_dropKeys.contains(e.key.toLowerCase()))
        .map((e) => '${e.key}: ${_asText(e.value)}')
        .join('；');
    if (fields.isNotEmpty) segs.add(fields);
    if (r.links.isNotEmpty) {
      segs.add(r.links
          .map((l) => l.label.trim().isEmpty ? l.url : '${l.label} ${l.url}')
          .join(' '));
    }
    if (segs.isEmpty) return head;
    return '$head —— ${segs.join('  |  ')}';
  }

  static const Set<String> _dropKeys = {'subcategory'};

  static const Set<String> _generic = {
    '实习单位', '单位', '公司', '机构', '组织', '部门', '公司/组织', '学校',
    '待补充', '待定', '无', '未知', '其他', 'null', 'none', 'n/a', '-',
  };

  /// 去掉占位机构词（含括号后缀）。
  static String _cleanToken(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return '';
    final bare = t.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '').trim();
    if (_generic.contains(t.toLowerCase()) ||
        _generic.contains(bare.toLowerCase())) {
      return '';
    }
    return t;
  }

  static String _cleanText(String s) =>
      s.replaceAll('实习单位', '该单位').replaceAll('贵单位', '贵公司').trim();

  String _date(ProfileRecord r) {
    final s = (r.startDate ?? '').trim();
    final e = (r.endDate ?? '').trim();
    if (s.isEmpty && e.isEmpty) return '';
    if (s.isNotEmpty && e.isNotEmpty) return '$s ~ $e';
    return s.isNotEmpty ? s : e;
  }

  String _firstValue(Map<String, ProfileField>? section) {
    if (section == null) return '';
    for (final f in section.values) {
      final t = _asText(f.value);
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  List<String> _collect(Map<String, ProfileField>? section) {
    if (section == null) return const [];
    final out = <String>[];
    for (final f in section.values) {
      final v = f.value;
      if (v is List) {
        for (final e in v) {
          final t = _asText(e);
          if (t.isNotEmpty) out.add(t);
        }
      } else {
        final t = _asText(v);
        if (t.isNotEmpty) out.add(t);
      }
    }
    return out;
  }

  void _kv(StringBuffer b, String key, String value) {
    if (value.trim().isEmpty) return;
    b.writeln('  $key: ${_q(value)}');
  }

  static String _asText(dynamic v) {
    if (v == null) return '';
    if (v is List) {
      return v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join('、');
    }
    return '$v'.trim();
  }

  /// 统一双引号标量，转义反斜杠/引号/换行，保证 YAML 安全。
  static String _q(String s) {
    final esc = s
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\r', ' ')
        .replaceAll('\n', r'\n');
    return '"$esc"';
  }

  static String _stamp(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
