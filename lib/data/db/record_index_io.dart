/// 原生端索引工厂：返回 drift 支持的 [LifelineDatabase]。
library;

import 'dart:io';

import 'database.dart';
import 'record_index.dart';

/// 打开（或创建）同步根内的 drift 索引库。
RecordIndex openRecordIndex(String path) => LifelineDatabase(File(path));
