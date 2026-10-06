/// dart:io 平台抽象入口。
///
/// 原生（io）导出真实 `dart:io`；Web 导出内存文件系统兼容层。
/// 条件基于 `dart.library.js_interop`（web 为真）。
library;

export 'io_native.dart' if (dart.library.js_interop) 'io_web.dart';
