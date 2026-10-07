import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fonts = [
    'NotoSansSC-Regular', 'NotoSansSC-Bold',
    'NotoSerifSC-Regular', 'NotoSerifSC-Bold',
  ];
  for (final f in fonts) {
    testWidgets('嵌入 $f 可出 PDF', (tester) async {
      final data = await rootBundle.load('assets/fonts/$f.ttf');
      final font = pw.Font.ttf(data);
      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Text('中文测试 ABC 123',
            style: pw.TextStyle(font: font, fontSize: 14)),
      ));
      final bytes = await doc.save();
      expect(bytes.length, greaterThan(1000));
    });
  }
}
