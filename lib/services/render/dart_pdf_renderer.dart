/// PDF 渲染器（纯 Dart，全平台主力）。
///
/// 内嵌打包的 OFL 中英子集字体（按版式选衬线/无衬线），彻底避免中文乱码；
/// 依据 [ResumeTemplate.layout] 实现 single / two-column / academic / creative
/// / compact 版式；渲染条目 `fields`/`links`，并在需要时追加「参考材料附录」页。
library;

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants.dart';
import '../../core/platform/io_platform.dart';
import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'renderer.dart';
import 'resume_fonts.dart';
import 'templates.dart';

class DartPdfRenderer extends ResumeRenderer {
  DartPdfRenderer({this.templateId});

  /// 默认模板 id；可被 `options['templateId']` 覆盖。
  final String? templateId;

  String? _lastNotice;

  /// 最近一次渲染的字体/降级说明（供上层向用户提示）。
  String? get lastNotice => _lastNotice;

  @override
  String get format => 'pdf';

  @override
  String get extension => 'pdf';

  @override
  Future<Result<List<int>>> render(
    ResumeDocument doc, {
    Map<String, dynamic> options = const {},
  }) async {
    final template = ResumeTemplates.byId(
      (options['templateId'] as String?) ?? templateId,
    );
    final fonts = await ResumeFontLoader().load(serif: _isSerif(template));
    final images = await _preloadImages(doc, options['syncRoot'] as String?);

    try {
      final bytes = await _build(doc, template, fonts, options, images);
      _lastNotice = fonts.embedded
          ? 'PDF 已内嵌字体：${fonts.source}'
          : '未找到中文字体，已回退内置 Helvetica，中文可能缺字。';
      return Ok(bytes);
    } catch (e) {
      // 字体嵌入等异常：退回内置拉丁字体，尽量出图。
      try {
        final fallback = ResumeFonts(
          regular: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          source: 'helvetica',
        );
        final bytes = await _build(doc, template, fallback, options, images);
        _lastNotice = '字体嵌入失败，已回退内置字体；中文可能缺字。';
        return Ok(bytes);
      } catch (e2) {
        return Err('PDF 渲染失败: $e2', e2);
      }
    }
  }

  bool _isSerif(ResumeTemplate t) =>
      t.id == 'elegant-serif' ||
      t.id == 'academic-cv' ||
      t.layout == 'academic' ||
      t.layout == 'elegant';

  /// 预加载附录图片（相对同步根），避免在同步的 build 回调中做 IO。
  Future<Map<String, pw.MemoryImage>> _preloadImages(
    ResumeDocument doc,
    String? syncRoot,
  ) async {
    final out = <String, pw.MemoryImage>{};
    if (syncRoot == null) return out;
    for (final entry in doc.appendix) {
      for (final rel in entry.materials) {
        if (!AttachmentTypes.isImage(rel)) continue;
        try {
          final file = File(p.join(syncRoot, rel));
          if (!await file.exists()) continue;
          out[rel] = pw.MemoryImage(await file.readAsBytes());
        } catch (_) {
          // 忽略无法读取的图片。
        }
      }
    }
    return out;
  }

  /// 版式归一化：未知/优雅/极简映射到最接近的版式。
  String _layoutOf(String layout) => switch (layout) {
        'two-column' => 'two-column',
        'academic' => 'academic',
        'creative' => 'creative',
        'compact' => 'compact',
        _ => 'single',
      };

  Future<List<int>> _build(
    ResumeDocument doc,
    ResumeTemplate template,
    ResumeFonts fonts,
    Map<String, dynamic> options,
    Map<String, pw.MemoryImage> images,
  ) async {
    final layout = _layoutOf(template.layout);
    final accent = PdfColor.fromInt(template.accentArgb);
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      fontFallback: fonts.fallback.isEmpty ? null : fonts.fallback,
    );

    final pageLimit = (options['pageLimit'] as num?)?.toInt() ?? 0;
    final compact = layout == 'compact' || pageLimit == 1;
    final size = compact ? 9.0 : 10.0;
    final st = _Styles(
      reg: fonts.regular,
      bld: fonts.bold,
      size: size,
      accent: accent,
    );

    final pdf = pw.Document(
      theme: theme,
      title: doc.header.name.isEmpty ? 'Resume' : doc.header.name,
      creator: 'Lifeline',
      producer: 'Lifeline DartPdfRenderer (${template.id})',
    );

    final sections = ResumeTemplates.orderSections(doc.sections, template.id);
    final content = <pw.Widget>[];

    switch (layout) {
      case 'two-column':
        if (_bulk(doc) <= 26) {
          content.addAll(_twoColumn(doc, sections, st));
        } else {
          content.addAll(_single(doc, sections, st));
        }
      case 'academic':
        content.add(_headerCentered(doc, st));
        content.addAll(_academicBody(doc, sections, st));
      case 'creative':
        content.add(_headerBand(doc, st));
        content.addAll(_creativeBody(doc, sections, st));
      case 'compact':
        content.add(_headerInline(doc, st));
        content.addAll(_single(doc, sections, st, plainTitles: true));
      default:
        content.addAll(_single(doc, sections, st));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(42, 40, 42, 42),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('第 ${ctx.pageNumber} 页', style: st.small),
        ),
        build: (_) => content,
      ),
    );

    if (doc.appendix.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.fromLTRB(42, 40, 42, 42),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('附录 · 第 ${ctx.pageNumber} 页', style: st.small),
          ),
          build: (_) => _appendixBlock(doc, st, images),
        ),
      );
    }

    final data = await pdf.save();
    return data.toList();
  }

  // ---------------------------------------------------------------------------
  // 参考材料附录
  // ---------------------------------------------------------------------------

  List<pw.Widget> _appendixBlock(
    ResumeDocument doc,
    _Styles st,
    Map<String, pw.MemoryImage> images,
  ) {
    final en = doc.language == 'en';
    final out = <pw.Widget>[
      _sectionTitle(en ? 'Appendix · Supporting Materials' : '附录 · 参考材料',
          st, _TitleStyle.underline),
      pw.SizedBox(height: 4),
      pw.Text(
        en
            ? 'Materials below support the claims marked [A-x] in the resume.'
            : '以下材料用于佐证简历中以〔A-x〕标注的经历/声称。',
        style: st.small,
      ),
    ];
    for (final entry in doc.appendix) {
      out.add(pw.SizedBox(height: 10));
      out.add(pw.Text('[${entry.label}] ${entry.title}', style: st.bold));
      if ((entry.note ?? '').trim().isNotEmpty) {
        out.add(pw.Text(entry.note!.trim(), style: st.small));
      }
      if (entry.materials.isEmpty) {
        out.add(pw.Text(en ? '(no material)' : '（暂无可附材料）', style: st.small));
        continue;
      }
      for (final rel in entry.materials) {
        final img = images[rel];
        if (img != null) {
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Container(
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(img, height: 190, fit: pw.BoxFit.contain),
            ),
          ));
          out.add(pw.Text(p.basename(rel), style: st.small));
        } else {
          out.add(pw.Text('• ${p.basename(rel)}'
              '${en ? ' (file)' : '（非图片，见文件）'}', style: st.small));
        }
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // 版式 body
  // ---------------------------------------------------------------------------

  List<pw.Widget> _single(
    ResumeDocument doc,
    List<ResumeSection> sections,
    _Styles st, {
    bool plainTitles = false,
  }) {
    final out = <pw.Widget>[_headerClassic(doc, st), pw.SizedBox(height: 8)];
    final titleStyle = plainTitles ? _TitleStyle.plain : _TitleStyle.underline;
    out.addAll(_summaryAndStrengths(doc, st));
    for (final s in sections) {
      out.addAll(_sectionBlock(s, st, titleStyle, variant: _ItemVariant.plain));
    }
    return out;
  }

  List<pw.Widget> _academicBody(
    ResumeDocument doc,
    List<ResumeSection> sections,
    _Styles st,
  ) {
    final out = <pw.Widget>[..._summaryAndStrengths(doc, st)];
    for (final s in sections) {
      out.addAll(
        _sectionBlock(s, st, _TitleStyle.centered, variant: _ItemVariant.plain),
      );
    }
    return out;
  }

  List<pw.Widget> _creativeBody(
    ResumeDocument doc,
    List<ResumeSection> sections,
    _Styles st,
  ) {
    final out = <pw.Widget>[..._summaryAndStrengths(doc, st)];
    for (final s in sections) {
      out.addAll(
        _sectionBlock(s, st, _TitleStyle.bar, variant: _ItemVariant.bordered),
      );
    }
    return out;
  }

  List<pw.Widget> _twoColumn(
    ResumeDocument doc,
    List<ResumeSection> sections,
    _Styles st,
  ) {
    final sideKeys = {
      'skills', 'certificates', 'languages', 'awards', 'tags',
      'interests', 'links', 'honors',
    };
    bool isSide(ResumeSection s) {
      final k = '${s.key} ${s.title}'.toLowerCase();
      return sideKeys.any(k.contains);
    }

    final main = sections.where((s) => !isSide(s)).toList();
    final side = sections.where(isSide).toList();
    final out = <pw.Widget>[_headerClassic(doc, st), pw.SizedBox(height: 8)];
    if ((doc.summary ?? '').trim().isNotEmpty) {
      out.addAll([
        _sectionTitle(doc.language == 'en' ? 'Summary' : '个人简介', st,
            _TitleStyle.underline),
        pw.Text(doc.summary!.trim(), style: st.normal),
        pw.SizedBox(height: 8),
      ]);
    }
    final left = <pw.Widget>[
      for (final s in main)
        ..._sectionBlock(s, st, _TitleStyle.underline, variant: _ItemVariant.plain),
    ];
    final right = <pw.Widget>[
      if (doc.strengths.isNotEmpty) ...[
        _sectionTitle(doc.language == 'en' ? 'Highlights' : '核心优势', st,
            _TitleStyle.bar),
        for (final s in doc.strengths)
          pw.Bullet(text: s, style: st.small, bulletSize: st.size * 0.4),
        pw.SizedBox(height: 8),
      ],
      for (final s in side)
        ..._sectionBlock(s, st, _TitleStyle.bar, variant: _ItemVariant.plain),
    ];
    out.add(pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: left,
        )),
        pw.SizedBox(width: 16),
        pw.Expanded(child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: right,
        )),
      ],
    ));
    return out;
  }

  // ---------------------------------------------------------------------------
  // header 变体
  // ---------------------------------------------------------------------------

  pw.Widget _headerClassic(ResumeDocument doc, _Styles st) {
    final h = doc.header;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_name(doc),
            style: pw.TextStyle(
              font: st.bld,
              fontSize: st.nameSize,
              fontWeight: pw.FontWeight.bold,
              color: st.accent,
            )),
        if ((h.englishName ?? '').trim().isNotEmpty)
          pw.Text(h.englishName!, style: st.small),
        if ((h.headline ?? '').trim().isNotEmpty)
          pw.Text(h.headline!, style: st.bold),
        if (h.contacts.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(_contacts(h), style: st.small),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 1.0, color: st.accent, height: 2),
        ] else
          pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _headerCentered(ResumeDocument doc, _Styles st) {
    final h = doc.header;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(_name(doc),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: st.bld,
              fontSize: st.nameSize,
              fontWeight: pw.FontWeight.bold,
            )),
        if ((h.englishName ?? '').trim().isNotEmpty)
          pw.Text(h.englishName!, style: st.small),
        if ((h.headline ?? '').trim().isNotEmpty)
          pw.Text(h.headline!, textAlign: pw.TextAlign.center, style: st.bold),
        if (h.contacts.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(_contacts(h), textAlign: pw.TextAlign.center, style: st.small),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.0, color: st.accent, height: 2),
      ],
    );
  }

  pw.Widget _headerBand(ResumeDocument doc, _Styles st) {
    final h = doc.header;
    final onAccent = pw.TextStyle(
      font: st.reg,
      color: PdfColors.white,
      fontSize: st.size,
    );
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: st.accent,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_name(doc),
              style: pw.TextStyle(
                font: st.bld,
                fontSize: st.nameSize + 1,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              )),
          if ((h.englishName ?? '').trim().isNotEmpty)
            pw.Text(h.englishName!, style: onAccent),
          if ((h.headline ?? '').trim().isNotEmpty)
            pw.Text(h.headline!,
                style: onAccent.copyWith(fontWeight: pw.FontWeight.bold)),
          if (h.contacts.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(_contacts(h), style: onAccent.copyWith(fontSize: st.size - 1)),
          ],
        ],
      ),
    );
  }

  pw.Widget _headerInline(ResumeDocument doc, _Styles st) {
    final h = doc.header;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(_name(doc),
                style: pw.TextStyle(
                  font: st.bld,
                  fontSize: st.nameSize - 3,
                  fontWeight: pw.FontWeight.bold,
                  color: st.accent,
                )),
            if ((h.headline ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Text(h.headline!, style: st.bold)),
            ],
          ],
        ),
        if ((h.englishName ?? '').trim().isNotEmpty)
          pw.Text(h.englishName!, style: st.small),
        if (h.contacts.isNotEmpty) pw.Text(_contacts(h), style: st.small),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.8, color: st.accent, height: 2),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 通用块
  // ---------------------------------------------------------------------------

  List<pw.Widget> _summaryAndStrengths(ResumeDocument doc, _Styles st) {
    final out = <pw.Widget>[];
    if ((doc.summary ?? '').trim().isNotEmpty) {
      out.addAll([
        pw.SizedBox(height: 8),
        _sectionTitle(doc.language == 'en' ? 'Summary' : '个人简介', st,
            _TitleStyle.underline),
        pw.Text(doc.summary!.trim(), style: st.normal),
      ]);
    }
    if (doc.strengths.isNotEmpty) {
      out.addAll([
        pw.SizedBox(height: 10),
        _sectionTitle(doc.language == 'en' ? 'Highlights' : '核心优势', st,
            _TitleStyle.underline),
        for (final s in doc.strengths)
          pw.Bullet(text: s, style: st.normal, bulletSize: st.size * 0.4),
      ]);
    }
    return out;
  }

  List<pw.Widget> _sectionBlock(
    ResumeSection section,
    _Styles st,
    _TitleStyle titleStyle, {
    required _ItemVariant variant,
  }) {
    if (section.items.isEmpty) return const [];
    return [
      pw.SizedBox(height: st.compact ? 7 : 10),
      _sectionTitle(section.title, st, titleStyle),
      for (final item in section.items) _item(item, st, variant),
    ];
  }

  pw.Widget _sectionTitle(String title, _Styles st, _TitleStyle style) {
    final t = st.title.copyWith(color: style == _TitleStyle.bar ? st.accent : null);
    switch (style) {
      case _TitleStyle.centered:
        return pw.Column(
          children: [
            pw.Text(title, textAlign: pw.TextAlign.center, style: t),
            pw.SizedBox(height: 2),
            pw.Divider(thickness: 0.8, color: st.accent, height: 4),
          ],
        );
      case _TitleStyle.bar:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            children: [
              pw.Container(width: 4, height: st.titleSize, color: st.accent),
              pw.SizedBox(width: 6),
              pw.Text(title, style: t),
            ],
          ),
        );
      case _TitleStyle.plain:
        return pw.Text(title, style: t);
      case _TitleStyle.underline:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: t),
            pw.Divider(thickness: 0.6, color: st.accent, height: 6),
          ],
        );
    }
  }

  pw.Widget _item(ResumeItem item, _Styles st, _ItemVariant variant) {
    final meta = (item.meta ?? '').trim();
    final subtitle = (item.subtitle ?? '').trim();
    final desc = (item.description ?? '').trim();
    final refSuffix =
        item.appendixRefs.isEmpty ? '' : '  〔见附录 ${item.appendixRefs.join(', ')}〕';
    final fieldLine = item.fields.entries
        .where((e) => '${e.value}'.trim().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .join('  ·  ');
    final linkLine = item.links
        .map((l) => l.label.trim().isEmpty ? l.url : '${l.label}: ${l.url}')
        .join('  ·  ');
    final column = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${item.title}${meta.isEmpty ? '' : '  ·  $meta'}$refSuffix',
            style: st.bold),
        if (subtitle.isNotEmpty) pw.Text(subtitle, style: st.small),
        if (fieldLine.isNotEmpty)
          pw.Text(fieldLine, style: st.small.copyWith(color: st.accent)),
        if (desc.isNotEmpty) pw.Text(desc, style: st.normal),
        if (item.bullets.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          for (final bullet in item.bullets)
            pw.Bullet(
              text: bullet,
              style: st.normal,
              bulletSize: st.size * 0.4,
            ),
        ],
        if (linkLine.isNotEmpty) pw.Text(linkLine, style: st.small),
        if (item.tags.isNotEmpty)
          pw.Text(item.tags.join('  '),
              style: st.small.copyWith(color: st.accent)),
      ],
    );
    final top = st.compact ? 3.0 : 5.0;
    if (variant == _ItemVariant.bordered) {
      return pw.Container(
        margin: pw.EdgeInsets.only(top: top),
        padding: const pw.EdgeInsets.only(left: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: st.accent, width: 1.5),
          ),
        ),
        child: column,
      );
    }
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: top),
      child: column,
    );
  }

  // ---------------------------------------------------------------------------
  // 体量估算
  // ---------------------------------------------------------------------------

  int _bulk(ResumeDocument doc) {
    var n = 0;
    for (final s in doc.sections) {
      n += s.items.length;
      for (final i in s.items) {
        n += i.bullets.length;
      }
    }
    return n;
  }

  String _name(ResumeDocument doc) =>
      doc.header.name.isEmpty ? 'Resume' : doc.header.name;

  String _contacts(ResumeHeader h) => h.contacts
      .map((c) => c.label.isEmpty ? c.value : '${c.label}: ${c.value}')
      .join('  ·  ');
}

/// 版式样式集合。
enum _TitleStyle { underline, bar, centered, plain }

/// 条目装饰变体。
enum _ItemVariant { plain, bordered }

class _Styles {
  _Styles({
    required this.reg,
    required this.bld,
    required this.size,
    required this.accent,
  });

  final pw.Font reg;
  final pw.Font bld;
  final double size;
  final PdfColor accent;

  bool get compact => size <= 9.0;
  double get titleSize => size + 2;
  double get nameSize => compact ? 17 : 22;

  pw.TextStyle get normal =>
      pw.TextStyle(font: reg, fontSize: size, lineSpacing: compact ? 1.6 : 2.5);
  pw.TextStyle get small =>
      pw.TextStyle(font: reg, fontSize: size - 1.0, lineSpacing: compact ? 1.2 : 2);
  pw.TextStyle get bold => pw.TextStyle(
        font: bld,
        fontSize: size,
        fontWeight: pw.FontWeight.bold,
      );
  pw.TextStyle get title => pw.TextStyle(
        font: bld,
        fontSize: titleSize,
        fontWeight: pw.FontWeight.bold,
      );
}
