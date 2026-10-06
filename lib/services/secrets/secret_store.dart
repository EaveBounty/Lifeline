/// 密钥存储门面：组合「加密密钥保险库（可同步）」与「系统密钥库 / 本地降级文件」。
///
/// - 保险库存在时：读写走 vault（需已解锁）；**锁定态不回退旧后端**，`read` 返回
///   null、`write`/`delete` 抛受控错误，避免锁定被绕过。
/// - 保险库不存在时：沿用原逻辑（keychain 优先，失败降级本地权限文件，不同步）。
/// - 迁移（[migrateFromLocal]/[createVaultFromLocal]）默认删除已迁移的旧后端源键。
/// - 解锁后把 DEK 缓存进系统密钥库（键 [deviceDekKey]），启动可自动解锁；
///   [forgetDevice] 清除该缓存并如实反馈删除结果。
///
/// 密钥永不写入同步 YAML、永不落日志。
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/platform/io_platform.dart';
import '../../core/utils/file_utils.dart';
import 'crypto_vault.dart';
import 'vault_store.dart';

class SecretStore {
  SecretStore({String? rootPath, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        vault = rootPath == null ? null : VaultStore(rootPath);

  final FlutterSecureStorage _storage;

  /// 加密保险库（随同步根同步）；未挂载同步根时为 null。
  final VaultStore? vault;

  /// 设备密钥库中缓存 DEK 的键名。
  static const String deviceDekKey = '__vault_dek__';

  /// 与 [SyncLayout.secretsFile] 一致（App 支持目录内，不同步）。
  static const String _fallbackFilename = SyncLayout.secretsFile;

  bool _usingFallback = false;
  bool get usingFallback => _usingFallback;

  File? _fallbackFile;
  Map<String, String>? _cache;

  // --- 保险库状态 ---

  bool get vaultExists => vault?.exists ?? false;
  bool get vaultUnlocked => vault?.unlocked ?? false;

  // --- 读写门面 ---

  Future<String?> read(String key) async {
    final v = vault;
    if (v != null && v.exists) {
      if (!v.unlocked) {
        // 锁定态：不得回退旧后端（否则锁定语义被绕过）。视为「无此键」。
        return null;
      }
      final all = await v.readAll();
      if (all.containsKey(key)) return all[key];
      // 已解锁：未迁移的历史键方可回退旧后端，保证兼容。
    }
    return _readLegacy(key);
  }

  Future<void> write(String key, String value) async {
    final v = vault;
    if (v != null && v.exists) {
      if (!v.unlocked) {
        throw const VaultException('密钥保险库已锁定，请先在「设置 → 密钥保险库」解锁。');
      }
      await v.upsert(key, value);
      return;
    }
    await _writeLegacy(key, value);
  }

  Future<void> delete(String key) async {
    final v = vault;
    if (v != null && v.exists) {
      if (!v.unlocked) {
        throw const VaultException('密钥保险库已锁定，请先在「设置 → 密钥保险库」解锁。');
      }
      await v.deleteEntity(key);
      return;
    }
    await _deleteLegacy(key);
  }

  /// 读取旧后端（keychain 或降级文件）的全部键值；供迁移使用。
  ///
  /// 保险库已存在但未解锁时返回空表：锁定态不得泄漏旧后端内容。
  Future<Map<String, String>> readAll() async {
    final v = vault;
    if (v != null && v.exists && !v.unlocked) {
      return <String, String>{};
    }
    if (!_usingFallback) {
      try {
        return await _storage.readAll();
      } catch (e) {
        appLog.warning('系统密钥库不可用，降级本地文件密钥: $e');
        _usingFallback = true;
      }
    }
    return Map<String, String>.from(await _loadFallback());
  }

  // --- 保险库操作 ---

  Future<void> createVault(String passphrase, Map<String, String> secrets) async {
    final v = vault;
    if (v == null) throw const VaultException('未挂载同步根，无法创建密钥保险库。');
    await v.create(passphrase, secrets);
    await _cacheDek();
  }

  Future<void> unlockVault(String passphrase) async {
    final v = vault;
    if (v == null) throw const VaultException('未挂载同步根。');
    await v.unlock(passphrase);
    await _cacheDek();
  }

  void lockVault() => vault?.lock();

  Future<Map<String, String>> readVaultAll() async =>
      vault?.readAll() ?? <String, String>{};

  Future<void> changeVaultPassphrase(String oldPass, String newPass) async {
    final v = vault;
    if (v == null) throw const VaultException('未挂载同步根。');
    await v.changePassphrase(oldPass, newPass);
    await _cacheDek();
  }

  /// 启动自动解锁：仅用设备密钥库缓存的 DEK，不弹口令。
  Future<bool> tryAutoUnlock() async {
    final v = vault;
    if (v == null) return false;
    if (v.unlocked) return true;
    if (!v.exists) return false;
    final cached = await _readDeviceDek();
    if (cached == null) return false;
    try {
      await v.unlockWithDek(cached);
      return true;
    } catch (e) {
      appLog.warning('设备缓存的保险库密钥失效，已清除: $e');
      await _clearDeviceDek();
      return false;
    }
  }

  /// 设备密钥库是否存在缓存 DEK。
  Future<bool> hasDeviceCache() async => (await _readDeviceDek()) != null;

  /// 清除本机缓存并锁定（不影响保险库文件）。
  ///
  /// 返回是否确实删除了系统密钥库中的缓存 DEK；失败时调用方不得当作成功。
  Future<bool> forgetDevice() async {
    lockVault();
    return _clearDeviceDek();
  }

  /// 用旧后端现有密钥初始化新保险库；迁移后默认删除旧后端源键。
  Future<void> createVaultFromLocal(String passphrase) async {
    final legacy = await readAll();
    await createVault(passphrase, legacy);
    for (final key in legacy.keys) {
      await _deleteLegacy(key);
    }
  }

  /// 把旧后端的全部键值并入保险库；[deleteAfter] 为真时随后删除源键。
  ///
  /// 默认删除源键：旧后端残留会与锁定语义冲突（尽管锁定态已不再回退旧后端）。
  Future<void> migrateFromLocal({bool deleteAfter = true}) async {
    final v = vault;
    if (v == null || !v.exists) {
      throw const VaultException('请先创建密钥保险库。');
    }
    if (!v.unlocked) {
      throw const VaultException('请先解锁密钥保险库。');
    }
    final legacy = await readAll();
    if (legacy.isEmpty) return;
    final merged = await v.readAll();
    for (final entry in legacy.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }
    await v.writeAll(merged);
    if (deleteAfter) {
      for (final key in legacy.keys) {
        await _deleteLegacy(key);
      }
    }
  }

  // --- 设备 DEK 缓存 ---

  Future<List<int>?> _readDeviceDek() async {
    try {
      final value = await _storage.read(key: deviceDekKey);
      if (value == null || value.isEmpty) return null;
      return base64.decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheDek() async {
    final encoded = vault?.dekBase64;
    if (encoded == null) return;
    try {
      await _storage.write(key: deviceDekKey, value: encoded);
    } catch (e) {
      appLog.warning('无法缓存保险库设备密钥（系统密钥库不可用）: $e');
    }
  }

  Future<bool> _clearDeviceDek() async {
    try {
      await _storage.delete(key: deviceDekKey);
      return true;
    } catch (e) {
      appLog.warning('清除设备保险库缓存失败（系统密钥库可能仍可自动解锁）: $e');
      return false;
    }
  }

  // --- 旧后端（keychain / 降级文件） ---

  Future<String?> _readLegacy(String key) async {
    if (!_usingFallback) {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        appLog.warning('系统密钥库不可用，降级本地文件密钥: $e');
        _usingFallback = true;
      }
    }
    return (await _loadFallback())[key];
  }

  Future<void> _writeLegacy(String key, String value) async {
    if (!_usingFallback) {
      try {
        await _storage.write(key: key, value: value);
        return;
      } catch (e) {
        appLog.warning('系统密钥库不可用，降级本地文件密钥: $e');
        _usingFallback = true;
      }
    }
    final map = await _loadFallback();
    map[key] = value;
    await _saveFallback(map);
  }

  Future<void> _deleteLegacy(String key) async {
    if (!_usingFallback) {
      try {
        await _storage.delete(key: key);
        return;
      } catch (e) {
        appLog.warning('系统密钥库不可用，降级本地文件密钥: $e');
        _usingFallback = true;
      }
    }
    final map = await _loadFallback();
    map.remove(key);
    await _saveFallback(map);
  }

  Future<File> _file() async {
    final cached = _fallbackFile;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, _fallbackFilename));
    _fallbackFile = file;
    return file;
  }

  Future<Map<String, String>> _loadFallback() async {
    final cached = _cache;
    if (cached != null) return cached;
    final file = await _file();
    var map = <String, String>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          map = decoded.map((k, v) => MapEntry('$k', '$v'));
        }
      } catch (_) {
        map = {};
      }
    }
    _cache = map;
    return map;
  }

  Future<void> _saveFallback(Map<String, String> map) async {
    final file = await _file();
    _cache = map;
    await writeStringAtomic(
      file.path,
      const JsonEncoder.withIndent('  ').convert(map),
    );
    await _restrictPermissions(file);
  }

  Future<void> _restrictPermissions(File file) async {
    if (Platform.isWindows) return;
    try {
      final r = await Process.run('chmod', ['600', file.path]);
      if (r.exitCode != 0) {
        appLog.warning('chmod 600 失败: ${file.path}');
      }
    } catch (_) {
      // 尽力而为。
    }
  }
}
