import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/services/secrets/crypto_vault.dart';

void main() {
  group('CryptoVault 信封加密（纯逻辑）', () {
    const pass = 'correct horse battery staple';
    final secrets = <String, String>{
      'openai': 'sk-test-1234567890',
      'deepseek': 'sk-deep-xyz',
    };
    late String content;

    setUpAll(() async {
      content = await CryptoVault.createEnvelope(
        passphrase: pass,
        secrets: secrets,
      );
    });

    test('建→开 往返一致', () async {
      final out = await CryptoVault.openEnvelope(
        passphrase: pass,
        fileContent: content,
      );
      expect(out, secrets);
    });

    test('错误口令抛 VaultException（不崩）', () async {
      await expectLater(
        CryptoVault.openEnvelope(passphrase: 'wrong-pass', fileContent: content),
        throwsA(isA<VaultException>()),
      );
    });

    test('篡改任一字节 → 认证失败（VaultException）', () async {
      final lines = content.trim().split('\n')..removeAt(0);
      final bytes = base64.decode(lines.join());
      bytes[bytes.length - 20] ^= 0x01;
      final tampered = 'LFV1\n${base64.encode(bytes)}';
      await expectLater(
        CryptoVault.openEnvelope(passphrase: pass, fileContent: tampered),
        throwsA(isA<VaultException>()),
      );
    });

    test('文件不含明文密钥且 looksLikeVault 为真', () {
      expect(content.contains('sk-test-1234567890'), isFalse);
      expect(content.contains('sk-deep-xyz'), isFalse);
      expect(content.contains('openai'), isFalse);
      expect(CryptoVault.looksLikeVault(content), isTrue);
      expect(content.trimLeft().startsWith(CryptoVault.kMagic), isTrue);
    });

    test('头部含版本/KDF/迭代数/包裹与数据字段', () {
      final header = CryptoVault.headerOf(content);
      expect(header['v'], CryptoVault.kVersion);
      expect(header['kdf'], CryptoVault.kKdf);
      expect(header['iters'], CryptoVault.kIterations);
      expect(header['saltLen'], CryptoVault.kSaltLen);
      expect(header['hasWrap'], isTrue);
      expect(header['hasData'], isTrue);
    });

    test('改口令后旧口令失败、新口令成功', () async {
      const newPass = 'new-pass-9876';
      final newContent = await CryptoVault.rewrap(
        oldPass: pass,
        newPass: newPass,
        fileContent: content,
      );
      await expectLater(
        CryptoVault.openEnvelope(passphrase: pass, fileContent: newContent),
        throwsA(isA<VaultException>()),
      );
      final out = await CryptoVault.openEnvelope(
        passphrase: newPass,
        fileContent: newContent,
      );
      expect(out, secrets);
    });

    test('M1：空口令在 crypto 层被拒', () async {
      await expectLater(
        CryptoVault.createEnvelope(passphrase: '', secrets: const {}),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        CryptoVault.createEnvelopeData(passphrase: '', secrets: const {}),
        throwsA(isA<VaultException>()),
      );
    });

    test('M1：过短口令（<8）被拒', () async {
      await expectLater(
        CryptoVault.createEnvelope(passphrase: 'short', secrets: const {}),
        throwsA(isA<VaultException>()),
      );
    });

    test('M1：rewrap 拒绝过短新口令', () async {
      await expectLater(
        CryptoVault.rewrap(
          oldPass: pass,
          newPass: '1234567',
          fileContent: content,
        ),
        throwsA(isA<VaultException>()),
      );
    });

    test('M2：按信封头记录的自定义 iters 派生并成功打开', () async {
      final custom = await CryptoVault.createEnvelopeData(
        passphrase: pass,
        secrets: secrets,
        iters: 5000,
      );
      expect(CryptoVault.headerOf(custom.fileContent)['iters'], 5000);
      final out = await CryptoVault.openEnvelope(
        passphrase: pass,
        fileContent: custom.fileContent,
      );
      expect(out, secrets);
    });

    test('M3：rewrap 为最小重包，DEK 与数据均不变', () async {
      const newPass = 'another-strong-pass';
      final before = await CryptoVault.openEnvelopeData(
        passphrase: pass,
        fileContent: content,
      );
      final newContent = await CryptoVault.rewrap(
        oldPass: pass,
        newPass: newPass,
        fileContent: content,
      );
      final after = await CryptoVault.openEnvelopeData(
        passphrase: newPass,
        fileContent: newContent,
      );
      expect(after.dek, before.dek);
      expect(after.secrets, before.secrets);
      expect(
        CryptoVault.headerOf(newContent)['iters'],
        CryptoVault.kIterations,
      );
    });
  });
}
