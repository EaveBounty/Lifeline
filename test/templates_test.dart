import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/data/models/export_request.dart';
import 'package:lifeline/data/models/resume_doc.dart';
import 'package:lifeline/services/render/dart_pdf_renderer.dart';
import 'package:lifeline/services/render/renderer_registry.dart';
import 'package:lifeline/services/render/templates.dart';

ResumeDocument _doc() {
  final now = DateTime.parse('2026-01-01T00:00:00.000');
  return ResumeDocument(
    header: const ResumeHeader(
      name: '张三',
      englishName: 'Zhang San',
      headline: '后端工程师（Go / Kubernetes）',
      contacts: [
        ResumeContact(label: '邮箱', value: 'zhang@example.com'),
        ResumeContact(label: '主页', value: 'GitHub', url: 'https://github.com/z'),
      ],
    ),
    summary: '5 年后端开发经验。',
    strengths: const ['高并发', '云原生'],
    sections: [
      ResumeSection(key: 'skills', title: '专业技能', items: const [
        ResumeItem(id: 's1', title: 'Go / Kubernetes', categorySlug: 'skills', tags: ['Go', 'K8s']),
      ]),
      ResumeSection(key: 'experience', title: '工作经历', items: const [
        ResumeItem(id: 'e1', title: '高级后端工程师', subtitle: 'ACME', meta: '2022-2026',
            categorySlug: 'experience', bullets: ['QPS 提升 4 倍', '延迟降低 40%']),
      ]),
      ResumeSection(key: 'education', title: '教育背景', items: const [
        ResumeItem(id: 'd1', title: '计算机科学 硕士', subtitle: '某大学', categorySlug: 'education'),
      ]),
      ResumeSection(key: 'publications', title: '论文发表', items: const [
        ResumeItem(id: 'p1', title: 'A Paper on Systems', meta: '2025', categorySlug: 'publications'),
      ]),
      ResumeSection(key: 'certificates', title: '证书', items: const [
        ResumeItem(id: 'c1', title: 'CKA', categorySlug: 'certificates'),
      ]),
    ],
    generatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('模板注册表', () {
    test('至少 8 套且 id 唯一', () {
      final all = ResumeTemplates.all;
      expect(all.length, greaterThanOrEqualTo(8));
      final ids = all.map((t) => t.id).toSet();
      expect(ids.length, all.length);
    });

    test('byId 兜底', () {
      expect(ResumeTemplates.byId(null).id, ResumeTemplates.defaultId);
      expect(ResumeTemplates.byId('').id, ResumeTemplates.defaultId);
      expect(ResumeTemplates.byId('不存在').id, ResumeTemplates.defaultId);
      expect(ResumeTemplates.byId('academic-cv').id, 'academic-cv');
    });

    test('recommendFor 按岗位返回合理模板', () {
      expect(ResumeTemplates.recommendFor(['教师']).first.id, 'teacher');
      expect(ResumeTemplates.recommendFor(['算法工程师']).first.id, 'tech-compact');
      expect(ResumeTemplates.recommendFor(['科研']).first.id, 'academic-cv');
      expect(ResumeTemplates.recommendFor(['应届生']).first.id, 'fresh-graduate');
      // 空关键词返回全部。
      expect(ResumeTemplates.recommendFor(const []).length,
          ResumeTemplates.all.length);
    });

    test('orderSections 学术前置论文、应届前置教育', () {
      final academic =
          ResumeTemplates.orderSections(_doc().sections, 'academic-cv');
      expect(academic.first.key, 'publications');
      final fresh =
          ResumeTemplates.orderSections(_doc().sections, 'fresh-graduate');
      expect(fresh.first.key, 'education');
    });
  });

  group('DartPdf 多版式', () {
    final layouts = {
      'single': 'ats-classic',
      'two-column': 'modern-two-col',
      'academic': 'academic-cv',
      'creative': 'creative',
      'compact': 'fresh-graduate',
    };

    for (final entry in layouts.entries) {
      test('layout ${entry.key} 产出合法 PDF', () async {
        final r = await DartPdfRenderer(templateId: entry.value).render(_doc());
        expect(r.isOk, isTrue, reason: r.errorMessage);
        final bytes = r.valueOrNull!;
        expect(bytes.isNotEmpty, isTrue);
        expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
      });
    }
  });

  group('渲染器注册表', () {
    test('pdf 候选非空且含 DartPdf 兜底', () {
      for (final t in ResumeTemplates.all) {
        final list = renderersFor('pdf', templateId: t.id);
        expect(list, isNotEmpty);
        expect(list.any((r) => r is DartPdfRenderer), isTrue,
            reason: '模板 ${t.id} 缺少 DartPdf 兜底');
      }
      final prefer = renderersFor('pdf',
          templateId: 'modern-two-col', preferTypstPdf: true);
      expect(prefer.any((r) => r is DartPdfRenderer), isTrue);
    });
  });

  group('元数据模板字段', () {
    test('ExportRequest 默认模板并随 JSON 往返', () {
      expect(const ExportRequest().templateId, ResumeTemplates.defaultId);
      final json = const ExportRequest(templateId: 'creative').toJson();
      expect(ExportRequest.fromJson(json).templateId, 'creative');
    });

    test('ResumeMeta 兼容缺失 templateId', () {
      final meta = ResumeMeta.fromJson(const {
        'id': 'x',
        'name': 'n',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(meta.templateId, isNull);
      final round = ResumeMeta.fromJson(
        meta.copyWith(templateId: 'teacher').toJson(),
      );
      expect(round.templateId, 'teacher');
    });
  });
}
