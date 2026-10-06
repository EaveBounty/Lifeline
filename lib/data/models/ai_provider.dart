/// AI 模型厂商/Provider 配置。
///
/// 密钥不在此（存系统密钥库或本地降级文件 secrets.local.json），此处仅存 `keyRef` 指针。
library;

class AiCapability {
  static const text = 'text';
  static const vision = 'vision';
  static const json = 'json';
}

class AiProvider {
  final String id;
  final String name;

  /// OpenAI 兼容 base url，如 https://api.openai.com/v1
  final String baseUrl;
  final String model;

  /// 密钥引用键（对应密钥库中的 key）。
  final String keyRef;
  final List<String> capabilities;
  final bool enabled;

  /// 额外请求头（一般留空）。
  final Map<String, String> extraHeaders;

  const AiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.keyRef,
    this.capabilities = const [AiCapability.text],
    this.enabled = true,
    this.extraHeaders = const {},
  });

  bool get supportsVision => capabilities.contains(AiCapability.vision);

  /// B7：剥离可能泄露密钥的请求头，避免随 YAML 同步外泄。
  ///
  /// 仅保留非敏感自定义头；`Authorization`、`api-key`、`token`、`cookie`
  /// 等一律移除。
  static const List<String> _sensitiveHeaderKeys = [
    'authorization',
    'proxy-authorization',
    'api-key',
    'apikey',
    'x-api-key',
    'x-auth-token',
    'x-goog-api-key',
    'token',
    'access-token',
    'secret',
    'cookie',
  ];

  bool _isSensitiveHeader(String key) {
    final k = key.toLowerCase();
    return _sensitiveHeaderKeys.any((needle) => k.contains(needle));
  }

  AiProvider sanitized() {
    if (extraHeaders.isEmpty) return this;
    final clean = <String, String>{};
    extraHeaders.forEach((k, v) {
      if (!_isSensitiveHeader(k)) clean[k] = v;
    });
    return copyWith(extraHeaders: clean);
  }

  AiProvider copyWith({
    String? name,
    String? baseUrl,
    String? model,
    String? keyRef,
    List<String>? capabilities,
    bool? enabled,
    Map<String, String>? extraHeaders,
  }) =>
      AiProvider(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        keyRef: keyRef ?? this.keyRef,
        capabilities: capabilities ?? this.capabilities,
        enabled: enabled ?? this.enabled,
        extraHeaders: extraHeaders ?? this.extraHeaders,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_url': baseUrl,
        'model': model,
        'key_ref': keyRef,
        'capabilities': capabilities,
        'enabled': enabled,
        'extra_headers': extraHeaders,
      };

  factory AiProvider.fromJson(Map<String, dynamic> j) => AiProvider(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        baseUrl: (j['base_url'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        keyRef: (j['key_ref'] ?? '') as String,
        capabilities: (j['capabilities'] as List?)?.map((e) => '$e').toList() ??
            const [AiCapability.text],
        enabled: (j['enabled'] ?? true) as bool,
        extraHeaders:
            (j['extra_headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
      );
}

/// 常见厂商预设（供设置页一键填充）。
class AiPresets {
  static const List<AiProvider> presets = [
    AiProvider(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      keyRef: 'openai',
      capabilities: ['text', 'vision', 'json'],
    ),
    AiProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      model: 'deepseek-chat',
      keyRef: 'deepseek',
      capabilities: ['text', 'json'],
    ),
    AiProvider(
      id: 'moonshot',
      name: 'Moonshot (Kimi)',
      baseUrl: 'https://api.moonshot.cn/v1',
      model: 'moonshot-v1-8k',
      keyRef: 'moonshot',
      capabilities: ['text', 'vision', 'json'],
    ),
    AiProvider(
      id: 'zhipu',
      name: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-4-flash',
      keyRef: 'zhipu',
      capabilities: ['text', 'vision', 'json'],
    ),
    AiProvider(
      id: 'dashscope',
      name: '阿里通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen-plus',
      keyRef: 'dashscope',
      capabilities: ['text', 'vision', 'json'],
    ),
  ];
}
