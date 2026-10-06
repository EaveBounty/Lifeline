/// Typst 渲染器：桌面精品 PDF。
///
/// 定位内嵌 `typst` 二进制（环境变量 → 可执行文件同目录 → PATH），
/// 找不到则返回 [Err]，由注册表回退到 DartPdfRenderer。
///
/// 内置多套模板（single / two-column / academic / creative），数据经
/// `json("data.json")` 注入；模板内显式声明 CJK 字体族。
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/platform/io_platform.dart';
import '../../core/result.dart';
import '../../data/models/resume_doc.dart';
import 'renderer.dart';
import 'templates.dart';

class TypstRenderer extends ResumeRenderer {
  TypstRenderer({this.executableOverride, this.templateId});

  /// 测试/调试用：强制指定 typst 路径。
  final String? executableOverride;

  /// 默认模板 id；可被 `options['templateId']` 覆盖。
  final String? templateId;

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

    final template = ResumeTemplates.byId(
      (options['templateId'] as String?) ?? templateId,
    );

    Directory? tmp;
    try {
      tmp = await Directory.systemTemp.createTemp('lifeline_typst_');
      final dataFile = File(p.join(tmp.path, 'data.json'));
      final data = Map<String, dynamic>.from(doc.toJson());
      data['sections'] =
          ResumeTemplates.orderSections(doc.sections, template.id)
              .map((s) => s.toJson())
              .toList();
      await dataFile.writeAsString(jsonEncode(data));

      final typFile = File(p.join(tmp.path, 'main.typ'));
      await typFile.writeAsString(
        _templateFor(_layoutOf(template.layout), _hex(template.accentArgb)),
      );

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

  /// 版式归一化：未知/优雅/极简映射到 single。
  String _layoutOf(String layout) => switch (layout) {
        'two-column' => 'two-column',
        'academic' => 'academic',
        'creative' => 'creative',
        _ => 'single',
      };

  String _hex(int argb) {
    final rgb = argb & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  String _templateFor(String layout, String accent) {
    final body = switch (layout) {
      'two-column' => _twoColumn,
      'academic' => _academic,
      'creative' => _creative,
      _ => _single,
    };
    return _head + _itemFn + _data + body.replaceAll('__ACCENT__', accent);
  }

  // ---------------------------------------------------------------------------
  // 模板片段
  // ---------------------------------------------------------------------------

  /// 页面/字体/段落公共设置（CJK 字体族显式声明）。
  static const String _head = r'''
#set page(paper: "a4", margin: (x: 1.7cm, y: 1.5cm))
#set text(
  font: (
    "Noto Sans CJK SC",
    "Noto Sans SC",
    "Source Han Sans SC",
    "Microsoft YaHei",
    "PingFang SC",
    "WenQuanYi Micro Hei",
    "Noto Serif CJK SC",
    "Source Han Serif SC",
    "Noto Sans",
    "Helvetica",
  ),
  size: 10pt,
  lang: "zh",
)
#set par(justify: false, leading: 0.72em)
''';

  /// 条目渲染辅助函数（各模板复用）。
  static const String _itemFn = r'''
#let render_item(item) = [
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
  #v(0.45em)
]
''';

  static const String _data = r'''
#let d = json("data.json")
#let h = d.header
''';

  /// single：单列，标题下划色线。
  static const String _single = r'''
#let accent = rgb("__ACCENT__")
#show heading.where(level: 1): it => block(above: 0.9em, below: 0.35em)[
  #set text(size: 13pt, weight: "bold", fill: accent)
  #it
  #v(-0.15em)
  #line(length: 100%, stroke: 0.6pt + accent)
]

#align(center)[
  #text(size: 20pt, weight: "bold", fill: accent)[#h.name]
  #if h.english_name != none and h.english_name != "" [
    #linebreak()
    #text(size: 11pt)[#h.english_name]
  ]
  #if h.headline != none and h.headline != "" [
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
    #render_item(item)
  ]
]
''';

  /// two-column：主经历 + 右侧技能/证书侧栏。
  static const String _twoColumn = r'''
#let accent = rgb("__ACCENT__")
#show heading.where(level: 1): it => block(above: 0.8em, below: 0.3em)[
  #set text(size: 12pt, weight: "bold", fill: accent)
  #it
  #v(-0.12em)
  #line(length: 100%, stroke: 0.5pt + accent)
]

#let is_side(s) = (
  s.key.contains("skill") or s.key.contains("cert") or s.key.contains("language")
    or s.key.contains("award") or s.key.contains("honor")
    or s.title.contains("技能") or s.title.contains("证书")
    or s.title.contains("语言") or s.title.contains("奖")
)
#let main_secs = d.sections.filter(s => not is_side(s))
#let side_secs = d.sections.filter(s => is_side(s))

#align(center)[
  #text(size: 19pt, weight: "bold", fill: accent)[#h.name]
  #if h.english_name != none and h.english_name != "" [
    #linebreak()
    #text(size: 11pt)[#h.english_name]
  ]
  #if h.headline != none and h.headline != "" [
    #linebreak()
    #text(size: 10.5pt)[#h.headline]
  ]
  #if h.contacts.len() > 0 [
    #linebreak()
    #text(size: 9pt)[#h.contacts.map(c => c.value).join("  ·  ")]
  ]
]
#v(0.4em)

#if d.summary != none and d.summary != "" [
  #heading(level: 1, outlined: false)[个人简介]
  #d.summary
]

#grid(
  columns: (1.9fr, 1fr),
  gutter: 1.2em,
  [
    #for sec in main_secs [
      #heading(level: 1, outlined: false)[#sec.title]
      #for item in sec.items [
        #render_item(item)
      ]
    ]
  ],
  [
    #if d.strengths.len() > 0 [
      #heading(level: 1, outlined: false)[核心优势]
      #for s in d.strengths [
        - #s
      ]
      #v(0.3em)
    ]
    #for sec in side_secs [
      #heading(level: 1, outlined: false)[#sec.title]
      #for item in sec.items [
        #render_item(item)
      ]
    ]
  ],
)
''';

  /// academic：居中标题、上下分隔线。
  static const String _academic = r'''
#let accent = rgb("__ACCENT__")
#show heading.where(level: 1): it => block(above: 1em, below: 0.35em)[
  #align(center)[
    #line(length: 100%, stroke: 0.5pt + accent)
    #v(0.12em)
    #set text(size: 12.5pt, weight: "bold")
    #it
  ]
]

#align(center)[
  #text(size: 20pt, weight: "bold")[#h.name]
  #if h.english_name != none and h.english_name != "" [
    #linebreak()
    #text(size: 11pt)[#h.english_name]
  ]
  #if h.headline != none and h.headline != "" [
    #linebreak()
    #text(size: 10.5pt, style: "italic")[#h.headline]
  ]
  #if h.contacts.len() > 0 [
    #linebreak()
    #text(size: 9pt)[#h.contacts.map(c => c.value).join("  ·  ")]
  ]
]
#v(0.5em)

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
    #render_item(item)
  ]
]
''';

  /// creative：彩色标题块 + 顶部色带。
  static const String _creative = r'''
#let accent = rgb("__ACCENT__")
#show heading.where(level: 1): it => block(above: 0.9em, below: 0.3em)[
  #rect(width: 100%, fill: accent, inset: (x: 7pt, y: 3pt), radius: 2pt)[
    #set text(size: 12pt, weight: "bold", fill: white)
    #it
  ]
]

#rect(width: 100%, fill: accent, inset: 12pt, radius: 5pt)[
  #text(size: 21pt, weight: "bold", fill: white)[#h.name]
  #if h.english_name != none and h.english_name != "" [
    #linebreak()
    #text(size: 11pt, fill: white)[#h.english_name]
  ]
  #if h.headline != none and h.headline != "" [
    #linebreak()
    #text(size: 11pt, weight: "bold", fill: white)[#h.headline]
  ]
  #if h.contacts.len() > 0 [
    #linebreak()
    #text(size: 9pt, fill: white)[#h.contacts.map(c => c.value).join("  ·  ")]
  ]
]
#v(0.4em)

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
    #render_item(item)
  ]
]
''';
}
