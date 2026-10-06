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

ResumeDocument _teacherDoc() {
  final now = DateTime.parse('2026-01-01T00:00:00.000');
  return ResumeDocument(
    header: const ResumeHeader(name: '王老师', headline: '数学教育应届生'),
    summary: '师范院校数学专业应届生，有家教与支教经历。',
    sections: [
      ResumeSection(
        key: 'education',
        title: '教育经历',
        order: 0,
        items: const [
          ResumeItem(id: 'edu', title: '某师范大学 数学与应用数学 本科', categorySlug: 'education'),
        ],
      ),
      ResumeSection(
        key: 'experience',
        title: '实习经历',
        order: 1,
        items: const [
          ResumeItem(
            id: 'x1',
            title: '家教 / 支教',
            categorySlug: 'experience',
            bullets: ['辅导 30 名学生，平均分提升 12 分'],
          ),
        ],
      ),
      ResumeSection(
        key: 'skills',
        title: '技能',
        order: 2,
        items: const [
          ResumeItem(
            id: 's1',
            title: '数学 / 教学设计 / 班级管理',
            categorySlug: 'skills',
          ),
        ],
      ),
    ],
    generatedAt: now,
  );
}

const _backendRequest = ExportRequest(
  targetRole: '后端工程师',
  targetCompany: 'ACME',
  mustInclude: ['Kubernetes', 'Go'],
  pageLimit: 1,
);

const _teacherRequest = ExportRequest(
  targetRole: '初中数学教师',
  targetCompany: '某中学',
  pageLimit: 1,
);

const _algoRequest = ExportRequest(
  targetRole: '算法工程师',
  targetCompany: '某科技公司',
  pageLimit: 1,
);

void main() {
  final service = ResumeEvalService(llm: LlmClient());

  group('启发式评估 · 客观质量', () {
    test('所有客观分数落在 0..100', () {
      for (final doc in [_richDoc(), _poorDoc(), _teacherDoc()]) {
        final eval = service.evaluateHeuristic(doc: doc, request: _backendRequest);
        expect(eval.objective.overall, inInclusiveRange(0, 100));
        expect(eval.objective.dimensions, isNotEmpty);
        for (final d in eval.objective.dimensions) {
          expect(d.score, inInclusiveRange(0, 100), reason: d.key);
        }
        for (final d in eval.fit.recommendations) {
          expect(d.expectedGain, inInclusiveRange(0, 100));
        }
      }
    });

    test('贫简历客观分低于富简历', () {
      final rich = service.evaluateHeuristic(doc: _richDoc(), request: _backendRequest);
      final poor = service.evaluateHeuristic(doc: _poorDoc(), request: _backendRequest);
      expect(poor.objective.overall, lessThan(rich.objective.overall));
    });

    test('量化比例影响 impact', () {
      final rich = service.evaluateHeuristic(doc: _richDoc(), request: _backendRequest);
      final poor = service.evaluateHeuristic(doc: _poorDoc(), request: _backendRequest);
      final richImpact =
          rich.objective.dimensions.firstWhere((d) => d.key == 'impact').score;
      final poorImpact =
          poor.objective.dimensions.firstWhere((d) => d.key == 'impact').score;
      expect(richImpact, greaterThan(poorImpact));
      expect(richImpact, greaterThan(50));
    });

    test('确定性：同一输入同一输出', () {
      final now = DateTime.parse('2026-01-01T00:00:00.000');
      final a = service.evaluateHeuristic(doc: _richDoc(), request: _backendRequest, now: now);
      final b = service.evaluateHeuristic(doc: _richDoc(), request: _backendRequest, now: now);
      expect(a.toJson(), b.toJson());
    });
  });

  group('岗位适配 · 教师', () {
    test('缺教资 → hardRequirements 标 missing', () {
      final eval = service.evaluateHeuristic(doc: _teacherDoc(), request: _teacherRequest);
      expect(eval.fit.roleProfileId, 'teacher');
      final cert = eval.fit.hardRequirements.firstWhere(
        (r) => r.name.contains('教师资格'),
      );
      expect(cert.status, 'missing');
      expect(cert.importance, 'required');
      expect(eval.fit.fitScore, lessThan(70));
      expect(eval.fit.fitScore, inInclusiveRange(0, 100));
    });

    test('推荐含教师资格相关且 priority 靠前', () {
      final eval = service.evaluateHeuristic(doc: _teacherDoc(), request: _teacherRequest);
      final rec = eval.fit.recommendations.firstWhere(
        (a) => a.action.contains('教师资格'),
      );
      expect(rec.priority, lessThanOrEqualTo(2));
      expect(rec.resources, contains('https://ntce.neea.edu.cn'));
      // 缺漏项也应包含教师证。
      expect(eval.fit.missing.any((m) => m.item.contains('教师资格')), isTrue);
    });

    test('recommendations priority 从 1 连续递增', () {
      final eval = service.evaluateHeuristic(doc: _teacherDoc(), request: _teacherRequest);
      expect(
        eval.fit.recommendations.map((r) => r.priority).toList(),
        [for (var i = 1; i <= eval.fit.recommendations.length; i++) i],
      );
    });
  });

  group('岗位适配 · 算法', () {
    test('建议含 Kaggle/天池/LeetCode 等竞赛资源', () {
      final eval = service.evaluateHeuristic(doc: _richDoc(), request: _algoRequest);
      expect(eval.fit.roleProfileId, 'algorithm');
      final urls = eval.fit.recommendations.expand((a) => a.resources).toList();
      expect(
        urls.any((u) =>
            u.contains('kaggle') || u.contains('tianchi') || u.contains('leetcode')),
        isTrue,
        reason: '算法岗建议应包含竞赛/刷题资源',
      );
      expect(
        eval.fit.recommendations.map((r) => r.priority).toList(),
        [for (var i = 1; i <= eval.fit.recommendations.length; i++) i],
      );
    });
  });

  group('JSON 往返', () {
    test('新结构 ResumeEvaluation 完整保留', () {
      final eval = service.evaluateHeuristic(doc: _teacherDoc(), request: _teacherRequest);
      final decoded = ResumeEvaluation.fromJson(eval.toJson());
      expect(decoded.toJson(), eval.toJson());
      expect(decoded.objective.overall, eval.objective.overall);
      expect(decoded.objective.dimensions.length, eval.objective.dimensions.length);
      expect(decoded.fit.recommendations.length, eval.fit.recommendations.length);
      expect(decoded.fit.hardRequirements.length, eval.fit.hardRequirements.length);
    });

    test('旧结构（schema v1 顶层字段）可解析', () {
      final eval = ResumeEvaluation.fromJson({
        'schema_version': '1',
        'overall': 72,
        'dimensions': [
          {'key': 'impact', 'label': '量化成果', 'score': 60, 'evidence': ['x']},
        ],
        'missing': [
          {'item': '教师资格证', 'severity': 'high', 'why': 'w', 'suggestion': 's'},
        ],
        'recommendations': [
          {'item': '报名教资', 'expected_gain': 40, 'effort': 'low', 'priority': 1},
        ],
        'summary': '总体判断',
      });
      expect(eval.objective.overall, 72);
      expect(eval.objective.dimensions.single.key, 'impact');
      expect(eval.objective.summary, '总体判断');
      expect(eval.fit.missing.single.item, '教师资格证');
      expect(eval.fit.recommendations.single.action, '报名教资');
      expect(eval.fit.recommendations.single.expectedGain, 40);
      expect(eval.fit.recommendations.single.effort, 'low');
    });

    test('ResumeMeta 带 request/evaluation 往返', () {
      final now = DateTime.parse('2026-01-01T00:00:00.000');
      final eval = service.evaluateHeuristic(doc: _richDoc(), request: _backendRequest, now: now);
      final meta = ResumeMeta(
        id: 'abc',
        name: '后端工程师 · ACME',
        createdAt: now,
        updatedAt: now,
        request: _backendRequest,
        evaluation: eval,
      );
      final decoded = ResumeMeta.fromJson(meta.toJson());
      expect(decoded.request?.targetRole, '后端工程师');
      expect(decoded.evaluation?.objective.overall, eval.objective.overall);
      expect(decoded.evaluation?.fit.fitScore, eval.fit.fitScore);
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
        'schema_version': '2',
        'fit': {
          'fit_score': 999,
          'hard_requirements': [
            {'name': 'x', 'status': 'weird', 'importance': 'nope'},
          ],
          'recommendations': [
            {
              'action': 'y',
              'expected_gain': 500,
              'effort': 'warp',
              'priority': -3,
              'resources': 'not-a-list',
              'done': 'yes',
            },
          ],
        },
        'objective': {
          'overall': -20,
          'dimensions': [
            {'key': 'impact', 'score': 150, 'evidence': 'not-a-list'},
            'garbage',
          ],
        },
      });
      expect(eval.fit.fitScore, 100);
      expect(eval.fit.hardRequirements.single.status, 'unclear');
      expect(eval.fit.hardRequirements.single.importance, 'required');
      expect(eval.fit.recommendations.single.expectedGain, 100);
      expect(eval.fit.recommendations.single.effort, 'medium');
      expect(eval.fit.recommendations.single.priority, 1);
      expect(eval.fit.recommendations.single.resources, isEmpty);
      expect(eval.fit.recommendations.single.done, isFalse);
      expect(eval.objective.overall, 0);
      expect(eval.objective.dimensions.single.score, 100);
      expect(eval.objective.dimensions.single.evidence, isEmpty);
    });
  });
}
