import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/data/models/resume_doc.dart';
import 'package:lifeline/services/update/update_service.dart';

void main() {
  group('语义化版本比较', () {
    test('主/次/修订比较', () {
      expect(compareVersions('0.5.0', '0.4.2'), greaterThan(0));
      expect(compareVersions('0.4.2', '0.5.0'), lessThan(0));
      expect(compareVersions('0.5.0', '0.5.0'), 0);
      expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
    });

    test('容忍 build 号与不等长', () {
      expect(compareVersions('0.5.0+7', '0.5.0'), 0);
      expect(compareVersions('0.5', '0.5.1'), lessThan(0));
      expect(compareVersions('0.10.0', '0.9.0'), greaterThan(0));
    });
  });

  group('参考材料附录模型', () {
    test('ResumeDocument appendix JSON 往返', () {
      final doc = ResumeDocument(
        header: const ResumeHeader(name: '张三'),
        generatedAt: DateTime.now(),
        appendix: const [
          ResumeAppendixEntry(
            label: 'A-1',
            recordId: 'r1',
            title: 'ACM 银奖',
            materials: ['attachments/2026/cert.jpg'],
            note: '证书与正文一致',
          ),
        ],
      );
      final back = ResumeDocument.fromJson(doc.toJson());
      expect(back.appendix.length, 1);
      expect(back.appendix.single.label, 'A-1');
      expect(back.appendix.single.materials.single, 'attachments/2026/cert.jpg');
    });

    test('ResumeItem 交叉引用与 links 往返', () {
      const item = ResumeItem(
        id: 'i1',
        title: '后端工程师',
        categorySlug: 'experience',
        links: [ResumeLink(label: 'repo', url: 'https://x')],
        appendixRefs: ['A-2'],
      );
      final j = item.toJson();
      expect(j['appendix_refs'], ['A-2']);
      expect((j['links'] as List).single['url'], 'https://x');
    });
  });
}
