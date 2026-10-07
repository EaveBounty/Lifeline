/// DOCX 渲染器：手写最小 OOXML，单列 ATS 友好，纯 Dart 跨平台。
///
/// DOCX = ZIP(OOXML)。仅生成必需部件：
/// `[Content_Types].xml` / `_rels/.rels` / `word/document.xml`
/// / `word/_rels/document.xml.rels` / `word/styles.xml`。
library;

// archive 为 pdf 包的传递依赖，已在依赖树中（冻结约束：不改 pubspec）。
// ignore: depend_on_referenced_packages
import 'package:archive/archive.dart';

import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'renderer.dart';
import 'templates.dart';

class DocxRenderer extends ResumeRenderer {
  DocxRenderer({this.templateId});

  /// 默认模板 id；可被 `options['templateId']` 覆盖。
  final String? templateId;

  String _accentHex = '2E5C8A';
  bool _modernStyle = false;

  @override
  String get format => 'docx';

  @override
  String get extension => 'docx';

  @override
  Future<Result<List<int>>> render(
    ResumeDocument doc, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      final template = ResumeTemplates.byId(
        (options['templateId'] as String?) ?? templateId,
      );
      final archive = Archive()
        ..add(ArchiveFile.string('[Content_Types].xml', _contentTypes))
        ..add(ArchiveFile.string('_rels/.rels', _rootRels))
        ..add(ArchiveFile.string(
            'word/_rels/document.xml.rels', _documentRels))
        ..add(ArchiveFile.string('word/styles.xml', _styles))
        ..add(ArchiveFile.string(
            'word/document.xml',
            _document(doc, _hex(template.accentArgb), _modern(template))));
      final bytes = ZipEncoder().encode(archive);
      return Ok(bytes);
    } catch (e) {
      return Err('DOCX 生成失败: $e', e);
    }
  }

  /// 是否采用「modern」标题样式（仍单列，仅配色/下边框，兼容 ATS）。
  bool _modern(ResumeTemplate t) =>
      t.id != ResumeTemplates.defaultId && t.layout != 'elegant';

  String _hex(int argb) =>
      (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

  String _document(ResumeDocument doc, String accent, bool modern) {
    _accentHex = accent;
    _modernStyle = modern;
    final b = StringBuffer();
    b.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    b.writeln('<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    b.writeln('<w:body>');

    final h = doc.header;
    b.writeln(_para(
      [ _Run(h.name.isEmpty ? 'Resume' : h.name, bold: true, size: 40, color: _accentHex) ],
      style: 'Title',
    ));
    if ((h.englishName ?? '').trim().isNotEmpty) {
      b.writeln(_para([_Run(h.englishName!, size: 22)], center: true));
    }
    if ((h.headline ?? '').trim().isNotEmpty) {
      b.writeln(_para([_Run(h.headline!, bold: true, size: 22)], center: true));
    }
    if (h.contacts.isNotEmpty) {
      b.writeln(_para(
        [
          _Run(
            h.contacts
                .map((c) => c.label.isEmpty ? c.value : '${c.label}: ${c.value}')
                .join('  ·  '),
            size: 18,
          ),
        ],
        center: true,
      ));
    }

    if ((doc.summary ?? '').trim().isNotEmpty) {
      b.writeln(_heading(doc.language == 'en' ? 'Summary' : '个人简介'));
      b.writeln(_para([_Run(doc.summary!.trim())]));
    }

    if (doc.strengths.isNotEmpty) {
      b.writeln(_heading(doc.language == 'en' ? 'Highlights' : '核心优势'));
      for (final s in doc.strengths) {
        b.writeln(_bullet(s));
      }
    }

    for (final section in doc.sections) {
      if (section.items.isEmpty) continue;
      b.writeln(_heading(section.title));
      for (final item in section.items) {
        final meta = (item.meta ?? '').trim();
        final refs = item.appendixRefs.isEmpty
            ? ''
            : '  〔见附录 ${item.appendixRefs.join(', ')}〕';
        b.writeln(_para(
          [
            _Run(item.title, bold: true, size: 24),
            if (meta.isNotEmpty) _Run('  ·  $meta', size: 20),
            if (refs.isNotEmpty) _Run(refs, size: 18),
          ],
          style: 'Heading2',
        ));
        final subtitle = (item.subtitle ?? '').trim();
        if (subtitle.isNotEmpty) {
          b.writeln(_para([_Run(subtitle, italic: true, size: 20)]));
        }
        final fieldLine = item.fields.entries
            .where((e) => '${e.value}'.trim().isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .join('  ·  ');
        if (fieldLine.isNotEmpty) {
          b.writeln(_para([_Run(fieldLine, size: 18)]));
        }
        final desc = (item.description ?? '').trim();
        if (desc.isNotEmpty) b.writeln(_para([_Run(desc)]));
        for (final bullet in item.bullets) {
          b.writeln(_bullet(bullet));
        }
        if (item.links.isNotEmpty) {
          b.writeln(_para([
            _Run(item.links
                .map((l) => l.label.trim().isEmpty
                    ? l.url
                    : '${l.label}: ${l.url}')
                .join('  ·  '),
                size: 18),
          ]));
        }
        if (item.tags.isNotEmpty) {
          b.writeln(_para([_Run(item.tags.join('  '), size: 18)]));
        }
      }
    }

    if (doc.appendix.isNotEmpty) {
      b.writeln(_heading(doc.language == 'en' ? 'Appendix' : '附录 · 参考材料'));
      for (final entry in doc.appendix) {
        b.writeln(_para([_Run('[${entry.label}] ${entry.title}', bold: true, size: 20)]));
        if ((entry.note ?? '').trim().isNotEmpty) {
          b.writeln(_para([_Run(entry.note!.trim(), size: 18)]));
        }
        for (final rel in entry.materials) {
          b.writeln(_bullet(rel));
        }
      }
    }

    // 分节属性（页面尺寸/页边距）。
    b.writeln('<w:sectPr>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
        'w:header="709" w:footer="709" w:gutter="0"/>'
        '</w:sectPr>');
    b.writeln('</w:body>');
    b.writeln('</w:document>');
    return b.toString();
  }

  String _heading(String text) {
    final run = [_Run(text, bold: true, size: 28, color: _modernStyle ? _accentHex : null)];
    if (!_modernStyle) return _para(run, style: 'Heading1');
    // modern：彩色标题 + 底部强调色边框，仍为单列、ATS 友好。
    return _para(
      run,
      style: 'Heading1',
      borderBottomColor: _accentHex,
    );
  }

  String _bullet(String text) => _para(
        [_Run('•  $text')],
        style: 'ListParagraph',
      );

  String _para(
    List<_Run> runs, {
    String? style,
    bool center = false,
    String? borderBottomColor,
  }) {
    final b = StringBuffer('<w:p>');
    final props = StringBuffer();
    if (style != null) props.write('<w:pStyle w:val="${_esc(style)}"/>');
    if (center) props.write('<w:jc w:val="center"/>');
    if (borderBottomColor != null) {
      props.write('<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="2" '
          'w:color="$borderBottomColor"/></w:pBdr>');
    }
    if (props.isNotEmpty) b.write('<w:pPr>$props</w:pPr>');
    for (final run in runs) {
      b.write('<w:r><w:rPr>');
      if (run.bold) b.write('<w:b/>');
      if (run.italic) b.write('<w:i/>');
      if (run.color != null) b.write('<w:color w:val="${run.color}"/>');
      if (run.size != null) {
        b.write('<w:sz w:val="${run.size}"/><w:szCs w:val="${run.size}"/>');
      }
      b.write('</w:rPr>');
      b.write('<w:t xml:space="preserve">${_esc(run.text)}</w:t></w:r>');
    }
    b.write('</w:p>');
    return b.toString();
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';

  static const String _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

  static const String _documentRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static const String _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:docDefaults>'
      '<w:rPrDefault><w:rPr>'
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="SimSun"/>'
      '<w:sz w:val="21"/><w:szCs w:val="21"/>'
      '</w:rPr></w:rPrDefault>'
      '<w:pPrDefault><w:pPr>'
      '<w:spacing w:after="80" w:line="276" w:lineRule="auto"/>'
      '</w:pPr></w:pPrDefault>'
      '</w:docDefaults>'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
      '<w:name w:val="Normal"/></w:style>'
      '<w:style w:type="paragraph" w:styleId="Title">'
      '<w:name w:val="Title"/><w:basedOn w:val="Normal"/>'
      '<w:pPr><w:spacing w:after="60"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="40"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Heading1">'
      '<w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>'
      '<w:pPr><w:spacing w:before="200" w:after="60"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Heading2">'
      '<w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>'
      '<w:pPr><w:spacing w:before="120" w:after="40"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="ListParagraph">'
      '<w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/>'
      '<w:pPr><w:ind w:left="360" w:hanging="180"/></w:pPr></w:style>'
      '</w:styles>';
}

class _Run {
  const _Run(this.text, {this.bold = false, this.italic = false, this.size, this.color});
  final String text;
  final bool bold;
  final bool italic;
  final int? size;
  final String? color;
}
