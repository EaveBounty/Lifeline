/// LaTeX 渲染器：IR -> 可编译的 `ctexart` 源码（默认 xelatex 编译）。
///
/// 只负责生成 `.tex`；是否编译成 PDF 由 [LatexCompiler] 在桌面端尝试。
library;

import 'dart:convert';

import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'renderer.dart';
import 'templates.dart';

class LatexRenderer extends ResumeRenderer {
  LatexRenderer({this.templateId});

  final String? templateId;

  @override
  String get format => 'latex';

  @override
  String get extension => 'tex';

  @override
  Future<Result<List<int>>> render(
    ResumeDocument doc, {
    Map<String, dynamic> options = const {},
  }) async {
    final tid = (options['templateId'] as String?) ?? templateId;
    final tex = renderString(doc, templateId: tid);
    return Ok(utf8.encode(tex));
  }

  String renderString(ResumeDocument doc, {String? templateId}) {
    final template = ResumeTemplates.byId(templateId);
    final sections =
        doc.tailored ? doc.sections : ResumeTemplates.orderSections(doc.sections, template.id);
    final h = doc.header;
    final b = StringBuffer();

    b.writeln(r'\documentclass[11pt]{ctexart}');
    b.writeln(r'\usepackage[a4paper,margin=2cm]{geometry}');
    b.writeln(r'\usepackage{enumitem}');
    b.writeln(r'\usepackage[hidelinks]{hyperref}');
    b.writeln(r'\setlist[itemize]{leftmargin=1.3em,itemsep=1pt,topsep=2pt,parsep=0pt}');
    b.writeln(r'\setlength{\parindent}{0pt}');
    b.writeln(r'\pagestyle{empty}');
    b.writeln(r'\begin{document}');

    // 头部
    b.writeln(r'\begin{center}');
    b.writeln(r'{\LARGE\bfseries ' + _esc(h.name.isEmpty ? 'Resume' : h.name) + r'}\\');
    if ((h.englishName ?? '').trim().isNotEmpty) {
      b.writeln(_esc(h.englishName!) + r'\\');
    }
    if ((h.headline ?? '').trim().isNotEmpty) {
      b.writeln(r'{\bfseries ' + _esc(h.headline!) + r'}\\');
    }
    if (h.contacts.isNotEmpty) {
      final parts = h.contacts.map((c) {
        final label = c.label.isEmpty ? '' : '${c.label}: ';
        final value = (c.url ?? '').trim().isEmpty
            ? _esc(c.value)
            : '\\href{${_url(c.url!)}}{${_esc(c.value)}}';
        return label.isEmpty ? value : '${_esc(label)}$value';
      }).join(r'  \textperiodcentered  ');
      b.writeln('\\vspace{2pt}$parts');
    }
    b.writeln(r'\end{center}');

    if ((doc.summary ?? '').trim().isNotEmpty) {
      b.writeln(r'\section*{个人简介}');
      b.writeln(_esc(doc.summary!.trim()));
    }
    if (doc.strengths.isNotEmpty) {
      b.writeln(r'\section*{核心优势}');
      b.writeln(r'\begin{itemize}');
      for (final s in doc.strengths) {
        b.writeln(r'  \item ' + _esc(s.trim()));
      }
      b.writeln(r'\end{itemize}');
    }

    for (final section in sections) {
      if (section.items.isEmpty) continue;
      b.writeln('\\section*{${_esc(section.title)}}');
      for (final it in section.items) {
        _item(b, it);
      }
    }

    if (doc.appendix.isNotEmpty) {
      b.writeln(r'\section*{附录 · 附件目录}');
      b.writeln(r'\begin{itemize}');
      for (final e in doc.appendix) {
        final names = e.materials.isEmpty
            ? '（无）'
            : e.materials.map((x) => x.split('/').last).join('、');
        b.writeln(
            '  \\item \\textbf{[${_esc(e.label)}]} ${_esc(e.title)} —— 材料：${_esc(names)}');
      }
      b.writeln(r'\end{itemize}');
      b.writeln(r'\section*{附录 · 佐证材料}');
      for (final e in doc.appendix) {
        b.writeln(r'\noindent\textbf{[' +
            _esc(e.label) +
            r'] ' +
            _esc(e.title) +
            r'}\\');
        if ((e.note ?? '').trim().isNotEmpty) {
          b.writeln(_esc(e.note!.trim()) + r'\\');
        }
        for (final rel in e.materials) {
          b.writeln(r'  ' + _esc(rel) + r'\\');
        }
      }
    }

    b.writeln(r'\end{document}');
    return b.toString();
  }

  void _item(StringBuffer b, ResumeItem it) {
    final meta = (it.meta ?? '').trim();
    final refs =
        it.appendixRefs.isEmpty ? '' : '  〔见附录 ${it.appendixRefs.join(', ')}〕';
    b.write('\\noindent\\textbf{${_esc(it.title)}}');
    if (meta.isNotEmpty) {
      b.write(' \\hfill ${_esc(meta)}');
    }
    if (refs.isNotEmpty) b.write(_esc(refs));
    b.writeln(r'\\');
    final sub = (it.subtitle ?? '').trim();
    if (sub.isNotEmpty) b.writeln('\\textit{${_esc(sub)}}\\\\');
    final fieldLine = it.fields.entries
        .where((e) => '${e.value}'.trim().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .join('  ·  ');
    if (fieldLine.isNotEmpty) b.writeln('${_esc(fieldLine)}\\\\');
    final desc = (it.description ?? '').trim();
    if (desc.isNotEmpty) b.writeln('${_esc(desc)}\\\\');
    if (it.bullets.isNotEmpty) {
      b.writeln(r'\begin{itemize}');
      for (final bullet in it.bullets) {
        b.writeln('  \\item ${_esc(bullet)}');
      }
      b.writeln(r'\end{itemize}');
    }
    if (it.links.isNotEmpty) {
      final line = it.links
          .map((l) => l.label.trim().isEmpty
              ? '\\url{${_url(l.url)}}'
              : '${_esc(l.label)}: \\url{${_url(l.url)}}')
          .join(r'  \textperiodcentered  ');
      b.writeln('$line\\\\');
    }
    if (it.tags.isNotEmpty) {
      b.writeln('${_esc(it.tags.join('  '))}\\\\');
    }
    b.writeln(r'\vspace{4pt}');
  }

  /// LaTeX 转义（保留换行）。
  static String _esc(String s) {
    final out = StringBuffer();
    const map = {
      r'\': r'\textbackslash{}',
      '&': r'\&',
      '%': r'\%',
      r'$': r'\$',
      '#': r'\#',
      '_': r'\_',
      '{': r'\{',
      '}': r'\}',
      '~': r'\textasciitilde{}',
      '^': r'\textasciicircum{}',
    };
    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      out.write(map[c] ?? c);
    }
    return out.toString();
  }

  /// URL 转义（hyperref 的 \url 对 % # 等敏感）。
  static String _url(String s) => s
      .replaceAll('%', r'\%')
      .replaceAll('#', r'\#')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}');
}
