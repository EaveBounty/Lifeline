/// 原生平台：让 Dio 遵循代理（手动 > Windows 系统代理 > 环境变量）。
///
/// Dart 的 HttpClient 默认**不使用**系统代理；Windows 上 Clash/v2ray 等常以「系统代理」
/// 模式运行，此时 Dart 直连会被 VPN 路由规则拦截 → 表现为 unknown/连接失败。
/// 这里显式解析代理，尽量自动生效。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 用户手动代理（如 `http://127.0.0.1:7890`）；空则走自动。
String? explicitProxy;

void configureProxy(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      try {
        client.findProxy = (uri) {
          final p = explicitProxy?.trim();
          if (p != null && p.isNotEmpty) return p;
          final win = _windowsSystemProxy();
          if (win != null) return win;
          return HttpClient.findProxyFromEnvironment(
            uri,
            environment: Platform.environment,
          );
        };
      } catch (_) {
        // 代理解析失败时保持直连。
      }
      return client;
    },
  );
}

/// 环境变量代理（供 UI 提示）。
String? detectEnvProxy() {
  final env = Platform.environment;
  for (final k in const [
    'HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy',
  ]) {
    final v = env[k];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// 读取 Windows 系统代理（WinINET），返回 Dio 的 findProxy 格式。
String? _windowsSystemProxy() {
  if (!Platform.isWindows) return null;
  try {
    const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
    final enable = Process.runSync(
      'reg', ['query', key, '/v', 'ProxyEnable'],
    );
    if (!RegExp(r'ProxyEnable\s+REG_DWORD\s+0x1').hasMatch('${enable.stdout}')) {
      return null;
    }
    final server = Process.runSync('reg', ['query', key, '/v', 'ProxyServer']);
    final m = RegExp(r'ProxyServer\s+REG_SZ\s+(.+)').firstMatch('${server.stdout}');
    if (m == null) return null;
    var v = m.group(1)!.trim();
    if (v.contains('=')) {
      // 形如 http=1.2.3.4:8080;https=1.2.3.4:8080
      final parts = v.split(';').map((e) => e.trim()).toList();
      final pick = parts.firstWhere(
        (e) => e.toLowerCase().startsWith('https='),
        orElse: () => parts.isNotEmpty ? parts.first : '',
      );
      v = pick.contains('=') ? pick.split('=').last.trim() : v;
    }
    if (v.isEmpty) return null;
    if (!v.contains('://')) v = 'http://$v';
    return v;
  } catch (_) {
    return null;
  }
}
