/// Lifeline 入口。
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'app.dart';
import 'core/constants.dart';
import 'core/logging.dart';
import 'core/utils/file_utils.dart';
import 'data/config/app_config.dart';
import 'data/providers.dart';
import 'data/repositories/root_manager.dart';
import 'dev/demo_seed.dart';

/// 持有语义句柄，避免被 GC 回收导致 Web 语义树关闭（浏览器测试/无障碍依赖）。
final List<SemanticsHandle> _semanticsHandles = <SemanticsHandle>[];

bool get _semanticsEnabled => _semanticsHandles.isNotEmpty;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web 端强制开启语义树，使 Flutter 输出 flt-semantics DOM（测试/无障碍）。
  if (kIsWeb) {
    _semanticsHandles.add(SemanticsBinding.instance.ensureSemantics());
  }
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

  final container = ProviderContainer(
    overrides: [appConfigProvider.overrideWithValue(config)],
  );

  // Web 演示：仅在 `?demo=1` 时挂载内存根并写入种子数据，不影响正常路径。
  if (kIsWeb && Uri.base.queryParameters['demo'] == '1') {
    try {
      await container
          .read(syncRootProvider.notifier)
          .initializeAndAttach('/lifeline-demo');
      await seedDemo(container);
      container.invalidate(settingsProvider);
      container.invalidate(profileProvider);
      container.invalidate(recordsProvider);
      container.invalidate(attachmentsProvider);
      container.invalidate(resumeLibraryProvider);
      appLog.info('web demo 种子已写入（语义树启用=$_semanticsEnabled）');
    } catch (e, st) {
      appLog.warning('web demo 初始化失败: $e', e, st);
    }
  }

  // 密钥保险库自动解锁：仅当设备密钥库缓存了 DEK 时快速解密，不弹口令。
  // 未挂载同步根或未创建保险库时为空操作。
  try {
    await container.read(secretStoreProvider).tryAutoUnlock();
  } catch (e) {
    appLog.warning('密钥保险库自动解锁失败: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LifelineApp(),
    ),
  );
}