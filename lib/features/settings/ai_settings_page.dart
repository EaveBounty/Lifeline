/// AI / 模型厂商设置：Provider 增删改、密钥写入、连通性测试。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/common.dart';
import '../../data/models/ai_provider.dart';
import '../../data/providers.dart';
import '../../services/secrets/secret_store.dart';

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  String? _testing;
  bool _probedSecrets = false;

  @override
  void initState() {
    super.initState();
    _probeSecrets();
  }

  /// 触发一次读以判定密钥库是否降级（`usingFallback` 为副作用状态）。
  Future<void> _probeSecrets() async {
    final secrets = ref.read(secretStoreProvider);
    await secrets.read('__lifeline_secret_probe__');
    if (mounted) {
      setState(() => _probedSecrets = true);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openEditor(AiProvider? initial) async {
    final secrets = ref.read(secretStoreProvider);
    final draft = await showDialog<_ProviderDraft>(
      context: context,
      builder: (_) => _ProviderEditDialog(initial: initial, secrets: secrets),
    );
    if (draft == null) return;
    // 密钥只写系统密钥库，绝不落到 YAML / 日志。
    if (draft.clearKey) {
      await secrets.delete(draft.provider.keyRef);
    }
    final apiKey = draft.apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      await secrets.write(draft.provider.keyRef, apiKey);
    }
    await ref.read(settingsProvider.notifier).upsertProvider(draft.provider);
    _snack('已保存 ${draft.provider.name}');
  }

  Future<void> _addFromPresets() async {
    final existing =
        ref.read(settingsProvider).value?.providers ?? const <AiProvider>[];
    final chosen = await showDialog<AiProvider>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('从预设添加'),
        children: AiPresets.presets.map((preset) {
          final exists = existing.any((e) => e.id == preset.id);
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, preset),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preset.name),
                      Text(
                        preset.model,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (exists)
                  Text('已存在',
                      style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (chosen == null) return;
    await ref.read(settingsProvider.notifier).upsertProvider(chosen);
    _snack('已添加 ${chosen.name}');
  }

  Future<void> _delete(AiProvider provider) async {
    final ok = await _confirm(
      '删除 ${provider.name}？',
      '将从配置中移除该 Provider。已保存的密钥不会被自动删除。',
    );
    if (!ok) return;
    await ref.read(settingsProvider.notifier).removeProvider(provider.id);
    _snack('已删除 ${provider.name}');
  }

  Future<void> _setDefault(AiProvider provider) async {
    await ref.read(settingsProvider.notifier).setDefaultProvider(provider.id);
    _snack('已将 ${provider.name} 设为默认');
  }

  Future<void> _toggleEnabled(AiProvider provider, bool value) async {
    await ref
        .read(settingsProvider.notifier)
        .upsertProvider(provider.copyWith(enabled: value));
  }

  /// 直接用 dio 发一条极简 chat 请求，不使用其它 AI 服务层。
  Future<void> _test(AiProvider provider) async {
    final secrets = ref.read(secretStoreProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testing = provider.id);
    try {
      final key = await secrets.read(provider.keyRef);
      final base = provider.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        ...provider.extraHeaders,
      };
      if (key != null && key.isNotEmpty) {
        headers['Authorization'] = 'Bearer $key';
      }
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      final res = await dio.post(
        '$base/chat/completions',
        data: {
          'model': provider.model,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
        },
        options: Options(headers: headers, validateStatus: (_) => true),
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        messenger.showSnackBar(
          SnackBar(content: Text('${provider.name} 连接成功（HTTP $code）')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${provider.name} 连接失败：HTTP $code ${_brief(res.data)}'),
          ),
        );
      }
    } on DioException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${provider.name} 连接失败：${e.type.name} ${e.message ?? ''}'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${provider.name} 连接失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _testing = null);
    }
  }

  static String _brief(dynamic data) {
    final text = data?.toString() ?? '';
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('API / 模型厂商')),
      body: settingsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(settingsProvider),
        ),
        data: (settings) {
          final secrets = ref.read(secretStoreProvider);
          final usingFallback = _probedSecrets && secrets.usingFallback;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (usingFallback) ...[
                    _fallbackWarning(context),
                    const SizedBox(height: 4),
                  ],
                  SectionCard(
                    title: '模型厂商',
                    icon: Icons.hub_outlined,
                    child: settings.providers.isEmpty
                        ? _empty(context)
                        : Column(
                            children: [
                              for (final p in settings.providers)
                                _ProviderCard(
                                  provider: p,
                                  isDefault:
                                      settings.defaultAiProviderId == p.id,
                                  testing: _testing == p.id,
                                  onEdit: () => _openEditor(p),
                                  onDelete: () => _delete(p),
                                  onSetDefault: () => _setDefault(p),
                                  onToggle: (v) => _toggleEnabled(p, v),
                                  onTest: () => _test(p),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openEditor(null),
                        icon: const Icon(Icons.add),
                        label: const Text('新增 Provider'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addFromPresets,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('从预设添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _secretNote(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '还没有配置任何 Provider。可新增自定义项，或从常见厂商预设一键添加。',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );

  Widget _fallbackWarning(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '系统密钥库不可用，密钥已降级保存到本地权限文件。'
                '该文件不同步、但保护强度较低；建议安装 libsecret / gnome-keyring 后重新保存密钥。',
                style: TextStyle(color: scheme.onErrorContainer, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secretNote(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'API Key 只写入系统密钥库（失败时降级本地权限文件），不会写入同步 YAML，也不会出现在日志中。'
            'Provider 的 key_ref 只是指向密钥库的键名。',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.45,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.isDefault,
    required this.testing,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onToggle,
    required this.onTest,
  });

  final AiProvider provider;
  final bool isDefault;
  final bool testing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: provider.enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            Text(
              provider.baseUrl,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text('模型：${provider.model}　key_ref：${provider.keyRef}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: provider.capabilities
                  .map((c) => Chip(
                        label: Text(_capLabel(c),
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (testing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: onTest,
                    icon: const Icon(Icons.wifi_tethering, size: 18),
                    label: const Text('测试连接'),
                  ),
                TextButton.icon(
                  onPressed: isDefault ? null : onSetDefault,
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: const Text('设为默认'),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
                  label: Text('删除', style: TextStyle(color: scheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _capLabel(String cap) {
    switch (cap) {
      case AiCapability.text:
        return '文本';
      case AiCapability.vision:
        return '视觉';
      case AiCapability.json:
        return 'JSON';
      default:
        return cap;
    }
  }
}

/// 对话框返回值：Provider 本体 + 待写入/清除的密钥。
class _ProviderDraft {
  const _ProviderDraft(this.provider, {this.apiKey, this.clearKey = false});

  final AiProvider provider;
  final String? apiKey;
  final bool clearKey;
}

class _ProviderEditDialog extends StatefulWidget {
  const _ProviderEditDialog({required this.initial, required this.secrets});

  final AiProvider? initial;
  final SecretStore secrets;

  @override
  State<_ProviderEditDialog> createState() => _ProviderEditDialogState();
}

class _ProviderEditDialogState extends State<_ProviderEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _keyRef;
  final _apiKey = TextEditingController();
  late Set<String> _caps;
  bool _obscure = true;
  bool _keySet = false;
  bool _keyKnown = false;
  bool _clearKey = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _baseUrl = TextEditingController(text: p?.baseUrl ?? '');
    _model = TextEditingController(text: p?.model ?? '');
    _keyRef = TextEditingController(text: p?.keyRef ?? '');
    _caps = {...?p?.capabilities};
    if (_caps.isEmpty) _caps = {AiCapability.text};
    _keyRef.addListener(_refreshKeyStatus);
    _refreshKeyStatus();
  }

  @override
  void dispose() {
    _keyRef.removeListener(_refreshKeyStatus);
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _keyRef.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _refreshKeyStatus() async {
    final ref = _keyRef.text.trim();
    if (ref.isEmpty) {
      if (mounted) {
        setState(() {
          _keySet = false;
          _keyKnown = true;
        });
      }
      return;
    }
    final value = await widget.secrets.read(ref);
    if (!mounted) return;
    setState(() {
      _keySet = value != null && value.isNotEmpty;
      _keyKnown = true;
    });
  }

  void _clearExistingKey() {
    setState(() {
      _clearKey = true;
      _keySet = false;
    });
    _apiKey.clear();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final apiKey = _apiKey.text.trim();
    final provider = AiProvider(
      id: widget.initial?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      keyRef: _keyRef.text.trim(),
      capabilities: _caps.toList(),
      enabled: widget.initial?.enabled ?? true,
      extraHeaders: widget.initial?.extraHeaders ?? const {},
    );
    Navigator.pop(
      context,
      _ProviderDraft(
        provider,
        apiKey: apiKey.isEmpty ? null : apiKey,
        clearKey: _clearKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(widget.initial == null ? '新增 Provider' : '编辑 Provider'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '名称'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? '请输入名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return '请输入 Base URL';
                    final uri = Uri.tryParse(t);
                    if (uri == null || !uri.hasScheme) return 'URL 格式不正确';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: '模型'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? '请输入模型名' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _keyRef,
                  decoration: const InputDecoration(
                    labelText: 'key_ref（密钥库键名）',
                    helperText: '仅作为密钥索引，不含密钥本身',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? '请输入 key_ref' : null,
                ),
                const SizedBox(height: 14),
                Text('能力', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _capChip(AiCapability.text, '文本'),
                    _capChip(AiCapability.vision, '视觉'),
                    _capChip(AiCapability.json, 'JSON'),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _apiKey,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    helperText: '只写入系统密钥库，不写入 YAML / 日志。留空表示不修改。',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? '显示' : '隐藏',
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _keySet ? Icons.lock : Icons.lock_open,
                      size: 16,
                      color: _keySet ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        !_keyKnown
                            ? '正在检测密钥…'
                            : _keySet
                                ? '当前密钥：已设置'
                                : '当前密钥：未设置',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (_keySet && !_clearKey)
                      TextButton(
                        onPressed: _clearExistingKey,
                        child: const Text('清除密钥'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  Widget _capChip(String cap, String label) {
    final selected = _caps.contains(cap);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() {
        if (v) {
          _caps.add(cap);
        } else {
          _caps.remove(cap);
        }
      }),
    );
  }
}
