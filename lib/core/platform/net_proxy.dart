/// 为 Dio 配置系统/环境代理（仅原生平台；Web 为空实现）。
library;

export 'net_proxy_native.dart' if (dart.library.js_interop) 'net_proxy_web.dart';
