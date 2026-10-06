/// 密钥保险库设置页：加密同步的 API Key 保险库管理。
///
/// 文件 `<syncRoot>/.lifeline/vault.dat` 随同步根同步；跨设备用同一口令解锁。
/// 口令丢失不可恢复——文件为 AEAD 密文，无任何后门。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../services/secrets/vault_providers.dart';

class SecretVaultPage extends ConsumerStatefulWidget {
  const SecretVaultPage({super.key});

  @override
  ConsumerState<SecretVaultPage> createState() => _SecretVaultPageState();
}

class _SecretVaultPageState extends ConsumerState<SecretVaultPage> {
  final _createPass = TextEditingController();
  final _createPass2 = TextEditingController();
  final _unlockPass = TextEditingController();
  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();
  final _newPass2 = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _createPass.dispose();
    _createPass2.dispose();
    _unlockPass.dispose();
    _oldPass.dispose();
    _newPass.dispose();
    _newPass2.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (okMessage.isNotEmpty) _snack(okMessage);
    } catch (e) {
      _snack(vaultErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final p1 = _createPass.text;
    final p2 = _createPass2.text;
    if (p1.length < 8) {
      _snack('口令至少 8 位');
      return;
    }
    if (p1 != p2) {
      _snack('两次输入的口令不一致');
      return;
    }
    await _run(
      () => ref.read(vaultStatusProvider.notifier).createFromLocal(p1),
      '密钥保险库已创建并解锁；现有本地密钥已迁入，旧后端副本已删除。',
    );
    _createPass.clear();
    _createPass2.clear();
  }

  Future<void> _unlock() async {
    final p = _unlockPass.text;
    if (p.isEmpty) {
      _snack('请输入口令');
      return;
    }
    await _run(
      () => ref.read(vaultStatusProvider.notifier).unlock(p),
      '已解锁',
    );
    _unlockPass.clear();
  }

  Future<void> _changePass() async {
    final oldP = _oldPass.text;
    final p1 = _newPass.text;
    final p2 = _newPass2.text;
    if (oldP.isEmpty) {
      _snack('请输入当前口令');
      return;
    }
    if (p1.length < 8) {
      _snack('新口令至少 8 位');
      return;
    }
    if (p1 != p2) {
      _snack('两次输入的新口令不一致');
      return;
    }
    await _run(
      () => ref.read(vaultStatusProvider.notifier).changePassphrase(oldP, p1),
      '口令已修改',
    );
    _oldPass.clear();
    _newPass.clear();
    _newPass2.clear();
  }

  Future<void> _migrate() => _run(
        () => ref.read(vaultStatusProvider.notifier).migrateFromLocal(),
        '已把本地密钥迁入保险库，并删除旧后端副本。',
      );

  Future<void> _lock() => _run(
        () async => ref.read(vaultStatusProvider.notifier).lock(),
        '已锁定',
      );

  Future<void> _forget() async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(vaultStatusProvider.notifier).forgetDevice();
      _snack(
        ok
            ? '已清除本机缓存并锁定'
            : '已锁定，但清除系统密钥库缓存失败：本机下次可能仍会自动解锁，请重试。',
      );
    } catch (e) {
      _snack(vaultErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _strengthLabel(String pass) {
    if (pass.isEmpty) return '';
    var score = 0;
    if (pass.length >= 8) score++;
    if (pass.length >= 12) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(pass) && RegExp(r'[0-9]').hasMatch(pass)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pass)) score++;
    return switch (score) {
      <= 1 => '弱',
      2 => '中',
      3 => '较强',
      _ => '强',
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(vaultStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('密钥保险库（加密同步）')),
      body: statusAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(vaultStatusProvider),
        ),
        data: (status) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _statusCard(status),
                const SizedBox(height: 12),
                if (!status.exists) _createCard(),
                if (status.exists && !status.unlocked) _unlockCard(status),
                if (status.exists && status.unlocked) _manageCard(status),
                const SizedBox(height: 12),
                _note(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard(VaultStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final color = status.exists
        ? (status.unlocked ? scheme.primary : scheme.error)
        : scheme.onSurfaceVariant;
    return SectionCard(
      title: '状态',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.unlocked ? Icons.lock_open : Icons.lock_outline,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                status.labelZh,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _kv('保险库文件', status.exists ? '已创建（随同步根同步）' : '未创建'),
          _kv('本机自动解锁', status.usingDeviceCache ? '已缓存设备密钥' : '未缓存'),
          _kv(
            '旧后端',
            status.usingFallback ? '系统密钥库不可用（本地降级文件）' : '系统密钥库',
          ),
        ],
      ),
    );
  }

  Widget _createCard() => SectionCard(
        title: '启用保险库',
        icon: Icons.enhanced_encryption_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置一个口令。API Key 将用「口令 + PBKDF2 + AES-256-GCM」加密后'
              '写入同步根下的 vault.dat，跨设备同步后可用同一口令解锁。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _createPass,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '口令',
                helperText: _strengthLabel(_createPass.text).isEmpty
                    ? '至少 8 位；建议混合大小写、数字与符号'
                    : '强度：${_strengthLabel(_createPass.text)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _createPass2,
              obscureText: true,
              decoration: const InputDecoration(labelText: '确认口令'),
            ),
            const SizedBox(height: 8),
            const Text(
              '注意：口令丢失将无法恢复任何密钥（无后门、无找回）。',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.lock),
              label: const Text('创建并解锁'),
            ),
          ],
        ),
      );

  Widget _unlockCard(VaultStatus status) => SectionCard(
        title: '解锁保险库',
        icon: Icons.lock_open_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('保险库已存在但当前已锁定。输入口令以读写其中的 API Key。'),
            const SizedBox(height: 12),
            TextField(
              controller: _unlockPass,
              obscureText: true,
              onSubmitted: (_) {
                if (!_busy) _unlock();
              },
              decoration: const InputDecoration(labelText: '口令'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('解锁'),
                ),
                if (status.usingDeviceCache)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _forget,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清除本机缓存'),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _manageCard(VaultStatus status) => Column(
        children: [
          SectionCard(
            title: '操作',
            icon: Icons.tune,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _lock,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('锁定'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _migrate,
                  icon: const Icon(Icons.move_down),
                  label: const Text('迁移本地密钥'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _forget,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清除本机缓存'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '修改口令',
            icon: Icons.password,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _oldPass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '当前口令'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPass,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '新口令',
                    helperText: _strengthLabel(_newPass.text).isEmpty
                        ? '至少 8 位'
                        : '强度：${_strengthLabel(_newPass.text)}',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPass2,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '确认新口令'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _changePass,
                  icon: const Icon(Icons.save),
                  label: const Text('修改口令'),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _note() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '安全说明：真实机密性来自「口令 + PBKDF2(210000) + AES-256-GCM」；'
            '文件外层的 LFV1 换行 base64 只是混淆，用于避免被肉眼直接识别，'
            '并非安全措施。多设备请使用同一口令解锁同一份 vault.dat。'
            '锁定后本页不再读取系统密钥库/降级文件中的旧密钥，避免绕过锁定；'
            '迁移（创建或「迁移本地密钥」）默认删除旧后端源键。'
            '修改口令为最小重包：DEK 与数据密文不变，其它设备需改用新口令解锁。',
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

  Widget _kv(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
