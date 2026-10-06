import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/data/models/export_request.dart';
import 'package:lifeline/data/models/resume_doc.dart';
import 'package:lifeline/data/models/resume_eval.dart';
import 'package:lifeline/services/ai/llm_client.dart';
import 'package:lifeline/services/export/resume_eval_service.dart';

ResumeDocument _richDoc() {
  final now = DateTime.parse('2026-01-01T00:00:00.000');
  return ResumeDocument(
    header: const ResumeHeader(
      name: '张三',
      headline: '后端工程师（Go / Kubernetes）',
      contacts: [
        ResumeContact(label: '邮箱', value: 'zhang@example.com'),
        ResumeContact(label: '主页', value: 'GitHub', url: 'https://github.com/zhang'),
      ],
    ),
    summary: '5 年后端开发经验，主导高并发服务设计。',
    strengths: const ['高并发架构', '云原生', '性能优化'],
    sections: [
      ResumeSection(
        key: 'experience',
        title: '工作经历',
        order: 0,
        items: const [
          ResumeItem(
            id: 'e1',
            title: '高级后端工程师',
            subtitle: 'ACME',
            categorySlug: 'experience',
            tags: ['Go', 'Kubernetes', '微服务'],
            bullets: [
              '主导订单服务重构，QPS 从 2000 提升到 8000，延迟降低 40%',
              '设计 Kubernetes 部署方案，部署效率提升 3 倍',
              '优化数据库索引，查询耗时从 800ms 降到 120ms',
            ],
          ),
          ResumeItem(
            id: 'e2',
            title: '后端工程师',
            subtitle: 'Beta',
            categorySlug: 'experience',
            tags: ['Go'],
            bullets: [
              '交付 5 个核心模块，覆盖 100 万用户',
              '引入缓存层，成本节省 30%',
            ],
          ),
        ],
      ),
      ResumeSection(
        key: 'projects',
        title: '项目经历',
        order: 1,
        items: const [
          ResumeItem(
            id: 'p1',
            title: '云原生网关',
            categorySlug: 'projects',
            tags: ['Kubernetes', 'Envoy'],
            bullets: ['支撑日均 1 亿请求，可用性 99.99%'],
          ),
        ],
      ),
      ResumeSection(
        key: 'education',
        title: '教育经历',
        order: 2,
        items: const [
          ResumeItem(id: 'edu', title: '某大学 计算机科学 本科', categorySlug: 'education'),
        ],
      ),
      ResumeSection(
        key: 'skills',
        title: '技能',
        order: 3,
        items: const [
          ResumeItem(
            id: 's1',
            title: 'Golang / Kubernetes / MySQL / Redis',
            categorySlug: 'skills',
            tags: ['Go', 'Kubernetes', 'MySQL'],
          ),
        ],
      ),
    ],
    generatedAt: now,
    tailored: true,
  );
}

ResumeDocument _poorDoc() {
  final now = DateTime.parse('2026-01-01T00:00:00.000');
  return ResumeDocument(
    header: const ResumeHeader(name: '李四'),
    sections: const [
      ResumeSection(
        key: 'experience',
        title: '经历',
        items: [
          ResumeItem(
            id: 'x1',
            title: '实习生',
            categorySlug: 'experience',
            bullets: ['负责了一些工作'],
          ),
        ],
      ),
    ],
    generatedAt: now,
  );
}

const _request = ExportRequest(
  targetRole: '后端工程师',
  targetCompany: 'ACME',
  mustInclude: ['Kubernetes', 'Go'],
  pageLimit: 1,
);

void main() {
  final service = ResumeEvalService(llm: LlmClient());

  group('启发式评估', () {
    test('所有分数落在 0..100', () {
      for (final doc in [_richDoc(), _poorDoc()]) {
        final eval = service.evaluateHeuristic(doc: doc, request: _request);
        expect(eval.overall, inInclusiveRange(0, 100));
        expect(eval.dimensions, isNotEmpty);
        for (final d in eval.dimensions) {
          expect(d.score, inInclusiveRange(0, 100), reason: d.key);
        }
      }
    });

    test('贫简历总分低于富简历', () {
      final rich = service.evaluateHeuristic(doc: _richDoc(), request: _request);
      final poor = service.evaluateHeuristic(doc: _poorDoc(), request: _request);
      expect(poor.overall, lessThan(rich.overall));
    });

    test('量化比例影响 impact', () {
      final rich = service.evaluateHeuristic(doc: _richDoc(), request: _request);
      final poor = service.evaluateHeuristic(doc: _poorDoc(), request: _request);
      final richImpact = rich.dimensions.firstWhere((d) => d.key == 'impact').score;
      final poorImpact = poor.dimensions.firstWhere((d) => d.key == 'impact').score;
      expect(richImpact, greaterThan(poorImpact));
      expect(richImpact, greaterThan(50));
    });

    test('recommendations 按 priority 有序且以 1 开头', () {
      final eval = service.evaluateHeuristic(doc: _poorDoc(), request: _request);
      expect(eval.recommendations, isNotEmpty);
      expect(
        eval.recommendations.map((r) => r.priority).toList(),
        [for (var i = 1; i <= eval.recommendations.length; i++) i],
      );
      for (final r in eval.recommendations) {
        expect(r.expectedGain, inInclusiveRange(0, 100));
        expect(['low', 'medium', 'high'], contains(r.effort));
      }
    });

    test('缺漏项 severity 合法', () {
      final eval = service.evaluateHeuristic(doc: _poorDoc(), request: _request);
      expect(eval.missing, isNotEmpty);
      for (final m in eval.missing) {
        expect(['high', 'medium', 'low'], contains(m.severity));
        expect(m.item, isNotEmpty);
      }
    });

    test('确定性：同一输入同一输出', () {
      final now = DateTime.parse('2026-01-01T00:00:00.000');
      final a = service.evaluateHeuristic(doc: _richDoc(), request: _request, now: now);
      final b = service.evaluateHeuristic(doc: _richDoc(), request: _request, now: now);
      expect(a.toJson(), b.toJson());
    });
  });

  group('JSON 往返', () {
    test('ResumeEvaluation 完整保留', () {
      final eval = service.evaluateHeuristic(doc: _richDoc(), request: _request);
      final decoded = ResumeEvaluation.fromJson(eval.toJson());
      expect(decoded.toJson(), eval.toJson());
      expect(decoded.overall, eval.overall);
      expect(decoded.dimensions.length, eval.dimensions.length);
      expect(decoded.recommendations.length, eval.recommendations.length);
    });

    test('ResumeMeta 带 request/evaluation 往返', () {
      final now = DateTime.parse('2026-01-01T00:00:00.000');
      final eval = service.evaluateHeuristic(doc: _richDoc(), request: _request, now: now);
      final meta = ResumeMeta(
        id: 'abc',
        name: '后端工程师 · ACME',
        createdAt: now,
        updatedAt: now,
        request: _request,
        evaluation: eval,
      );
      final decoded = ResumeMeta.fromJson(meta.toJson());
      expect(decoded.request?.targetRole, '后端工程师');
      expect(decoded.evaluation?.overall, eval.overall);
      expect(decoded.evaluation?.dimensions.length, eval.dimensions.length);
    });

    test('旧数据缺字段时兼容为 null', () {
      final meta = ResumeMeta.fromJson({
        'id': 'old',
        'name': '旧简历',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(meta.request, isNull);
      expect(meta.evaluation, isNull);
    });
  });

  group('不可信输入解析', () {
    test('越界/缺字段的模型输出被安全夹紧', () {
      final eval = ResumeEvaluation.fromJson({
        'overall': 999,
        'dimensions': [
          {'key': 'match', 'score': -50, 'evidence': 'not-a-list'},
          {'key': 'ats', 'score': '70'},
          'garbage',
        ],
        'missing': [
          {'item': 'x', 'severity': 'catastrophic'},
        ],
        'recommendations': [
          {'item': 'y', 'expected_gain': 500, 'effort': 'warp', 'priority': 3},
        ],
      });
      expect(eval.overall, 100);
      expect(eval.dimensions.length, 2);
      expect(eval.dimensions[0].score, 0);
      expect(eval.dimensions[0].evidence, isEmpty);
      expect(eval.dimensions[1].score, 70);
      expect(eval.missing.single.severity, 'medium');
      expect(eval.recommendations.single.expectedGain, 100);
      expect(eval.recommendations.single.effort, 'medium');
    });
  });
}
