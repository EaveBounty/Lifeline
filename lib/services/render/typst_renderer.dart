/// Typst 渲染器：桌面精品 PDF。
///
/// 定位内嵌 `typst` 二进制（环境变量 → 可执行文件同目录 → PATH），
/// 找不到则返回 [Err]，由注册表回退到 DartPdfRenderer。
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/platform/io_platform.dart';
import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'renderer.dart';

class TypstRenderer extends ResumeRenderer {
  TypstRenderer({this.executableOverride});

  /// 测试/调试用：强制指定 typst 路径。
  final String? executableOverride;

  @override
  String get format => 'pdf';

  @override
  String get extension => 'pdf';

  /// 定位 typst 可执行文件；未找到返回 null。
  Future<String?> locateBinary() async {
    final override = executableOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return await _canRun(override) ? override : null;
    }

    final env = Platform.environment['LIFELINE_TYPST']?.trim();
    if (env != null && env.isNotEmpty && await _canRun(env)) return env;

    final exeDir = p.dirname(Platform.resolvedExecutable);
    final platformName = Platform.isWindows
        ? 'windows'
        : Platform.isMacOS
            ? 'macos'
            : Platform.isLinux
                ? 'linux'
                : 'android';
    final exeName = Platform.isWindows ? 'typst.exe' : 'typst';
    final candidates = <String>[
      p.join(exeDir, 'typst', platformName, exeName),
      p.join(exeDir, 'typst', exeName),
      p.join(exeDir, exeName),
    ];
    for (final c in candidates) {
      if (await _canRun(c)) return c;
    }

    // PATH 上的 typst。
    if (await _canRun('typst')) return 'typst';
    return null;
  }

  Future<bool> _canRun(String cmd) async {
    try {
      final r = await Process.run(cmd, ['--version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Result<List<int>>> render(
    ResumeDocument doc, {
    Map<String, dynamic> options = const {},
  }) async {
    final binary = await locateBinary();
    if (binary == null) {
      return const Err('未找到 Typst 二进制（LIFELINE_TYPST / 内嵌目录 / PATH）');
    }

    Directory? tmp;
    try {
      tmp = await Directory.systemTemp.createTemp('lifeline_typst_');
      final dataFile = File(p.join(tmp.path, 'data.json'));
      await dataFile.writeAsString(jsonEncode(doc.toJson()));
      final typFile = File(p.join(tmp.path, 'main.typ'));
      await typFile.writeAsString(_defaultTemplate);

      final result = await Process.run(
        binary,
        ['compile', '--root', tmp.path, 'main.typ', 'out.pdf'],
        workingDirectory: tmp.path,
      );
      if (result.exitCode != 0) {
        final err = '${result.stderr}'.trim();
        return Err('Typst 编译失败(${result.exitCode}): '
            '${err.isEmpty ? result.stdout : err}');
      }
      final out = File(p.join(tmp.path, 'out.pdf'));
      if (!await out.exists()) return const Err('Typst 未产出 out.pdf');
      final bytes = await out.readAsBytes();
      return Ok(bytes);
    } catch (e) {
      return Err('Typst 渲染异常: $e', e);
    } finally {
      final dir = tmp;
      if (dir != null) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // 清理失败可忽略。
        }
      }
    }
  }

  /// 内置默认模板（raw：`#`/`$` 均为字面量）。
  static const String _defaultTemplate = r'''
#set page(paper: "a4", margin: (x: 1.7cm, y: 1.5cm))
#set text(
  font: (
    "Noto Sans CJK SC",
    "Noto Sans SC",
    "Source Han Sans SC",
    "Microsoft YaHei",
    "PingFang SC",
    "WenQuanYi Micro Hei",
    "Noto Sans",
    "Helvetica",
  ),
  size: 10pt,
  lang: "zh",
)
#set par(justify: false, leading: 0.72em)
#show heading.where(level: 1): it => block(above: 0.9em, below: 0.35em)[
  #set text(size: 13pt, weight: "bold")
  #it
  #v(-0.15em)
  #line(length: 100%, stroke: 0.5pt)
]

#let d = json("data.json")
#let h = d.header

#align(center)[
  #text(size: 20pt, weight: "bold")[#h.name]
  #if h.english_name != none [
    #linebreak()
    #text(size: 11pt)[#h.english_name]
  ]
  #if h.headline != none [
    #linebreak()
    #text(size: 10.5pt)[#h.headline]
  ]
  #if h.contacts.len() > 0 [
    #linebreak()
    #text(size: 9pt)[#h.contacts.map(c => c.value).join("  ·  ")]
  ]
]

#if d.summary != none and d.summary != "" [
  #heading(level: 1, outlined: false)[个人简介]
  #d.summary
]

#if d.strengths.len() > 0 [
  #heading(level: 1, outlined: false)[核心优势]
  #for s in d.strengths [
    - #s
  ]
]

#for sec in d.sections [
  #heading(level: 1, outlined: false)[#sec.title]
  #for item in sec.items [
    #text(weight: "bold")[#item.title]
    #if item.meta != none and item.meta != "" [
      #h(0.6em)
      #text(size: 9pt, fill: rgb("#444444"))[#item.meta]
    ]
    #if item.subtitle != none and item.subtitle != "" [
      #linebreak()
      #text(size: 9.5pt, style: "italic")[#item.subtitle]
    ]
    #if item.description != none and item.description != "" [
      #linebreak()
      #item.description
    ]
    #if item.bullets.len() > 0 [
      #v(0.15em)
      #for b in item.bullets [
        - #b
      ]
    ]
    #v(0.5em)
  ]
]
''';
}
