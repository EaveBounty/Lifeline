/// PDF 渲染器（纯 Dart，全平台兜底）。
///
/// 依据 [ResumeTemplate.layout] 实现多种版式：single / two-column / academic
/// / creative / compact；elegant、mono 等映射到最接近的版式。尽量内嵌 CJK
/// 字体，失败则用内置 Helvetica 兜底并记录告警（见 [lastNotice]）。
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'font_resolver.dart';
import 'renderer.dart';
import 'templates.dart';

class DartPdfRenderer extends ResumeRenderer {
  DartPdfRenderer({FontResolver? fontResolver, this.templateId})
      : _resolver = fontResolver ?? FontResolver();

  final FontResolver _resolver;

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
    final font = await _resolver.resolveCjk();
    final needsCjk = RenderText.hasCjk(RenderText.allText(doc));

    try {
      final bytes = await _build(doc, font, options);
      _lastNotice = _notice(font, needsCjk);
      return Ok(bytes);
    } catch (_) {
      // 字体嵌入导致失败：退到内置拉丁字体。
      try {
        final bytes = await _build(doc, ResolvedFont.none, options);
        _lastNotice = font.found
            ? 'CJK 字体嵌入失败，已回退内置字体；中文可能缺字。'
            : _notice(font, needsCjk);
        return Ok(bytes);
      } catch (e) {
        return Err('PDF 渲染失败: $e', e);
      }
    }
  }

  String _notice(ResolvedFont font, bool needsCjk) {
    if (font.found) return 'PDF 已内嵌字体：${font.source}';
    if (needsCjk) return '未找到 CJK 字体，已用内置 Helvetica 兜底，中文可能缺字。';
    return 'PDF 使用内置拉丁字体。';
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
    ResolvedFont font,
    Map<String, dynamic> options,
  ) async {
    final template = ResumeTemplates.byId(
      (options['templateId'] as String?) ?? templateId,
    );
    final layout = _layoutOf(template.layout);
    final accent = PdfColor.fromInt(template.accentArgb);
    final base = font.found ? pw.Font.ttf(font.data!) : pw.Font.helvetica();
    final theme = pw.ThemeData.withFont(base: base, bold: base);

    final pageLimit = (options['pageLimit'] as num?)?.toInt() ?? 0;
    final compact = layout == 'compact' || pageLimit == 1;
    final size = compact ? 9.0 : 10.0;
    final st = _Styles(base: base, size: size, accent: accent);

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
        // 仅当内容较小时用双栏，避免跨页无法拆分导致排版异常。
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

    final data = await pdf.save();
    return data.toList();
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
              font: st.base,
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
              font: st.base,
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
      font: st.base,
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
                font: st.base,
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
                  font: st.base,
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
    final column = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(meta.isEmpty ? item.title : '${item.title}  ·  $meta',
            style: st.bold),
        if (subtitle.isNotEmpty) pw.Text(subtitle, style: st.small),
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

  /// 粗略估算正文体量（条目 + bullet 数），用于双栏安全判断。
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
  _Styles({required this.base, required this.size, required this.accent});

  final pw.Font base;
  final double size;
  final PdfColor accent;

  bool get compact => size <= 9.0;
  double get titleSize => size + 2;
  double get nameSize => compact ? 17 : 22;

  pw.TextStyle get normal =>
      pw.TextStyle(font: base, fontSize: size, lineSpacing: compact ? 1.6 : 2.5);
  pw.TextStyle get small =>
      pw.TextStyle(font: base, fontSize: size - 1.0, lineSpacing: compact ? 1.2 : 2);
  pw.TextStyle get bold => pw.TextStyle(
        font: base,
        fontSize: size,
        fontWeight: pw.FontWeight.bold,
      );
  pw.TextStyle get title => pw.TextStyle(
        font: base,
        fontSize: titleSize,
        fontWeight: pw.FontWeight.bold,
      );
}
