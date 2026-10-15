/// 解析默认 AI Provider 的调用配置（含已读出的密钥）。
library;

import '../../data/models/ai_provider.dart';
import '../../data/models/app_settings.dart';
import '../secrets/secret_store.dart';

class AiCallConfig {
  const AiCallConfig({
    required this.providerId,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.extraHeaders = const {},
  });

  final String providerId;
  final String baseUrl;
  final String apiKey;
  final String model;
  final Map<String, String> extraHeaders;

  bool get ready => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;
}

/// 取默认 Provider（缺省回退第一个启用的）；密钥缺失或未配置返回 null。
Future<AiCallConfig?> resolveAiCall({
  required AppSettings settings,
  required SecretStore secrets,
}) async {
  AiProvider? provider;
  final id = settings.defaultAiProviderId;
  if (id != null) {
    for (final p in settings.providers) {
      if (p.id == id && p.enabled) provider = p;
    }
  }
  if (provider == null) {
    for (final p in settings.providers) {
      if (p.enabled) {
        provider = p;
        break;
      }
    }
  }
  if (provider == null) return null;
  final key = (await secrets.read(provider.keyRef)) ?? '';
  if (key.trim().isEmpty) return null;
  return AiCallConfig(
    providerId: provider.id,
    baseUrl: provider.baseUrl,
    apiKey: key,
    model: provider.model,
    extraHeaders: provider.extraHeaders,
  );
}
