/// 密钥存储：优先系统密钥库，失败时降级为本地权限文件。
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/platform/io_platform.dart';
import '../../core/utils/file_utils.dart';

class SecretStore {
  SecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// 与 [SyncLayout.secretsFile] 一致（App 支持目录内，不同步）。
  static const String _fallbackFilename = SyncLayout.secretsFile;

  bool _usingFallback = false;
  bool get usingFallback => _usingFallback;

  File? _fallbackFile;
  Map<String, String>? _cache;

  Future<File> _file() async {
    final cached = _fallbackFile;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, _fallbackFilename));
    _fallbackFile = file;
    return file;
  }

  Future<String?> read(String key) async {
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

  Future<void> write(String key, String value) async {
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

  Future<void> delete(String key) async {
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
