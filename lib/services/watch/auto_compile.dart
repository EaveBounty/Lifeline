/// 自动编译：监听同步根 `data/` 变更并刷新相关 provider。
///
/// 由 app 层挂载 [autoCompileProvider] 即可；根不存在或关闭自动编译时为空。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'change_watcher.dart';

/// B4：autoDispose 保证 UI 不再监听（根卸载/detach）时旧 watcher 与 Timer 被释放。
final autoCompileProvider = Provider.autoDispose<ChangeWatcher?>((ref) {
  final path = ref.watch(syncRootProvider.select((s) => s.path));
  final enabled = ref.watch(
    settingsProvider.select((s) => s.value?.autoCompileEnabled ?? false),
  );
  if (path == null || !enabled) return null;

  final debounceMs = ref.watch(
    settingsProvider.select((s) => s.value?.watchDebounceMs ?? 600),
  );

  final watcher = ChangeWatcher(
    rootPath: path,
    debounce: Duration(milliseconds: debounceMs),
    onChanged: () {
      ref.invalidate(settingsProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(recordsProvider);
      ref.invalidate(attachmentsProvider);
      ref.invalidate(resumeLibraryProvider);
    },
  );
  watcher.start();
  ref.onDispose(watcher.dispose);
  return watcher;
});
