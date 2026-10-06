/// Web 端变更监听：no-op（内存卷由本进程独占，无外部变更）。
library;

import 'change_watcher.dart';

/// 创建 no-op 变更监听。
ChangeWatcher createChangeWatcher({
  required String rootPath,
  required void Function() onChanged,
  Duration debounce = const Duration(milliseconds: 500),
  Duration pollInterval = const Duration(seconds: 15),
}) =>
    const NoopChangeWatcher();

class NoopChangeWatcher implements ChangeWatcher {
  const NoopChangeWatcher();

  @override
  void start() {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
