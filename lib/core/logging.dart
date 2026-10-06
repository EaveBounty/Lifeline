/// 统一日志（logging 包封装）。
library;

import 'package:logging/logging.dart';

final Logger appLog = Logger('lifeline');

/// 初始化日志级别；debug 模式输出全部，release 仅 info 以上。
void setupLogging({bool debug = true}) {
  Logger.root.level = debug ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((r) {
    // ignore: avoid_print
    print('[${r.level.name}] ${r.loggerName}: ${r.message}'
        '${r.error != null ? ' | ${r.error}' : ''}');
  });
}
