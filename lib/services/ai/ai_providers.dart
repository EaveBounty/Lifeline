/// AI 服务 Provider：随设置变化重建。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/providers.dart';
import 'ai_service.dart';
import 'llm_client.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final settings = ref.watch(settingsProvider).value ?? AppSettings.initial();
  return AiService(
    client: LlmClient(),
    secrets: ref.watch(secretStoreProvider),
    settings: settings,
  );
});
