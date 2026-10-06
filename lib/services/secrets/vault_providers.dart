/// 密钥保险库 Riverpod 控制器：状态查询与操作（创建/解锁/锁定/改口令/迁移/清缓存）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'crypto_vault.dart';
import 'secret_store.dart';

/// 保险库对外状态快照。
class VaultStatus {
  const VaultStatus({
    required this.exists,
    required this.unlocked,
    required this.usingFallback,
    required this.usingDeviceCache,
  });

  /// 保险库文件是否已创建（启用）。
  final bool exists;

  /// 是否已解锁。
  final bool unlocked;

  /// 旧后端是否降级为本地权限文件。
  final bool usingFallback;

  /// 设备密钥库是否缓存了 DEK（可自动解锁）。
  final bool usingDeviceCache;

  static const VaultStatus none = VaultStatus(
    exists: false,
    unlocked: false,
    usingFallback: false,
    usingDeviceCache: false,
  );

  /// 人类可读状态。
  String get labelZh {
    if (!exists) return '未启用';
    return unlocked ? '已解锁' : '已锁定';
  }
}

final vaultStatusProvider =
    AsyncNotifierProvider<VaultStatusController, VaultStatus>(
  VaultStatusController.new,
);

class VaultStatusController extends AsyncNotifier<VaultStatus> {
  @override
  Future<VaultStatus> build() async {
    final store = ref.watch(secretStoreProvider);
    return _probe(store);
  }

  SecretStore get _store => ref.read(secretStoreProvider);

  Future<VaultStatus> _probe(SecretStore store) async {
    final cache = await store.hasDeviceCache();
    return VaultStatus(
      exists: store.vaultExists,
      unlocked: store.vaultUnlocked,
      usingFallback: store.usingFallback,
      usingDeviceCache: cache,
    );
  }

  Future<void> refresh() async {
    state = AsyncData(await _probe(_store));
  }

  /// 创建保险库并自动解锁；[secrets] 一般为迁移自旧后端的现有键值。
  Future<void> create(String passphrase, Map<String, String> secrets) async {
    await _store.createVault(passphrase, secrets);
    await refresh();
  }

  Future<void> unlock(String passphrase) async {
    await _store.unlockVault(passphrase);
    await refresh();
  }

  /// 启动自动解锁（设备缓存）；返回是否成功。
  Future<bool> tryAutoUnlock() async {
    final ok = await _store.tryAutoUnlock();
    await refresh();
    return ok;
  }

  Future<void> lock() async {
    _store.lockVault();
    await refresh();
  }

  Future<void> changePassphrase(String oldPass, String newPass) async {
    await _store.changeVaultPassphrase(oldPass, newPass);
    await refresh();
  }

  /// 迁移旧后端（keychain/降级文件）中的全部密钥到保险库。
  ///
  /// 默认迁移后删除源键，避免旧后端残留。
  Future<void> migrateFromLocal({bool deleteAfter = true}) async {
    await _store.migrateFromLocal(deleteAfter: deleteAfter);
    await refresh();
  }

  /// 清除本机缓存并锁定；返回是否确实删除了系统密钥库缓存。
  Future<bool> forgetDevice() async {
    final ok = await _store.forgetDevice();
    await refresh();
    return ok;
  }

  /// 尝试以旧后端的现有密钥初始化新保险库（迁移后删除旧后端源键）。
  Future<void> createFromLocal(String passphrase) async {
    await _store.createVaultFromLocal(passphrase);
    await refresh();
  }
}

/// 便于 UI 捕获受控异常文案。
String vaultErrorText(Object error) =>
    error is VaultException ? error.message : '$error';
