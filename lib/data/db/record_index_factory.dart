/// 索引工厂入口：按平台选择 drift 或内存实现。
library;

export 'record_index.dart';
export 'record_index_io.dart'
    if (dart.library.js_interop) 'record_index_web.dart';
