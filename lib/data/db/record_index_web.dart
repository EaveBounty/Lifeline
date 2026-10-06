/// Web 端索引工厂：纯内存 [RecordIndex] 实现。
library;

import 'dart:async';

import '../models/attachment.dart';
import '../models/profile_record.dart';
import 'record_index.dart';

/// 打开内存索引（忽略 [path]，Web 无磁盘）。
RecordIndex openRecordIndex(String path) => MemoryRecordIndex();

/// 进程内内存索引：Map 存储，行为与 drift 版本一致。
class MemoryRecordIndex implements RecordIndex {
  final Map<String, ProfileRecord> _records = <String, ProfileRecord>{};
  final Map<String, Attachment> _attachments = <String, Attachment>{};
  final StreamController<int> _count =
      StreamController<int>.broadcast();

  @override
  Future<List<ProfileRecord>> allRecords() async {
    final list = _records.values.toList()
      ..sort((a, b) {
        final c = a.category.index.compareTo(b.category.index);
        if (c != 0) return c;
        return a.order.compareTo(b.order);
      });
    return list;
  }

  @override
  Future<void> upsertRecord(ProfileRecord record) async {
    _records[record.id] = record;
    _emit();
  }

  @override
  Future<void> upsertRecords(List<ProfileRecord> records) async {
    if (records.isEmpty) return;
    for (final r in records) {
      _records[r.id] = r;
    }
    _emit();
  }

  @override
  Future<void> deleteRecord(String id) async {
    _records.remove(id);
    _emit();
  }

  @override
  Future<int> recordCount() async => _records.length;

  @override
  Stream<int> watchRecordCount() => _count.stream;

  @override
  Future<List<Attachment>> allAttachments() async {
    final list = _attachments.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> upsertAttachment(Attachment attachment) async {
    _attachments[attachment.id] = attachment;
  }

  @override
  Future<void> upsertAttachments(List<Attachment> attachments) async {
    for (final a in attachments) {
      _attachments[a.id] = a;
    }
  }

  @override
  Future<void> deleteAttachment(String id) async {
    _attachments.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _attachments.clear();
    _records.clear();
    _emit();
  }

  @override
  Future<void> close() async {
    if (!_count.isClosed) await _count.close();
  }

  void _emit() {
    if (!_count.isClosed) _count.add(_records.length);
  }
}
