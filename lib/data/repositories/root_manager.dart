/// 同步根目录治理：探测 / 初始化 / 挂载 / 卸载。
///
/// 关键约束：[initialize] 只应由 UI 在用户明确选择目录后调用；
/// 任何路径都不删除用户已有内容。
library;

import 'package:path/path.dart' as p;
import 'package:yaml_writer/yaml_writer.dart';

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/platform/io_platform.dart';
import '../../core/result.dart';
import '../../core/utils/file_utils.dart';
import '../config/app_config.dart';
import '../models/app_settings.dart';
import '../models/profile.dart';
import '../models/record_category.dart';

/// 目录探测结果。
enum RootProbe {
  /// 不存在或不是目录。
  notDirectory,

  /// 空目录，可初始化。
  empty,

  /// 已是 Lifeline 同步根。
  initialized,

  /// 非空且无 Lifeline 标记，视为外来目录。
  foreign,
}

class RootManager {
  RootManager(this._config) : _rootPath = _config.syncRoot;

  final AppConfig _config;

  String? _rootPath;

  /// 当前同步根绝对路径。
  String? get rootPath => _rootPath;

  bool get hasRoot => _rootPath != null && _rootPath!.isNotEmpty;

  /// 存在 lifeline.yaml 即视为已初始化。
  bool get isInitialized =>
      hasRoot && File(p.join(_rootPath!, SyncLayout.configFile)).existsSync();

  String get _dataDir => p.join(_rootPath!, SyncLayout.dataDir);
  String get _recordsDir => p.join(_dataDir, SyncLayout.recordsDir);
  String get _resumesDir => p.join(_dataDir, SyncLayout.resumesDir);
  String get _attachmentsDir => p.join(_rootPath!, SyncLayout.attachmentsDir);
  String get _internalDir => p.join(_rootPath!, SyncLayout.internalDir);

  /// 探测目录状态，不修改任何内容。
  Future<RootProbe> probe(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: true);
    if (type != FileSystemEntityType.directory) return RootProbe.notDirectory;
    if (await File(p.join(path, SyncLayout.configFile)).exists()) {
      return RootProbe.initialized;
    }
    final entries = await Directory(path).list(followLinks: false).toList();
    final meaningful = entries
        .where((e) => !p.basename(e.path).startsWith('.'))
        .toList();
    return meaningful.isEmpty ? RootProbe.empty : RootProbe.foreign;
  }

  /// 用户确认后初始化同步根并挂载。绝不删除已有内容。
  Future<Result<void>> initialize(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final root = p.normalize(dir.absolute.path);
      _rootPath = root;

      for (final c in kDefaultCategories) {
        await ensureDir(p.join(_recordsDir, c.slug));
      }
      await ensureDir(_resumesDir);
      await ensureDir(_attachmentsDir);
      await ensureDir(_internalDir);

      final configFile = File(p.join(root, SyncLayout.configFile));
      if (!await configFile.exists()) {
        await writeStringAtomic(
          configFile.path,
          YamlWriter().write(AppSettings.initial().toJson()),
        );
      }

      final profileFile = File(p.join(_dataDir, SyncLayout.profileFile));
      if (!await profileFile.exists()) {
        await writeJsonAtomic(profileFile.path, Profile.empty().toJson());
      }

      final stateFile = File(p.join(_internalDir, SyncLayout.stateFile));
      if (!await stateFile.exists()) {
        await writeJsonAtomic(stateFile.path, {
          'schema_version': AppInfo.schemaVersion,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await _config.setSyncRoot(root);
      await _config.touchOpenedAt();
      appLog.info('已初始化同步根: $root');
      return const Ok<void>(null);
    } catch (e, st) {
      appLog.severe('初始化同步根失败', e, st);
      return Err<void>('初始化失败: $e', e);
    }
  }

  /// 挂载已初始化的同步根。
  Future<Result<void>> attach(String path) async {
    try {
      final probe = await this.probe(path);
      if (probe == RootProbe.notDirectory) {
        return const Err<void>('路径不存在或不是目录');
      }
      if (probe != RootProbe.initialized) {
        return const Err<void>('目录尚未初始化，请先初始化');
      }
      _rootPath = p.normalize(Directory(path).absolute.path);
      // 补齐可能缺失的数据目录（非破坏）。分类目录按需在实际写入时创建，
      // 以免把用户已删除的分类重新“复活”。
      await ensureDir(_recordsDir);
      await ensureDir(_resumesDir);
      await ensureDir(_attachmentsDir);
      await _config.setSyncRoot(_rootPath);
      await _config.touchOpenedAt();
      appLog.info('已挂载同步根: $_rootPath');
      return const Ok<void>(null);
    } catch (e, st) {
      appLog.severe('挂载同步根失败', e, st);
      return Err<void>('挂载失败: $e', e);
    }
  }

  /// 卸载（仅清除记录，不删除磁盘内容）。
  Future<void> detach() async {
    _rootPath = null;
    await _config.setSyncRoot(null);
  }

  /// 记录索引库文件。
  File get indexFile => File(p.join(_dataDir, SyncLayout.indexFile));

  /// 单例 profile 文件。
  File get profileFile => File(p.join(_dataDir, SyncLayout.profileFile));

  /// 必填子目录路径（供仓库层复用）。
  String get resumesDir => _resumesDir;
  String get attachmentsDir => _attachmentsDir;
}
