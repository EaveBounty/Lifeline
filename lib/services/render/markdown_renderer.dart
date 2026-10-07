/// Markdown 渲染器：IR -> GFM 风格纯文本，供二次加工与版本对比。
library;

import 'dart:convert';

import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'renderer.dart';
import 'templates.dart';

class MarkdownRenderer extends ResumeRenderer {
  MarkdownRenderer({this.templateId});

  /// 默认模板 id；可被 `options['templateId']` 覆盖。
  final String? templateId;

  @override
  String get format => 'md';

  @override
  String get extension => 'md';

  @override
  Future<Result<List<int>>> render(
    ResumeDocument doc, {
    Map<String, dynamic> options = const {},
  }) async {
    final tid = (options['templateId'] as String?) ?? templateId;
    final md = renderString(doc, templateId: tid);
    return Ok(utf8.encode(md));
  }

  /// 纯函数：IR -> Markdown 字符串；template 影响章节顺序与标题层级。
  String renderString(ResumeDocument doc, {String? templateId}) {
    final template = ResumeTemplates.byId(templateId);
    final sections = ResumeTemplates.orderSections(doc.sections, template.id);
    // academic/creative 用 H2 作主标题，其余用 H2 亦保持兼容；仅章节顺序随模板变化。
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

    for (final section in sections) {
      if (section.items.isEmpty) continue;
      b.writeln();
      b.writeln('## ${section.title}');
      for (final item in section.items) {
        b.writeln();
        _writeItem(b, item);
      }
    }

    if (doc.appendix.isNotEmpty) {
      b.writeln();
      b.writeln('## 附录 · 参考材料');
      for (final entry in doc.appendix) {
        b.writeln();
        b.writeln('**[${entry.label}] ${entry.title}**');
        if ((entry.note ?? '').trim().isNotEmpty) b.writeln(entry.note!.trim());
        for (final rel in entry.materials) {
          b.writeln('- `$rel`');
        }
      }
    }

    return b.toString();
  }

  void _writeItem(StringBuffer b, ResumeItem item) {
    final title = item.title.trim();
    final meta = (item.meta ?? '').trim();
    final refs = item.appendixRefs.isEmpty
        ? ''
        : '  〔见附录 ${item.appendixRefs.join(', ')}〕';
    b.write('### $title');
    if (meta.isNotEmpty) b.write('  ·  $meta');
    b.write(refs);
    b.writeln();

    final subtitle = (item.subtitle ?? '').trim();
    if (subtitle.isNotEmpty) b.writeln('*$subtitle*');

    final fieldLine = item.fields.entries
        .where((e) => '${e.value}'.trim().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .join('  ·  ');
    if (fieldLine.isNotEmpty) b.writeln('`$fieldLine`');

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

    if (item.links.isNotEmpty) {
      b.writeln();
      b.writeln(item.links
          .map((l) => l.label.trim().isEmpty
              ? '[${l.url}](${l.url})'
              : '[${l.label}](${l.url})')
          .join(' · '));
    }

    if (item.tags.isNotEmpty) {
      b.writeln();
      b.writeln(item.tags.map((t) => '`${t.trim()}`').join(' '));
    }
  }
}
