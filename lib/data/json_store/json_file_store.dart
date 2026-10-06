/// 通用 JSON 文件读写，含外部修改冲突备份。
///
/// 冲突策略：实例维护每个路径「上次由本进程写入后观测到的 mtime」。
/// 写入前若文件仍存在且当前 mtime 与基线不同，说明被外部（同步/其他端）
/// 改动过，先把现有内容备份为 `<file>.conflict-<毫秒时间戳>` 再覆盖。
/// 首次遇到（无基线）只记录基线、不备份，避免误伤。
library;

import 'dart:convert';
import 'dart:io';

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/utils/file_utils.dart';

class JsonFileStore {
  JsonFileStore();

  /// 绝对路径 -> 上次写入/读取后观测到的 mtime。
  static final Map<String, DateTime> _baseline = {};

  Future<Map<String, dynamic>?> readMap(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        _remember(file);
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (e, st) {
      appLog.warning('读取 JSON 失败: ${file.path}', e, st);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> readMapList(File file) async {
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        _remember(file);
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
      return const [];
    } catch (e, st) {
      appLog.warning('读取 JSON 列表失败: ${file.path}', e, st);
      return const [];
    }
  }

  /// 原子写入；外部改动先备份。
  Future<void> writeMap(File file, Map<String, dynamic> data) async {
    await _backupIfExternallyChanged(file);
    await writeJsonAtomic(file.path, data);
    _remember(file);
  }

  static void _remember(File file) {
    try {
      final stat = file.statSync();
      _baseline[file.path] = stat.modified;
    } catch (_) {
      _baseline.remove(file.path);
    }
  }

  Future<void> _backupIfExternallyChanged(File file) async {
    if (!await file.exists()) return;
    final baseline = _baseline[file.path];
    if (baseline == null) return;
    final current = (await file.stat()).modified;
    if (current == baseline) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final backup = File('${file.path}${SyncLayout.conflictSuffix}-$stamp');
    await file.copy(backup.path);
    appLog.info('检测到外部修改，已备份: ${backup.path}');
  }
}
