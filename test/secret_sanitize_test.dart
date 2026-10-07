import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/core/utils/secret_sanitize.dart';

void main() {
  group('secret_sanitize', () {
    test('去除换行、制表与控制字符', () {
      expect(sanitizeSecret('  sk-abc\n'), 'sk-abc');
      expect(sanitizeSecret('sk-a\tb\r\n'), 'sk-ab');
    });

    test('合法密钥可通过校验', () {
      expect(validateSecret('sk-1234567890abcdef'), isNull);
      expect(validateSecret(''), isNull); // 空＝不发送
    });

    test('中文/换行/空格被判为非法（避免 header FormatException）', () {
      const bad = '无法连接到已保存的服务器·请确认它正在运行：或选择其他实例·';
      expect(validateSecret(sanitizeSecret(bad)), isNotNull);
      expect(validateSecret('my key'), isNotNull);
    });

    test('脱敏预览', () {
      expect(maskSecret('sk-1234567890'), 'sk-…90');
      expect(maskSecret('short'), '****');
    });
  });
}
