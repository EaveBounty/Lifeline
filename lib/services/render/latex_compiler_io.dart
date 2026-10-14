/// 原生 LaTeX 编译：写临时目录，依次尝试 latexmk -xelatex / xelatex。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 编译 .tex 为 PDF 字节；失败或本机无 TeX 引擎返回 null。
Future<List<int>?> compileLatex(String tex) async {
  Directory? dir;
  try {
    dir = await Directory.systemTemp.createTemp('lifeline_tex_');
    final texFile = File(p.join(dir.path, 'resume.tex'));
    await texFile.writeAsString(tex, encoding: utf8);

    const attempts = <List<String>>[
      ['latexmk', '-xelatex', '-interaction=nonstopmode', '-halt-on-error', 'resume.tex'],
      ['xelatex', '-interaction=nonstopmode', '-halt-on-error', 'resume.tex'],
    ];
    for (final cmd in attempts) {
      try {
        await Process.run(
          cmd.first,
          cmd.sublist(1),
          workingDirectory: dir.path,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        ).timeout(const Duration(seconds: 120));
        final pdf = File(p.join(dir.path, 'resume.pdf'));
        if (await pdf.exists()) {
          final bytes = await pdf.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (_) {
        // 换下一个引擎。
      }
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    try {
      await dir?.delete(recursive: true);
    } catch (_) {}
  }
}
