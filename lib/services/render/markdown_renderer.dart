/// Markdown 渲染器：IR -> GFM 风格纯文本，供二次加工与版本对比。
library;

import 'dart:convert';

import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'renderer.dart';

class MarkdownRenderer extends ResumeRenderer {
  @override
  String get format => 'md';

  @override
  String get extension => 'md';

  @override
  Future<Result<List<int>>> render(
    ResumeDocument doc, {
    Map<String, dynamic> options = const {},
  }) async {
    final md = renderString(doc);
    return Ok(utf8.encode(md));
  }

  /// 纯函数：IR -> Markdown 字符串。
  String renderString(ResumeDocument doc) {
    final b = StringBuffer();
    final h = doc.header;

    if (h.name.isNotEmpty) b.writeln('# ${h.name}');
    if ((h.englishName ?? '').trim().isNotEmpty) {
      b.writeln('_${h.englishName}_');
    }
    if ((h.headline ?? '').trim().isNotEmpty) b.writeln('**${h.headline}**');

    if (h.contacts.isNotEmpty) {
      final parts = h.contacts.map((c) {
        final label = c.label.isEmpty ? '' : '${c.label}: ';
        final value = (c.url ?? '').trim().isEmpty
            ? c.value
            : '[${c.value}](${c.url})';
        return '$label$value';
      }).join(' · ');
      b.writeln();
      b.writeln(parts);
    }

    if ((doc.summary ?? '').trim().isNotEmpty) {
      b.writeln();
      b.writeln('## 简介');
      b.writeln();
      b.writeln(doc.summary!.trim());
    }

    if (doc.strengths.isNotEmpty) {
      b.writeln();
      b.writeln('## 核心优势');
      b.writeln();
      for (final s in doc.strengths) {
        b.writeln('- ${s.trim()}');
      }
    }

    for (final section in doc.sections) {
      if (section.items.isEmpty) continue;
      b.writeln();
      b.writeln('## ${section.title}');
      for (final item in section.items) {
        b.writeln();
        _writeItem(b, item);
      }
    }

    return b.toString();
  }

  void _writeItem(StringBuffer b, ResumeItem item) {
    final title = item.title.trim();
    final meta = (item.meta ?? '').trim();
    b.write('### $title');
    if (meta.isNotEmpty) b.write('  ·  $meta');
    b.writeln();

    final subtitle = (item.subtitle ?? '').trim();
    if (subtitle.isNotEmpty) b.writeln('*$subtitle*');

    final desc = (item.description ?? '').trim();
    if (desc.isNotEmpty) {
      b.writeln();
      b.writeln(desc);
    }

    if (item.bullets.isNotEmpty) {
      b.writeln();
      for (final bullet in item.bullets) {
        b.writeln('- ${bullet.trim()}');
      }
    }

    if (item.tags.isNotEmpty) {
      b.writeln();
      b.writeln(item.tags.map((t) => '`${t.trim()}`').join(' '));
    }
  }
}
