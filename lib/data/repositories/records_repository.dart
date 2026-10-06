/// 记录仓库：真相源为 `data/records/<slug>/<id>.json`，同步维护 drift 索引。
library;

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/platform/io_platform.dart';
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

  String _dirFor(RecordCategory category) => p.join(
        rootPath,
        SyncLayout.dataDir,
        SyncLayout.recordsDir,
        category.slug,
      );

  File _fileFor(ProfileRecord record) {
    if (!isSafeId(record.id)) {
      throw ArgumentError.value(record.id, 'record.id', '记录 id 非法');
    }
    return File(p.join(_dirFor(record.category), '${record.id}.json'));
  }

  /// 扫描所有分类目录，容错跳过坏 JSON。
  Future<List<ProfileRecord>> loadAll() async {
    final out = <ProfileRecord>[];
    for (final category in RecordCategory.values) {
      final dir = Directory(_dirFor(category));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final map = await _store.readMap(entity);
        if (map == null) continue;
        try {
          out.add(ProfileRecord.fromJson(map));
        } catch (e) {
          appLog.warning('跳过坏记录: ${entity.path} ($e)');
        }
      }
    }
    out.sort((a, b) {
      final c = a.category.index.compareTo(b.category.index);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    return out;
  }

  Future<void> save(ProfileRecord record) async {
    await _store.writeMap(_fileFor(record), record.toJson());
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
      await _store.writeMap(_fileFor(record), record.toJson());
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
    for (final category in RecordCategory.values) {
      final file = File(p.join(_dirFor(category), '$id.json'));
      if (await file.exists()) return file;
    }
    return null;
  }
}
