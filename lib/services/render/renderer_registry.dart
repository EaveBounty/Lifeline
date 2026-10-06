/// 渲染器注册表：按格式与模板返回候选渲染器（有序，支持优雅降级）。
library;

import 'dart_pdf_renderer.dart';
import 'docx_renderer.dart';
import 'markdown_renderer.dart';
import 'renderer.dart';
import 'templates.dart';
import 'typst_renderer.dart';

/// 返回 [format] 的渲染器列表；调用方按顺序尝试直到成功。
///
/// - `pdf`：模板有 Typst 实现且 [preferTypstPdf] 为真时 Typst 优先，否则
///   DartPdf 优先；两者互为兜底。模板无 Typst 实现时仅返回 DartPdf。
/// - `docx`：手写 OOXML（单列，接受 template 参数）。
/// - `md` / `markdown`：纯 Dart（接受 template 参数）。
List<ResumeRenderer> renderersFor(
  String format, {
  String? templateId,
  bool preferTypstPdf = false,
}) {
  final t = ResumeTemplates.byId(templateId);
  final f = format.trim().toLowerCase();
  switch (f) {
    case 'pdf':
      final dart = DartPdfRenderer(templateId: t.id);
      final typst = TypstRenderer(templateId: t.id);
      if (!t.typst) return [dart];
      return preferTypstPdf ? [typst, dart] : [dart, typst];
    case 'docx':
      return [DocxRenderer(templateId: t.id)];
    case 'md':
    case 'markdown':
      return [MarkdownRenderer(templateId: t.id)];
    default:
      return const [];
  }
}
