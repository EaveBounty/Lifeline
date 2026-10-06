/// 密钥保险库信封加密（纯逻辑，不做任何 IO，可单测；web 兼容）。
///
/// 安全模型：
/// - **KEK**（密钥加密密钥）= PBKDF2-HMAC-SHA256(passphrase, salt, iters, 256bit)；
///   `iters` 由信封头部记录并在解锁时读取（支持未来 KDF 上调/升级）。
/// - **DEK**（数据加密密钥）= 32B 随机；用 AES-256-GCM 由 KEK 包装（wrappedDEK）。
/// - 明文 `secretsJson` 用 AES-256-GCM 由 DEK 加密（含 GCM tag）。
/// - 更换口令只需重新包装 DEK：DEK 与数据密文保持不变，仅以新口令/新盐重包 wrap 段。
///
/// 外层混淆（`LFV1` + 换行 base64）**仅用于让文件不被人肉一眼识别**，
/// **不是安全机制**：其 keystream 由硬编码常量推导，任何人可逆。
/// 真正的机密性与完整性来自「口令 + KDF + AEAD」，与混淆层无关。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';

/// 受控异常：口令错误、内容被篡改或格式非法（调用方据此提示，不应崩溃）。
class VaultException implements Exception {
  const VaultException(this.message);

  final String message;

  @override
  String toString() => 'VaultException: $message';
}

/// 解密结果：明文字典 + DEK（供解锁后内存持有、避免重复 PBKDF2）。
class VaultData {
  const VaultData({required this.secrets, required this.dek});

  final Map<String, String> secrets;
  final List<int> dek;
}

/// 创建信封结果：待写文件字符串 + DEK。
class VaultEnvelope {
  const VaultEnvelope({required this.fileContent, required this.dek});

  final String fileContent;
  final List<int> dek;
}

class CryptoVault {
  CryptoVault._();

  static const int kIterations = 210000;
  static const int kSaltLen = 16;
  static const int kNonceLen = 12;
  static const int kDekLen = 32;
  static const int kGcmTagLen = 16;
  static const String kMagic = 'LFV1';
  static const String kKdf = 'pbkdf2-sha256';
  static const int kVersion = 1;

  /// 口令最小长度（crypto 层强制，UI 校验只是第二道防线）。
  static const int kMinPassphraseLength = 8;

  /// 信封允许的最大迭代数（防篡改导致的 KDF DoS）。
  static const int kMaxIterations = 10000000;

  /// 混淆层常量（**非密钥**，公开且可逆）。
  static const String _obfApp = 'Lifeline/vault/obfuscation/v1';
  static const List<int> _obfSalt = <int>[
    0x4c, 0x46, 0x56, 0x31, 0x2e, 0x6f, 0x62, 0x66,
  ];
  static const int _obfLineLen = 76;

  static final Random _rng = Random.secure();

  static final AesGcm _aead = AesGcm.with256bits();

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  /// 用口令生成全新信封，返回**待写文件字符串**（已混淆）。
  static Future<String> createEnvelope({
    required String passphrase,
    required Map<String, String> secrets,
    int iters = kIterations,
  }) async {
    final env = await createEnvelopeData(
      passphrase: passphrase,
      secrets: secrets,
      iters: iters,
    );
    return env.fileContent;
  }

  /// 同 [createEnvelope]，但额外返回 DEK 供调用方内存持有。
  static Future<VaultEnvelope> createEnvelopeData({
    required String passphrase,
    required Map<String, String> secrets,
    int iters = kIterations,
  }) async {
    _validatePassphrase(passphrase);
    _validateIters(iters);
    final salt = _randomBytes(kSaltLen);
    final kek = await _deriveKek(passphrase, salt, iters);
    final dekBytes = _randomBytes(kDekLen);
    final dek = SecretKey(dekBytes);

    final wrapNonce = _randomBytes(kNonceLen);
    final wrapBox = await _aead.encrypt(dekBytes, secretKey: kek, nonce: wrapNonce);

    final dataNonce = _randomBytes(kNonceLen);
    final plain = utf8.encode(jsonEncode(secrets));
    final dataBox = await _aead.encrypt(plain, secretKey: dek, nonce: dataNonce);

    final envelope = <String, dynamic>{
      'v': kVersion,
      'kdf': kKdf,
      'iters': iters,
      'salt': base64.encode(salt),
      'wrap': {
        'n': base64.encode(wrapNonce),
        'c': base64.encode(_concat(wrapBox.cipherText, wrapBox.mac.bytes)),
      },
      'data': {
        'n': base64.encode(dataNonce),
        'c': base64.encode(_concat(dataBox.cipherText, dataBox.mac.bytes)),
      },
    };
    return VaultEnvelope(
      fileContent: _obfuscate(utf8.encode(jsonEncode(envelope))),
      dek: dekBytes,
    );
  }

  /// 用口令打开信封。口令错误或内容被篡改 → 抛 [VaultException]。
  static Future<Map<String, String>> openEnvelope({
    required String passphrase,
    required String fileContent,
  }) async {
    final data = await openEnvelopeData(passphrase: passphrase, fileContent: fileContent);
    return data.secrets;
  }

  /// 同 [openEnvelope]，但额外返回 DEK。
  static Future<VaultData> openEnvelopeData({
    required String passphrase,
    required String fileContent,
  }) async {
    final envelope = _parseEnvelope(fileContent);
    final salt = _b64(envelope['salt'], 'salt');
    if (salt.length != kSaltLen) {
      throw const VaultException('保险库文件损坏：salt 长度异常。');
    }
    final iters = _readIters(envelope);
    final kek = await _deriveKek(passphrase, salt, iters);

    final wrap = _sub(envelope['wrap'], 'wrap');
    final wrapC = _b64(wrap['c'], 'wrap.c');
    final wrapNonce = _b64(wrap['n'], 'wrap.n');
    if (wrapC.length < kGcmTagLen) {
      throw const VaultException('保险库文件损坏：wrapped DEK 非法。');
    }

    List<int> dekBytes;
    try {
      dekBytes = await _aead.decrypt(
        _unpackBox(wrapC, wrapNonce),
        secretKey: kek,
      );
    } catch (_) {
      throw const VaultException('口令错误或保险库已被篡改。');
    }

    final dataMap = _sub(envelope['data'], 'data');
    final dataC = _b64(dataMap['c'], 'data.c');
    final dataNonce = _b64(dataMap['n'], 'data.n');
    return VaultData(
      secrets: await _openData(dataC, dataNonce, dekBytes),
      dek: dekBytes,
    );
  }

  /// 用已知 DEK 直接打开数据段（设备缓存自动解锁用）。
  static Future<Map<String, String>> openWithDek({
    required List<int> dek,
    required String fileContent,
  }) async {
    final envelope = _parseEnvelope(fileContent);
    final dataMap = _sub(envelope['data'], 'data');
    final dataC = _b64(dataMap['c'], 'data.c');
    final dataNonce = _b64(dataMap['n'], 'data.n');
    try {
      return await _openData(dataC, dataNonce, dek);
    } on VaultException {
      throw const VaultException('设备缓存密钥无效或保险库已被篡改。');
    }
  }

  /// 用已知 DEK 重写数据段（保持 salt/wrap/迭代数不变），返回新文件字符串。
  static Future<String> writeDataWithDek({
    required List<int> dek,
    required Map<String, String> secrets,
    required String fileContent,
  }) async {
    final envelope = _parseEnvelope(fileContent);
    final dataNonce = _randomBytes(kNonceLen);
    final plain = utf8.encode(jsonEncode(secrets));
    final box = await _aead.encrypt(plain, secretKey: SecretKey(dek), nonce: dataNonce);
    envelope['data'] = {
      'n': base64.encode(dataNonce),
      'c': base64.encode(_concat(box.cipherText, box.mac.bytes)),
    };
    return _obfuscate(utf8.encode(jsonEncode(envelope)));
  }

  /// 改口令：**最小重包**——仅用新口令（新盐）重新包装既有 DEK，
  /// DEK 与数据密文保持不变；旧口令随即失效、新口令可开、数据不丢。
  static Future<String> rewrap({
    required String oldPass,
    required String newPass,
    required String fileContent,
  }) async {
    _validatePassphrase(newPass);
    final opened = await openEnvelopeData(
      passphrase: oldPass,
      fileContent: fileContent,
    );
    final envelope = _parseEnvelope(fileContent);
    final iters = _readIters(envelope);

    final newSalt = _randomBytes(kSaltLen);
    final newKek = await _deriveKek(newPass, newSalt, iters);
    final wrapNonce = _randomBytes(kNonceLen);
    final wrapBox = await _aead.encrypt(
      opened.dek,
      secretKey: newKek,
      nonce: wrapNonce,
    );

    final rewrapped = <String, dynamic>{
      'v': kVersion,
      'kdf': kKdf,
      'iters': iters,
      'salt': base64.encode(newSalt),
      'wrap': {
        'n': base64.encode(wrapNonce),
        'c': base64.encode(_concat(wrapBox.cipherText, wrapBox.mac.bytes)),
      },
      // 数据段原样保留（DEK 未变，密文保持有效）。
      'data': envelope['data'],
    };
    return _obfuscate(utf8.encode(jsonEncode(rewrapped)));
  }

  /// 是否看似本应用的保险库文件（只看外层魔数）。
  static bool looksLikeVault(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.isEmpty) return false;
    final firstLine = const LineSplitter().convert(trimmed).first.trim();
    return firstLine == kMagic;
  }

  /// 返回信封头部的可公开字段（用于状态展示/测试），**不含任何密钥材料**。
  static Map<String, dynamic> headerOf(String fileContent) {
    final env = _parseEnvelope(fileContent);
    return <String, dynamic>{
      'v': env['v'],
      'kdf': env['kdf'],
      'iters': env['iters'],
      'saltLen': _b64(env['salt'], 'salt').length,
      'hasWrap': env['wrap'] is Map,
      'hasData': env['data'] is Map,
    };
  }

  // --- internals ---

  static void _validatePassphrase(String passphrase) {
    if (passphrase.isEmpty) {
      throw const VaultException('口令不能为空。');
    }
    if (passphrase.length < kMinPassphraseLength) {
      throw const VaultException('口令至少 $kMinPassphraseLength 位。');
    }
  }

  static void _validateIters(int iters) {
    if (iters < 1 || iters > kMaxIterations) {
      throw const VaultException('保险库迭代数非法。');
    }
  }

  static int _readIters(Map<String, dynamic> envelope) {
    final iters = envelope['iters'];
    if (iters is! int || iters < 1 || iters > kMaxIterations) {
      throw const VaultException('保险库迭代数非法。');
    }
    return iters;
  }

  static Future<SecretKey> _deriveKek(
    String passphrase,
    List<int> salt,
    int iterations,
  ) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static Future<Map<String, String>> _openData(
    List<int> dataC,
    List<int> dataNonce,
    List<int> dek,
  ) async {
    if (dataC.length < kGcmTagLen) {
      throw const VaultException('保险库文件损坏：data 非法。');
    }
    List<int> plain;
    try {
      plain = await _aead.decrypt(
        _unpackBox(dataC, dataNonce),
        secretKey: SecretKey(dek),
      );
    } catch (_) {
      throw const VaultException('口令错误或保险库已被篡改。');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(plain));
    } catch (_) {
      throw const VaultException('保险库明文字典非法。');
    }
    if (decoded is! Map) throw const VaultException('保险库明文字典非法。');
    return decoded.map((k, v) => MapEntry('$k', '$v'));
  }

  static Map<String, dynamic> _parseEnvelope(String fileContent) {
    if (!looksLikeVault(fileContent)) {
      throw const VaultException('不是有效的密钥保险库文件。');
    }
    List<int> bytes;
    try {
      bytes = _deobfuscate(fileContent);
    } catch (_) {
      throw const VaultException('保险库文件损坏：混淆层解码失败。');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const VaultException('保险库文件损坏：信封不是合法 JSON。');
    }
    if (decoded is! Map) throw const VaultException('保险库信封格式非法。');
    final map = decoded.cast<String, dynamic>();
    if (map['v'] != kVersion) throw const VaultException('不支持的保险库版本。');
    if (map['kdf'] != kKdf) throw const VaultException('不支持的 KDF 算法。');
    if (map['iters'] is! int) throw const VaultException('保险库迭代数非法。');
    return map;
  }

  static Map<String, dynamic> _sub(dynamic v, String name) {
    if (v is! Map) throw VaultException('保险库字段缺失：$name。');
    return v.cast<String, dynamic>();
  }

  static Uint8List _b64(dynamic v, String name) {
    if (v is! String) throw VaultException('保险库字段非法：$name。');
    try {
      return Uint8List.fromList(base64.decode(v));
    } catch (_) {
      throw VaultException('保险库字段非法：$name。');
    }
  }

  /// 把 `cipherText || gcmTag` 拆回 [SecretBox]。
  static SecretBox _unpackBox(List<int> cWithTag, List<int> nonce) {
    final split = cWithTag.length - kGcmTagLen;
    return SecretBox(
      cWithTag.sublist(0, split),
      nonce: nonce,
      mac: Mac(cWithTag.sublist(split)),
    );
  }

  static Uint8List _concat(List<int> a, List<int> b) {
    final out = Uint8List(a.length + b.length)
      ..setAll(0, a)
      ..setAll(a.length, b);
    return out;
  }

  /// 可逆混淆 keystream：反复 `sha256(appConst || obfSalt || counter)`。
  static List<int> _keystream(int length) {
    final appBytes = utf8.encode(_obfApp);
    final out = Uint8List(length);
    var offset = 0;
    var counter = 0;
    while (offset < length) {
      final counterBytes = Uint8List(4)
        ..[0] = (counter >> 24) & 0xff
        ..[1] = (counter >> 16) & 0xff
        ..[2] = (counter >> 8) & 0xff
        ..[3] = counter & 0xff;
      final block = sha256
          .convert(<int>[...appBytes, ..._obfSalt, ...counterBytes])
          .bytes;
      final take = min(block.length, length - offset);
      out.setAll(offset, block.sublist(0, take));
      offset += take;
      counter++;
    }
    return out;
  }

  static String _obfuscate(List<int> bytes) {
    final ks = _keystream(bytes.length);
    final xored = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      xored[i] = bytes[i] ^ ks[i];
    }
    final b64 = base64.encode(xored);
    final buf = StringBuffer('$kMagic\n');
    for (var i = 0; i < b64.length; i += _obfLineLen) {
      buf.writeln(b64.substring(i, min(i + _obfLineLen, b64.length)));
    }
    return buf.toString();
  }

  static Uint8List _deobfuscate(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.isNotEmpty && lines.first.trim() == kMagic) {
      lines.removeAt(0);
    }
    final b64 = lines.map((e) => e.trim()).join();
    final xored = base64.decode(b64);
    final ks = _keystream(xored.length);
    final out = Uint8List(xored.length);
    for (var i = 0; i < xored.length; i++) {
      out[i] = xored[i] ^ ks[i];
    }
    return out;
  }
}
