/// 真实数据管线校验（本地手动运行）。
///
/// 使用 `test/个人信息资料`（真实用户仓库）跑「编译 → 计划 → 改写 → 严格页数 → 渲染」，
/// 断言：① 1 页目标真的 ≤1 页；② 附录含「附件目录」；③ 占位符被清理。
/// 数据不存在时自动跳过（不影响 CI）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/core/platform/io_platform.dart';
import 'package:lifeline/core/result.dart';
import 'package:lifeline/core/utils/pdf_pages.dart';
import 'package:lifeline/data/models/export_request.dart';
import 'package:lifeline/data/models/profile.dart';
import 'package:lifeline/data/models/profile_record.dart';
import 'package:lifeline/data/models/resume_doc.dart';
import 'package:lifeline/data/repositories/resume_repository.dart';
import 'package:lifeline/services/ai/llm_client.dart';
import 'package:lifeline/services/compile/resume_compiler.dart';
import 'package:lifeline/services/export/export_service.dart';
import 'package:lifeline/services/export/data_exporter.dart';
import 'package:lifeline/services/render/dart_pdf_renderer.dart';
import 'package:lifeline/services/render/latex_compiler.dart';
import 'package:lifeline/services/render/latex_renderer.dart';
import 'package:path/path.dart' as p;

const String _fixture = 'test/个人信息资料';

/// 假模型：把传入的 facts 原样回吐为 ResumeDocument（最坏情况，触发裁剪闭环）。
class _EchoLlm extends LlmClient {
  @override
  Future<Result<String>> chatCompletion({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<LlmMessage> messages,
    bool jsonMode = false,
    Map<String, String> extraHeaders = const {},
  }) async {
    final system = messages
        .where((m) => m.role == 'system')
        .expand((m) => m.contents)
        .map((c) => c.value)
        .join();
    final user = messages
        .where((m) => m.role == 'user')
        .expand((m) => m.contents)
        .map((c) => c.value)
        .join();
    if (system.contains('取舍决策')) return Ok(_plan(user));
    if (system.contains('成品级')) return Ok(_rewrite(user));
    return const Ok('{}');
  }

  Map<String, dynamic> _factsAfter(String text, String marker) {
    final i = text.indexOf(marker);
    final start = text.indexOf('{', i < 0 ? 0 : i);
    var depth = 0;
    var inStr = false;
    for (var k = start; k < text.length; k++) {
      final c = text[k];
      if (c == '"') inStr = !inStr;
      if (inStr) continue;
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          return jsonDecode(text.substring(start, k + 1)) as Map<String, dynamic>;
        }
      }
    }
    return {};
  }

  String _plan(String user) {
    final facts = _factsAfter(user, '候选人素材 facts');
    final items = (facts['items'] as List?) ?? const [];
    final decisions = <Map<String, dynamic>>[];
    final slugs = <String>[];
    for (final it in items) {
      final m = (it as Map).cast<String, dynamic>();
      final slug = '${m['category_slug'] ?? ''}';
      if (!slugs.contains(slug)) slugs.add(slug);
      decisions.add({
        'source_record_id': m['source_record_id'] ?? m['id'],
        'decision': 'keep',
        'relevance': 0.6,
        'impact': 0.6,
        'priority': 0.5,
        'bullet_cap': 3,
        'verb_class': 'L3',
        'reason': 'echo',
      });
    }
    return jsonEncode({
      'role': 'test',
      'section_priority': slugs,
      'decisions': decisions,
      'budget_lines': 45,
      'min_coverage': 0.6,
      'open_questions': const [],
    });
  }

  String _rewrite(String user) {
    final facts = _factsAfter(user, '可用的候选人素材 facts');
    final items = (facts['items'] as List?) ?? const [];
    final bySlug = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final m = (it as Map).cast<String, dynamic>();
      final slug = '${m['category_slug'] ?? 'custom'}';
      bySlug.putIfAbsent(slug, () => []).add({
        'id': m['id'] ?? m['source_record_id'],
        'title': m['title'],
        'subtitle': m['subtitle'],
        'meta': m['meta'],
        'description': m['description'],
        'bullets': m['bullets'] ?? const [],
        'fields': m['fields'] ?? const {},
        'tags': m['tags'] ?? const [],
        'links': m['links'] ?? const [],
        'source_record_id': m['source_record_id'],
        'category_slug': slug,
      });
    }
    return jsonEncode({
      'header': facts['header'] ?? const {'name': 'test'},
      'summary': facts['summary'],
      'strengths': facts['strengths'] ?? const [],
      'sections': [
        for (final e in bySlug.entries)
          {'key': e.key, 'title': e.key, 'items': e.value, 'order': 0},
      ],
      'tailored': true,
    });
  }
}

Future<void> _copyDir(Directory src, Directory dst) async {
  await dst.create(recursive: true);
  await for (final e in src.list(recursive: false, followLinks: false)) {
    final name = p.basename(e.path);
    if (e is Directory) {
      await _copyDir(e, Directory(p.join(dst.path, name)));
    } else if (e is File) {
      await e.copy(p.join(dst.path, name));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实数据：1 页目标 + 附录目录 + 去占位符', () async {
    final src = Directory(_fixture);
    if (!src.existsSync()) {
      // 数据不存在则跳过。
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('lifeline_realdata_');
    try {
      await _copyDir(src, tmp);
      final root = tmp.path;

      // 加载 profile 与 records。
      final profile = Profile.fromJson(
        jsonDecode(await File(p.join(root, 'data/profile.json')).readAsString())
            as Map<String, dynamic>,
      );
      final records = <ProfileRecord>[];
      final recDir = Directory(p.join(root, 'data/records'));
      await for (final f in recDir.list(recursive: true)) {
        if (f is File && f.path.endsWith('.json')) {
          try {
            records.add(ProfileRecord.fromJson(
              jsonDecode(await f.readAsString()) as Map<String, dynamic>,
            ));
          } catch (_) {}
        }
      }

      final full = const ResumeCompiler().compile(
        profile: profile,
        records: records,
      );

      final request = ExportRequest(
        targetRole: '研究生（复试用）',
        targetCompany: '哈尔滨工程大学计算机学院',
        pageLimit: 1,
        templateId: 'academic-cv',
        appendixEnabled: true,
        researchEnabled: false,
      );

      final repo = ResumeRepository(root);
      final service = ExportService(
        llm: _EchoLlm(),
        repo: repo,
        syncRoot: root,
        formats: const ['pdf'],
      );

      final res = await service.generate(
        full: full,
        request: request,
        providerId: 'test',
        baseUrl: 'http://x',
        apiKey: 'x',
        model: 'x',
      );
      expect(res.isOk, isTrue, reason: res.errorMessage);

      // 校验正文页数 ≤ 1（附录另计，单独渲染正文以测量）。
      final id = res.valueOrNull!.id;
      final specFile = File(p.join(root, 'data/resumes/$id/spec.json'));
      final specJson = await specFile.readAsString();
      final spec = ResumeDocument.fromJson(
        jsonDecode(specJson) as Map<String, dynamic>,
      );
      final bodyRender = await DartPdfRenderer(templateId: 'academic-cv').render(
        spec,
        options: {
          'language': 'zh',
          'pageLimit': 1,
          'templateId': 'academic-cv',
          'syncRoot': root,
          'omitAppendix': true,
        },
      );
      expect(bodyRender.isOk, isTrue);
      final pages = countPdfPages(bodyRender.valueOrNull!);
      // ignore: avoid_print
      print('真实数据：正文页数=$pages（目标 1）；章节=${spec.sections.map((s) => s.title).toList()}');
      final kept = spec.sections.fold<int>(0, (a, s) => a + s.items.length);
      // ignore: avoid_print
      print('真实数据：保留条目=$kept，附录条目=${spec.appendix.length}');
      expect(pages, lessThanOrEqualTo(1));

      // 去占位符 + 附录目录与正文匹配（条目数不超过保留条目数）。
      expect(specJson.contains('实习单位'), isFalse);
      expect(spec.appendix.length, lessThanOrEqualTo(kept));

      // 不限页数场景：附录目录应有内容。
      final res2 = await service.generate(
        full: full,
        request: request.copyWith(pageLimit: 0),
        providerId: 'test',
        baseUrl: 'http://x',
        apiKey: 'x',
        model: 'x',
      );
      expect(res2.isOk, isTrue);
      final spec2 = ResumeDocument.fromJson(
        jsonDecode(await File(p.join(root, 'data/resumes/${res2.valueOrNull!.id}/spec.json'))
                .readAsString())
            as Map<String, dynamic>,
      );
      // ignore: avoid_print
      print('真实数据：不限页数 → 附录条目=${spec2.appendix.length}');
      expect(spec2.appendix.isNotEmpty, isTrue);

      // LaTeX：渲染 .tex 并尝试本机编译（引擎缺失不算失败）。
      final latex = await LatexRenderer(templateId: 'academic-cv').render(spec2);
      expect(latex.isOk, isTrue);
      final tex = utf8.decode(latex.valueOrNull!);
      expect(tex.contains('ctexart'), isTrue);
      expect(tex.contains('附件目录'), isTrue);
      final compiled = await compileLatex(tex);
      // ignore: avoid_print
      print('真实数据：LaTeX 编译=${compiled == null ? '未编译（无引擎或失败）' : '成功 ${compiled.length} 字节'}');

      // 数据导出 YAML：一行一条经历，且不含内部字段名。
      final yaml = const DataExporter().build(profile: profile, records: records);
      expect(yaml.contains('时间线:'), isTrue);
      expect(yaml.contains('category_slug'), isFalse);
      expect(yaml.contains('tags'), isFalse);
      // ignore: avoid_print
      print('数据导出 YAML 片段:\n${yaml.split('\n').take(16).join('\n')}');
      // ignore: avoid_print
      final lines = yaml.split('\n');
      final ti = lines.indexWhere((l) => l.startsWith('时间线:'));
      // ignore: avoid_print
      print('时间线样例:\n${lines.sublist(ti + 1).where((l) => l.startsWith('  - ')).take(4).join('\n')}');
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
