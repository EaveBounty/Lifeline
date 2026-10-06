/// 记录仓库：真相源为 `data/records/<slug>/<id>.json`，同步维护 drift 索引。
library;

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/platform/io_platform.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/path_guard.dart';
import '../db/record_index.dart';
import '../json_store/json_file_store.dart';
import '../models/profile_record.dart';
import '../models/record_category.dart';
import 'attachment_repository.dart';
import 'profile_repository.dart';

class RecordsRepository {
  RecordsRepository({required this.rootPath, required this.db});

  final String rootPath;
  final RecordIndex db;
  final JsonFileStore _store = JsonFileStore();

  /// 记录根目录（其下按分类 slug 分子目录）。
  String get _recordsBase =>
      p.join(rootPath, SyncLayout.dataDir, SyncLayout.recordsDir);

  String _dirFor(String slug) => p.join(_recordsBase, sanitizeSlug(slug));

  File _fileFor(ProfileRecord record) {
    if (!isSafeId(record.id)) {
      throw ArgumentError.value(record.id, 'record.id', '记录 id 非法');
    }
    return File(p.join(_dirFor(record.categorySlug), '${record.id}.json'));
  }

  /// 扫描记录根下所有分类子目录，容错跳过坏 JSON。
  ///
  /// 遍历磁盘实际存在的子目录（而非固定分类枚举），因此用户新增/删除分类
  /// 或存在未登记分类的旧数据都能被载入。
  Future<List<ProfileRecord>> loadAll() async {
    final out = <ProfileRecord>[];
    final base = Directory(_recordsBase);
    if (await base.exists()) {
      await for (final entity in base.list(followLinks: false)) {
        if (entity is! Directory) continue;
        await for (final file in entity.list(followLinks: false)) {
          if (file is! File || !file.path.endsWith('.json')) continue;
          final map = await _store.readMap(file);
          if (map == null) continue;
          try {
            out.add(ProfileRecord.fromJson(map));
          } catch (e) {
            appLog.warning('跳过坏记录: ${file.path} ($e)');
          }
        }
      }
    }
    out.sort((a, b) {
      final c = a.categorySlug.compareTo(b.categorySlug);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    return out;
  }

  Future<void> save(ProfileRecord record) async {
    final file = _fileFor(record);
    await ensureDir(file.parent.path);
    await _store.writeMap(file, record.toJson());
    await db.upsertRecord(record);
  }

  Future<void> delete(String id) async {
    final file = await _findFile(id);
    if (file != null && await file.exists()) {
      await file.delete();
    }
    await db.deleteRecord(id);
  }

  /// 导入记录：逐条校验 id，非法者跳过并记录告警，绝不越界写盘。
  Future<void> importAll(List<ProfileRecord> records) async {
    final valid = <ProfileRecord>[];
    for (final record in records) {
      if (!isSafeId(record.id)) {
        appLog.warning('跳过非法 id 的记录: ${record.id}');
        continue;
      }
      final file = _fileFor(record);
      await ensureDir(file.parent.path);
      await _store.writeMap(file, record.toJson());
      valid.add(record);
    }
    await db.upsertRecords(valid);
  }

  /// 清空索引后从 JSON + profile 声明全量重建（含附件索引）。
  Future<void> rebuildIndex() async {
    final all = await loadAll();
    final declared = <DeclaredAttachment>[];
    for (final record in all) {
      for (final rel in record.attachments) {
        declared.add(DeclaredAttachment(rel, recordId: record.id));
      }
    }
    // profile 声明：头像/证件照 + 各字段附件。
    final profile = await ProfileRepository(rootPath).load();
    final photo = profile.photoPath;
    if (photo != null && photo.trim().isNotEmpty) {
      declared.add(DeclaredAttachment(photo));
    }
    for (final section in profile.sections.values) {
      for (final field in section.values) {
        for (final rel in field.attachments) {
          declared.add(DeclaredAttachment(rel));
        }
      }
    }
    final attachments = await AttachmentRepository(rootPath: rootPath, db: db)
        .rebuildFromDeclarations(declared);

    await db.clearAll();
    await db.upsertRecords(all);
    await db.upsertAttachments(attachments);
  }

  Future<File?> _findFile(String id) async {
    if (!isSafeId(id)) return null;
    final base = Directory(_recordsBase);
    if (!await base.exists()) return null;
    await for (final entity in base.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final file = File(p.join(entity.path, '$id.json'));
      if (await file.exists()) return file;
    }
    return null;
  }

  /// 把某分类下的全部记录移动到另一个分类（删除分类前使用）。
  ///
  /// 返回迁移的记录数。仅重写 JSON 并删除旧文件；索引由 [rebuildIndex] 或
  /// 调用方的后续刷新更新。
  Future<int> moveCategory(String fromSlug, String toSlug) async {
    final from = sanitizeSlug(fromSlug);
    final to = sanitizeSlug(toSlug);
    if (from == to) return 0;
    final fromDir = Directory(_dirFor(from));
    if (!await fromDir.exists()) return 0;
    var moved = 0;
    await for (final entity in fromDir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final map = await _store.readMap(entity);
      if (map == null) continue;
      final record = ProfileRecord.fromJson(map).copyWith(categorySlug: to);
      final dest = File(p.join(_dirFor(to), '${record.id}.json'));
      await ensureDir(dest.parent.path);
      await _store.writeMap(dest, record.toJson());
      await entity.delete();
      await db.upsertRecord(record);
      moved++;
    }
    return moved;
  }
}
