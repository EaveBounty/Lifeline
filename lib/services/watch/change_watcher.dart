/// 同步根变更监听的平台无关接口。
///
/// 原生端递归监听 + 轮询兜底；Web 端为 no-op（内存卷无外部变更）。
library;

abstract interface class ChangeWatcher {
  /// 启动监听；根不存在等情况下静默无效。
  void start();

  /// 停止监听并释放订阅/定时器。
  Future<void> stop();

  /// 释放（等价于 stop）。
  Future<void> dispose();
}
