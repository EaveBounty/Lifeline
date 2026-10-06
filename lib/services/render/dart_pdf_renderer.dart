/// PDF 渲染器（纯 Dart，全平台兜底）。
///
/// 单列、ATS 友好的朴素排版；尽量内嵌 CJK 字体，失败则用内置 Helvetica
/// 兜底并记录告警（见 [lastNotice]）。
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'font_resolver.dart';
import 'renderer.dart';

class DartPdfRenderer extends ResumeRenderer {
  DartPdfRenderer({FontResolver? fontResolver})
      : _resolver = fontResolver ?? FontResolver();

  final FontResolver _resolver;

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

  Future<List<int>> _build(
    ResumeDocument doc,
    ResolvedFont font,
    Map<String, dynamic> options,
  ) async {
    final base = font.found ? pw.Font.ttf(font.data!) : pw.Font.helvetica();
    final theme = pw.ThemeData.withFont(base: base, bold: base);

    final pageLimit = (options['pageLimit'] as num?)?.toInt() ?? 0;
    final compact = pageLimit == 1;
    final size = compact ? 9.5 : 10.0;

    final normal = pw.TextStyle(font: base, fontSize: size, lineSpacing: 2.5);
    final small = pw.TextStyle(font: base, fontSize: size - 1.0, lineSpacing: 2);
    final bold = pw.TextStyle(
      font: base,
      fontSize: size,
      fontWeight: pw.FontWeight.bold,
    );

    final pdf = pw.Document(
      theme: theme,
      title: doc.header.name.isEmpty ? 'Resume' : doc.header.name,
      creator: 'Lifeline',
      producer: 'Lifeline DartPdfRenderer',
    );

    final content = <pw.Widget>[
      _header(doc, base, bold, small),
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 0.7),
    ];

    if ((doc.summary ?? '').trim().isNotEmpty) {
      content.addAll([
        pw.SizedBox(height: 8),
        _sectionTitle(doc.language == 'en' ? 'Summary' : '个人简介', bold),
        pw.Text(doc.summary!.trim(), style: normal),
      ]);
    }

    if (doc.strengths.isNotEmpty) {
      content.addAll([
        pw.SizedBox(height: 10),
        _sectionTitle(doc.language == 'en' ? 'Highlights' : '核心优势', bold),
        for (final s in doc.strengths)
          pw.Bullet(text: s, style: normal, bulletSize: size * 0.4),
      ]);
    }

    for (final section in doc.sections) {
      if (section.items.isEmpty) continue;
      content.addAll([
        pw.SizedBox(height: 10),
        _sectionTitle(section.title, bold),
        for (final item in section.items) _item(item, bold, normal, small),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(42, 40, 42, 42),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('第 ${ctx.pageNumber} 页', style: small),
        ),
        build: (_) => content,
      ),
    );

    final data = await pdf.save();
    return data.toList();
  }

  pw.Widget _header(
    ResumeDocument doc,
    pw.Font base,
    pw.TextStyle bold,
    pw.TextStyle small,
  ) {
    final h = doc.header;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          h.name.isEmpty ? 'Resume' : h.name,
          style: pw.TextStyle(
            font: base,
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if ((h.englishName ?? '').trim().isNotEmpty)
          pw.Text(h.englishName!, style: small),
        if ((h.headline ?? '').trim().isNotEmpty)
          pw.SizedBox(
            child: pw.Text(h.headline!, style: bold),
          ),
        if (h.contacts.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            h.contacts
                .map((c) => c.label.isEmpty ? c.value : '${c.label}: ${c.value}')
                .join('  ·  '),
            style: small,
          ),
        ],
      ],
    );
  }

  pw.Widget _sectionTitle(String title, pw.TextStyle bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: bold.copyWith(fontSize: (bold.fontSize ?? 10) + 2)),
        pw.Divider(thickness: 0.6, height: 6),
      ],
    );
  }

  pw.Widget _item(
    ResumeItem item,
    pw.TextStyle bold,
    pw.TextStyle normal,
    pw.TextStyle small,
  ) {
    final meta = (item.meta ?? '').trim();
    final subtitle = (item.subtitle ?? '').trim();
    final desc = (item.description ?? '').trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            meta.isEmpty ? item.title : '${item.title}  ·  $meta',
            style: bold,
          ),
          if (subtitle.isNotEmpty) pw.Text(subtitle, style: small),
          if (desc.isNotEmpty) pw.Text(desc, style: normal),
          if (item.bullets.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            for (final bullet in item.bullets)
              pw.Bullet(
                text: bullet,
                style: normal,
                bulletSize: (normal.fontSize ?? 10) * 0.4,
              ),
          ],
          if (item.tags.isNotEmpty)
            pw.Text(item.tags.join('  '), style: small),
        ],
      ),
    );
  }
}
