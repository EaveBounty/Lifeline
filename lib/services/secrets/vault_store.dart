/// 密钥保险库的文件存取与解锁态（IO 层；web 内存 FS 亦可运行）。
///
/// 文件位置：`<syncRoot>/.lifeline/vault.dat`（随同步根同步）。
/// 解锁成功后在内存持有 DEK，后续 `readAll/writeAll` 不再重复 PBKDF2。
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/platform/io_platform.dart';
import '../../core/utils/file_utils.dart';
import 'crypto_vault.dart';

class VaultStore {
  VaultStore(this.rootPath);

  /// 同步根路径。
  final String rootPath;

  Map<String, String>? _secrets;
  List<int>? _dek;

  /// 文件绝对路径。
  String get path => p.join(rootPath, SyncLayout.internalDir, SyncLayout.vaultFile);

  File get _file => File(path);

  /// 保险库文件是否存在（同步读；web 内存 FS 同样适用）。
  bool get exists {
    try {
      return _file.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 是否已解锁（内存持有 DEK）。
  bool get unlocked => _dek != null;

  /// 已解锁时返回 DEK 的 base64（用于设备密钥库缓存）；未解锁返回 null。
  String? get dekBase64 => _dek == null ? null : base64.encode(_dek!);

  /// 创建保险库（新口令 + 初始明文），成功后自动进入解锁态。
  Future<void> create(String passphrase, Map<String, String> secrets) async {
    final envelope = await CryptoVault.createEnvelopeData(
      passphrase: passphrase,
      secrets: secrets,
    );
    await ensureDir(p.join(rootPath, SyncLayout.internalDir));
    await writeStringAtomic(path, envelope.fileContent);
    _dek = List<int>.from(envelope.dek);
    _secrets = Map<String, String>.from(secrets);
  }

  /// 用口令解锁。
  Future<void> unlock(String passphrase) async {
    final content = await _file.readAsString();
    final data = await CryptoVault.openEnvelopeData(
      passphrase: passphrase,
      fileContent: content,
    );
    _dek = List<int>.from(data.dek);
    _secrets = Map<String, String>.from(data.secrets);
  }

  /// 用已知 DEK 解锁（设备密钥库缓存路径）。
  Future<void> unlockWithDek(List<int> dek) async {
    final content = await _file.readAsString();
    final secrets = await CryptoVault.openWithDek(dek: dek, fileContent: content);
    _secrets = Map<String, String>.from(secrets);
    _dek = List<int>.from(dek);
  }

  /// 锁定：清除内存中的 DEK 与明文缓存。
  void lock() {
    _dek = null;
    _secrets = null;
  }

  /// 读取全部明文键值；未解锁抛 [VaultException]。
  Future<Map<String, String>> readAll() async {
    final secrets = _secrets;
    if (secrets == null) {
      throw const VaultException('密钥保险库已锁定。');
    }
    return Map<String, String>.from(secrets);
  }

  /// 覆盖写入全部明文（密文落盘）；未解锁抛 [VaultException]。
  Future<void> writeAll(Map<String, String> secrets) async {
    final dek = _dek;
    if (dek == null) throw const VaultException('密钥保险库已锁定。');
    final content = await _file.readAsString();
    final updated = await CryptoVault.writeDataWithDek(
      dek: dek,
      secrets: secrets,
      fileContent: content,
    );
    await writeStringAtomic(path, updated);
    _secrets = Map<String, String>.from(secrets);
  }

  Future<String?> read(String key) async => (await readAll())[key];

  Future<void> upsert(String key, String value) async {
    final secrets = await readAll();
    secrets[key] = value;
    await writeAll(secrets);
  }

  Future<void> deleteEntity(String key) async {
    final secrets = await readAll();
    secrets.remove(key);
    await writeAll(secrets);
  }

  /// 改口令（最小重包：仅用新口令/新盐重新包裹既有 DEK，数据密文不变），
  /// 成功后进入新口令解锁态。
  Future<void> changePassphrase(String oldPass, String newPass) async {
    final content = await _file.readAsString();
    final updated = await CryptoVault.rewrap(
      oldPass: oldPass,
      newPass: newPass,
      fileContent: content,
    );
    await writeStringAtomic(path, updated);
    await unlock(newPass);
  }
}
