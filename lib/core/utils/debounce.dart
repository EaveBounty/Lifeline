/// 简易防抖器。
library;

import 'dart:async';

class Debouncer {
  Debouncer(this.duration);

  final Duration duration;

  Timer? _timer;

  /// 延迟执行；重复调用会重置计时。
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// 取消未执行的调用。
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
