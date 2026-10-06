/// Lifeline 入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'app.dart';
import 'core/constants.dart';
import 'core/logging.dart';
import 'core/utils/file_utils.dart';
import 'data/config/app_config.dart';
import 'data/providers.dart';
import 'data/repositories/root_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging(debug: true);

  final config = await AppConfig.load();

  // A4：启动即校验记忆的同步根；失效则清空并回到首启页，避免在缺失父目录开库。
  final remembered = config.syncRoot;
  if (remembered != null) {
    try {
      final probe = await RootManager(config).probe(remembered);
      if (probe != RootProbe.initialized) {
        appLog.warning('记忆的同步根无效（$probe）：$remembered，已重置');
        await config.setSyncRoot(null);
      } else {
        await ensureDir(p.join(remembered, SyncLayout.dataDir));
      }
    } catch (e) {
      appLog.warning('校验同步根异常，重置: $e');
      await config.setSyncRoot(null);
    }
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const LifelineApp(),
    ),
  );
}
