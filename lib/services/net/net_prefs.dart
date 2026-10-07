/// 网络代理偏好（设备本地）。手动设置优先于自动探测。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform/net_proxy.dart';

class NetPrefs {
  static const String _k = 'net.proxy';

  static Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_k);

  /// 保存并立即生效（空值=清除，走自动探测）。
  static Future<void> save(String? value) async {
    final sp = await SharedPreferences.getInstance();
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      await sp.remove(_k);
      explicitProxy = null;
    } else {
      await sp.setString(_k, v);
      explicitProxy = v;
    }
  }

  /// 启动时应用已保存的代理。
  static Future<void> apply() async {
    explicitProxy = await load();
  }
}
