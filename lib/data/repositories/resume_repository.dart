/// 定向简历仓库：管理 `data/resumes/<id>/`（meta.json / spec.json / 导出文件）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/path_guard.dart';
import '../json_store/json_file_store.dart';
import '../models/export_request.dart';
import '../models/resume_doc.dart';

class ResumeRepository {
  ResumeRepository(this.rootPath);

  final String rootPath;
  final JsonFileStore _store = JsonFileStore();

  String get _root => p.join(rootPath, SyncLayout.dataDir, SyncLayout.resumesDir);

  /// resume id -> 目录；id 非法（路径遍历）时抛 [ArgumentError]。
  String _dir(String id) {
    if (!isSafeId(id)) {
      throw ArgumentError.value(id, 'resume.id', '简历 id 非法');
    }
    final dir = p.normalize(p.join(_root, id));
    final rootAbs = p.normalize(_root);
    if (!dir.startsWith('$rootAbs${p.separator}')) {
      throw ArgumentError.value(id, 'resume.id', '简历路径越界');
    }
    return dir;
  }

  Future<List<ResumeMeta>> listMeta() async {
    final dir = Directory(_root);
    if (!await dir.exists()) return const [];
    final out = <ResumeMeta>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final map = await _store.readMap(File(p.join(entity.path, 'meta.json')));
      if (map == null) continue;
      try {
        out.add(ResumeMeta.fromJson(map));
      } catch (e) {
        appLog.warning('跳过坏简历元数据: ${entity.path} ($e)');
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<void> saveMeta(ResumeMeta meta) async {
    await ensureDir(_dir(meta.id));
    await _store.writeMap(
      File(p.join(_dir(meta.id), 'meta.json')),
      meta.toJson(),
    );
  }

  Future<void> saveSpec(String id, ResumeDocument document) async {
    await ensureDir(_dir(id));
    await _store.writeMap(
      File(p.join(_dir(id), 'spec.json')),
      document.toJson(),
    );
  }

  Future<void> saveFile(String id, String format, List<int> bytes) async {
    final file = File(p.join(_dir(id), 'resume.$format'));
    await writeBytesAtomic(file.path, bytes);
  }

  Future<void> delete(String id) async {
    final dir = Directory(_dir(id));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<ResumeDocument?> loadSpec(String id) async {
    final map = await _store.readMap(File(p.join(_dir(id), 'spec.json')));
    if (map == null) return null;
    try {
      return ResumeDocument.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
