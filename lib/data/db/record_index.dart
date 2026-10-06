/// 记录/附件派生索引的抽象接口。
///
/// 原生端由 drift（`LifelineDatabase`）实现；Web 端由纯内存实现。
/// 真相源始终是同步根内的 JSON 文件，本索引可随时重建。
library;

import '../models/attachment.dart';
import '../models/profile_record.dart';

abstract interface class RecordIndex {
  Future<List<ProfileRecord>> allRecords();

  Future<void> upsertRecord(ProfileRecord record);

  Future<void> upsertRecords(List<ProfileRecord> records);

  Future<void> deleteRecord(String id);

  Future<int> recordCount();

  Stream<int> watchRecordCount();

  Future<List<Attachment>> allAttachments();

  Future<void> upsertAttachment(Attachment attachment);

  Future<void> upsertAttachments(List<Attachment> attachments);

  Future<void> deleteAttachment(String id);

  Future<void> clearAll();

  Future<void> close();
}
