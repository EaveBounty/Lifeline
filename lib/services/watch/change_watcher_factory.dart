/// 变更监听工厂入口：按平台选择真实实现或 no-op。
library;

export 'change_watcher.dart';
export 'change_watcher_io.dart'
    if (dart.library.js_interop) 'change_watcher_web.dart';
