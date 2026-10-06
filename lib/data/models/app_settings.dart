/// 同步根内 YAML 设置（无密钥，可安全同步）。
library;

import 'ai_provider.dart';

class AppSettings {
  final int schemaVersion;
  final String language; // zh | en
  final String themeMode; // system | light | dark
  final List<String> defaultExportFormats; // pdf, docx, md
  final String? defaultAiProviderId;
  final List<AiProvider> providers;
  final bool researchEnabled;
  final bool autoCompileEnabled;
  final int watchDebounceMs;
  final Map<String, dynamic> extra;

  const AppSettings({
    this.schemaVersion = 1,
    this.language = 'zh',
    this.themeMode = 'system',
    this.defaultExportFormats = const ['pdf', 'docx', 'md'],
    this.defaultAiProviderId,
    this.providers = const [],
    this.researchEnabled = true,
    this.autoCompileEnabled = true,
    this.watchDebounceMs = 600,
    this.extra = const {},
  });

  AppSettings copyWith({
    int? schemaVersion,
    String? language,
    String? themeMode,
    List<String>? defaultExportFormats,
    String? defaultAiProviderId,
    List<AiProvider>? providers,
    bool? researchEnabled,
    bool? autoCompileEnabled,
    int? watchDebounceMs,
    Map<String, dynamic>? extra,
  }) =>
      AppSettings(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        defaultExportFormats: defaultExportFormats ?? this.defaultExportFormats,
        defaultAiProviderId: defaultAiProviderId ?? this.defaultAiProviderId,
        providers: providers ?? this.providers,
        researchEnabled: researchEnabled ?? this.researchEnabled,
        autoCompileEnabled: autoCompileEnabled ?? this.autoCompileEnabled,
        watchDebounceMs: watchDebounceMs ?? this.watchDebounceMs,
        extra: extra ?? this.extra,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'app': {
          'language': language,
          'theme_mode': themeMode,
        },
        'ai': {
          'default_provider_id': defaultAiProviderId,
          'providers': providers.map((p) => p.toJson()).toList(),
        },
        'export': {
          'default_formats': defaultExportFormats,
        },
        'compile': {
          'auto_enabled': autoCompileEnabled,
          'watch_debounce_ms': watchDebounceMs,
        },
        'research': {'enabled': researchEnabled},
        'extra': extra,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final app = (j['app'] as Map?)?.cast<String, dynamic>() ?? {};
    final ai = (j['ai'] as Map?)?.cast<String, dynamic>() ?? {};
    final export = (j['export'] as Map?)?.cast<String, dynamic>() ?? {};
    final compile = (j['compile'] as Map?)?.cast<String, dynamic>() ?? {};
    final research = (j['research'] as Map?)?.cast<String, dynamic>() ?? {};
    return AppSettings(
      schemaVersion: (j['schema_version'] as num?)?.toInt() ?? 1,
      language: (app['language'] ?? 'zh') as String,
      themeMode: (app['theme_mode'] ?? 'system') as String,
      defaultExportFormats: (export['default_formats'] as List?)?.map((e) => '$e').toList() ??
          const ['pdf', 'docx', 'md'],
      defaultAiProviderId: ai['default_provider_id'] as String?,
      providers: (ai['providers'] as List?)
              ?.map((e) => AiProvider.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      researchEnabled: (research['enabled'] ?? true) as bool,
      autoCompileEnabled: (compile['auto_enabled'] ?? true) as bool,
      watchDebounceMs: (compile['watch_debounce_ms'] as num?)?.toInt() ?? 600,
      extra: (j['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  static AppSettings initial() => const AppSettings();
}
