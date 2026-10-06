/// 应用根：根据同步根状态决定显示「首启页」或「主应用路由」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/onboarding/sync_root_setup_page.dart';
import 'services/watch/auto_compile.dart';

class LifelineApp extends ConsumerWidget {
  const LifelineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(syncRootProvider);
    // 挂载自动编译：根存在时启动文件监听，变更即重编简历。
    if (root.hasRoot) {
      ref.watch(autoCompileProvider);
    }
    final settings = ref.watch(settingsProvider).value;
    final themeMode = switch (settings?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final localizationDelegates = const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    const supportedLocales = [Locale('zh'), Locale('en')];

    if (!root.hasRoot) {
      return MaterialApp(
        title: '${AppInfo.nameEn} · ${AppInfo.nameZh}',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        localizationsDelegates: localizationDelegates,
        supportedLocales: supportedLocales,
        home: const SyncRootSetupPage(),
      );
    }

    return MaterialApp.router(
      title: '${AppInfo.nameEn} · ${AppInfo.nameZh}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: localizationDelegates,
      supportedLocales: supportedLocales,
      routerConfig: appRouter,
    );
  }
}
