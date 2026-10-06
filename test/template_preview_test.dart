import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/features/export/template_preview.dart';
import 'package:lifeline/services/render/templates.dart';

void main() {
  testWidgets('每个模板都能渲染 TemplatePreview 且无异常', (tester) async {
    for (final t in ResumeTemplates.all) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: TemplatePreview(template: t)),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '模板 ${t.id} 渲染异常');
      expect(find.byType(TemplatePreview), findsOneWidget);
    }
  });

  testWidgets('showLabels 标注版式顺序且无异常', (tester) async {
    for (final t in ResumeTemplates.all) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TemplatePreview(
                template: t,
                width: 160,
                showLabels: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '模板 ${t.id} 标注异常');
    }
  });

  testWidgets('窄尺寸约束下尺寸受控且不溢出', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 640);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TemplatePreview(
              template: ResumeTemplates.all.first,
              width: 700,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(TemplatePreview));
    expect(size.width, lessThanOrEqualTo(320));
  });

  testWidgets('宽度约束被尊重（220 默认）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TemplatePreview(template: ResumeTemplates.all.first),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(TemplatePreview));
    expect(size.width, 220);
    expect(size.height, closeTo(220 * 1.32, 0.01));
  });
}
