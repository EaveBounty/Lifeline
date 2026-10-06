/// 渲染器注册表：按格式返回候选渲染器（有序，支持优雅降级）。
library;

import 'dart_pdf_renderer.dart';
import 'docx_renderer.dart';
import 'markdown_renderer.dart';
import 'renderer.dart';
import 'typst_renderer.dart';

/// 返回 [format] 的渲染器列表；调用方按顺序尝试直到成功。
///
/// - `pdf`：`preferTypstPdf` 为真时 Typst 优先，否则 DartPdf 优先；
///   两者互为兜底（Typst 缺失会自动降级）。
/// - `docx`：手写 OOXML。
/// - `md` / `markdown`：纯 Dart。
List<ResumeRenderer> renderersFor(
  String format, {
  bool preferTypstPdf = false,
}) {
  final f = format.trim().toLowerCase();
  switch (f) {
    case 'pdf':
      return preferTypstPdf
          ? [TypstRenderer(), DartPdfRenderer()]
          : [DartPdfRenderer(), TypstRenderer()];
    case 'docx':
      return [DocxRenderer()];
    case 'md':
    case 'markdown':
      return [MarkdownRenderer()];
    default:
      return const [];
  }
}
