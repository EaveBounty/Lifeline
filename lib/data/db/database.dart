/// Drift 派生索引：真相源是 records/*.json，本库可随时重建。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../models/attachment.dart';
import '../models/profile_record.dart';

part 'database.g.dart';

/// 记录索引表。bodyJson 存完整 ProfileRecord JSON。
@DataClassName('RecordRow')
class Records extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  TextColumn get organization => text().nullable()();
  TextColumn get role => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get startDate => text().nullable()();
  TextColumn get endDate => text().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get bodyJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 附件索引表。
@DataClassName('AttachmentRow')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get recordId => text().nullable()();
  TextColumn get relPath => text()();
  TextColumn get filename => text()();
  TextColumn get mime => text().nullable()();
  IntColumn get size => integer().withDefault(const Constant(0))();
  TextColumn get sha1 => text()();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Records, Attachments])
class LifelineDatabase extends _$LifelineDatabase {
  /// [executor] 仅用于测试注入（如内存库）；生产默认后台打开 [indexFile]。
  LifelineDatabase(File indexFile, {QueryExecutor? executor})
      : super(executor ?? NativeDatabase.createInBackground(indexFile));

  /// 打开前确保父目录存在。
  static Future<LifelineDatabase> open(File indexFile) async {
    final parent = indexFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    return LifelineDatabase(indexFile);
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) async => m.createAll());

  Future<List<ProfileRecord>> allRecords() async {
    final rows = await (select(records)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    final out = <ProfileRecord>[];
    for (final row in rows) {
      final parsed = _decodeRecord(row.bodyJson);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  Future<void> upsertRecord(ProfileRecord record) =>
      into(records).insertOnConflictUpdate(_companion(record));

  Future<void> upsertRecords(List<ProfileRecord> list) async {
    if (list.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(records, list.map(_companion).toList());
    });
  }

  Future<void> deleteRecord(String id) =>
      (delete(records)..where((t) => t.id.equals(id))).go();

  Future<int> recordCount() async {
    final countExp = records.id.count();
    final row =
        await (selectOnly(records)..addColumns([countExp])).getSingle();
    return row.read(countExp) ?? 0;
  }

  Stream<int> watchRecordCount() {
    final countExp = records.id.count();
    return (selectOnly(records)..addColumns([countExp]))
        .map((row) => row.read(countExp) ?? 0)
        .watchSingle();
  }

  Future<List<Attachment>> allAttachments() async {
    final rows = await (select(attachments)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    return rows.map(_toAttachment).toList();
  }

  Future<void> upsertAttachment(Attachment attachment) =>
      into(attachments).insertOnConflictUpdate(_attachmentCompanion(attachment));

  Future<void> upsertAttachments(List<Attachment> list) async {
    if (list.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(
        attachments,
        list.map(_attachmentCompanion).toList(),
      );
    });
  }

  Future<void> deleteAttachment(String id) =>
      (delete(attachments)..where((t) => t.id.equals(id))).go();

  Future<void> clearAll() async {
    await delete(attachments).go();
    await delete(records).go();
  }

  RecordsCompanion _companion(ProfileRecord r) => RecordsCompanion.insert(
        id: r.id,
        category: r.category.slug,
        title: r.title,
        organization: Value(r.organization),
        role: Value(r.role),
        location: Value(r.location),
        startDate: Value(r.startDate),
        endDate: Value(r.endDate),
        description: Value(r.description),
        bodyJson: jsonEncode(r.toJson()),
        updatedAt: r.updatedAt,
        sortOrder: Value(r.order),
      );

  AttachmentsCompanion _attachmentCompanion(Attachment a) =>
      AttachmentsCompanion.insert(
        id: a.id,
        recordId: Value(a.recordId),
        relPath: a.relPath,
        filename: a.filename,
        mime: Value(a.mime),
        size: Value(a.size),
        sha1: a.sha1,
        caption: Value(a.caption),
        createdAt: a.createdAt,
      );

  Attachment _toAttachment(AttachmentRow r) => Attachment(
        id: r.id,
        recordId: r.recordId,
        relPath: r.relPath,
        filename: r.filename,
        mime: r.mime,
        size: r.size,
        sha1: r.sha1,
        caption: r.caption,
        createdAt: r.createdAt,
      );

  static ProfileRecord? _decodeRecord(String bodyJson) {
    try {
      return ProfileRecord.fromJson(
        (jsonDecode(bodyJson) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }
}
