/// 原生端索引工厂：返回 drift 支持的 [LifelineDatabase]。
library;

import 'dart:io';

import 'database.dart';
import 'record_index.dart';

/// 打开（或创建）索引库。
///
/// 关键：**同步确保父目录存在**——drift 的 `NativeDatabase.createInBackground`
/// 不会创建父目录，缺失时会报 `SqliteException(14) unable to open database file`。
/// 生产路径已改为 App 私有目录（见 `databaseProvider`），此处兜底仍保留。
RecordIndex openRecordIndex(String path) {
  final file = File(path);
  final parent = file.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }
  return LifelineDatabase(file);
}
