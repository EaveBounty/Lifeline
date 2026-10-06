/// 原生端变更监听：watcher 递归监听 + 定时轮询 mtime 兜底。
///
/// 回调只做 invalidate；自身写入靠防抖与「回调非写操作」避免死循环。
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../../core/constants.dart';
import '../../core/utils/debounce.dart';
import 'change_watcher.dart';

/// 创建原生变更监听。
ChangeWatcher createChangeWatcher({
  required String rootPath,
  required void Function() onChanged,
  Duration debounce = const Duration(milliseconds: 500),
  Duration pollInterval = const Duration(seconds: 15),
}) =>
    IoChangeWatcher(
      rootPath: rootPath,
      onChanged: onChanged,
      debounce: debounce,
      pollInterval: pollInterval,
    );

class IoChangeWatcher implements ChangeWatcher {
  IoChangeWatcher({
    required this.rootPath,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 500),
    this.pollInterval = const Duration(seconds: 15),
  });

  final String rootPath;
  final void Function() onChanged;
  final Duration debounce;
  final Duration pollInterval;

  late final Debouncer _debouncer = Debouncer(debounce);
  DirectoryWatcher? _watcher;
  StreamSubscription<WatchEvent>? _subscription;
  Timer? _pollTimer;
  DateTime? _lastMtime;
  bool _running = false;

  String get _dataPath => p.join(rootPath, SyncLayout.dataDir);

  @override
  void start() {
    if (_running) return;
    final dir = Directory(_dataPath);
    if (!dir.existsSync()) return;
    _running = true;
    _lastMtime = _scanMtime();
    try {
      _watcher = DirectoryWatcher(_dataPath);
      _subscription = _watcher!.events.listen(
        (_) => _debouncer.run(onChanged),
        onError: (_) {},
      );
    } catch (_) {
      _watcher = null;
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => _poll());
  }

  void _poll() {
    final current = _scanMtime();
    if (current == null) return;
    final last = _lastMtime;
    if (last == null) {
      _lastMtime = current;
      return;
    }
    if (current.isAfter(last)) {
      _lastMtime = current;
      _debouncer.run(onChanged);
    }
  }

  DateTime? _scanMtime() {
    final dir = Directory(_dataPath);
    if (!dir.existsSync()) return null;
    DateTime? max;
    try {
      for (final entity
          in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final modified = entity.statSync().modified;
        if (max == null || modified.isAfter(max)) max = modified;
      }
    } catch (_) {
      // 忽略轮询期间的局部读取失败。
    }
    return max;
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _subscription?.cancel();
    _subscription = null;
    _watcher = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _debouncer.dispose();
  }

  @override
  Future<void> dispose() => stop();
}
