// 真实模型联测：对本地 Ollama（OpenAI 兼容）跑一次「AI 精评」全链路。
//
// 用法:
//   dart run tool/ai_eval_live_test.dart
// 可用环境变量覆盖:
//   OLLAMA_BASE_URL (默认 http://127.0.0.1:11434/v1)
//   OLLAMA_MODEL    (默认 qwen2.5:0.5b)
//   LLM_API_KEY     (Ollama 可留空)
import 'dart:io';

import 'package:lifeline/data/models/export_request.dart';
import 'package:lifeline/data/models/resume_doc.dart';
import 'package:lifeline/services/ai/llm_client.dart';
import 'package:lifeline/services/export/resume_eval_service.dart';

Future<void> main() async {
  final baseUrl =
      Platform.environment['OLLAMA_BASE_URL'] ?? 'http://127.0.0.1:11434/v1';
  final model = Platform.environment['OLLAMA_MODEL'] ?? 'qwen2.5:0.5b';
  final apiKey = Platform.environment['LLM_API_KEY'] ?? '';

  const request = ExportRequest(
    purpose: '求职',
    targetRole: '后端工程师',
    targetCompany: '示例科技',
    industry: '互联网',
    pageLimit: 1,
    emphasis: '高并发与稳定性',
    mustInclude: ['Go', 'MySQL', 'Redis'],
  );

  final svc = ResumeEvalService(llm: LlmClient());
  stdout.writeln('联测目标: $baseUrl  model=$model');
  final sw = Stopwatch()..start();
  final result = await svc.evaluateWithAi(
    doc: _doc(),
    request: request,
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
  );
  sw.stop();

  result.when(
    ok: (e) {
      stdout.writeln('结果: OK (${sw.elapsedMilliseconds}ms)  ai=${e.aiAssisted}  model=${e.model}');
      stdout.writeln('  适配分 fit=${e.fit.fitScore}  客观分 objective=${e.objective.overall}');
      stdout.writeln('  维度=${e.objective.dimensions.length}  硬性要求=${e.fit.hardRequirements.length}  '
          '缺漏=${e.fit.missing.length}  建议=${e.fit.recommendations.length}');
      for (final d in e.objective.dimensions) {
        stdout.writeln('    - ${d.label}: ${d.score}  ${d.comment}');
      }
      for (final m in e.fit.missing.take(3)) {
        stdout.writeln('    缺: ${m.item} (${m.importance})');
      }
      if (e.fit.recommendations.isNotEmpty) {
        final a = e.fit.recommendations.first;
        stdout.writeln('    首要建议: ${a.action}  预计提升=${a.expectedGain}  投入=${a.effort}  资源=${a.resources}');
      }
      stdout.writeln('  总结: ${e.objective.summary}');
    },
    err: (m, e) {
      stdout.writeln('结果: ERR -> $m');
      if (e != null) stdout.writeln('  原始异常: $e');
    },
  );
}

ResumeDocument _doc() => ResumeDocument(
      header: const ResumeHeader(
        name: '张三',
        englishName: 'San Zhang',
        headline: '后端开发工程师',
        contacts: [
          ResumeContact(label: '邮箱', value: 'zhangsan@example.com'),
          ResumeContact(label: '电话', value: '138-0000-0000'),
        ],
      ),
      summary: '3 年后端开发经验，熟悉 Go / MySQL / Redis，主导订单服务重构。',
      strengths: const ['订单服务 QPS 提升 4 倍', '熟悉 Go / Kubernetes 技术栈'],
      sections: [
        ResumeSection(
          key: 'education',
          title: '教育经历',
          order: 0,
          items: const [
            ResumeItem(
              id: 'edu-1',
              title: '示例大学 · 软件工程',
              subtitle: '本科',
              meta: '2018-09 – 2022-06',
              bullets: ['GPA 3.7/4.0'],
              categorySlug: 'education',
            ),
          ],
        ),
        ResumeSection(
          key: 'experience',
          title: '工作经历',
          order: 1,
          items: const [
            ResumeItem(
              id: 'exp-1',
              title: '后端开发工程师',
              subtitle: '示例科技有限公司',
              meta: '2022-07 至今',
              bullets: ['订单服务 QPS 从 800 提升至 3500', '接口平均延迟下降 72%'],
              tags: ['Go', 'MySQL', 'Redis'],
              categorySlug: 'experience',
            ),
          ],
        ),
        ResumeSection(
          key: 'skills',
          title: '技能特长',
          order: 2,
          items: const [
            ResumeItem(
              id: 'skill-1',
              title: '技术栈',
              bullets: ['Go / MySQL / Redis / Kubernetes'],
              categorySlug: 'skills',
            ),
          ],
        ),
      ],
      generatedAt: DateTime.now(),
    );
