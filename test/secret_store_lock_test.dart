import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/services/secrets/crypto_vault.dart';
import 'package:lifeline/services/secrets/secret_store.dart';

/// 内存版 FlutterSecureStorage，用于门面语义回归（不触平台通道）。
class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage([Map<String, String>? initial]) : _data = {...?initial};

  final Map<String, String> _data;
  bool failDelete = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) throw Exception('delete failed');
    _data.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map<String, String>.from(_data);
}

void main() {
  const pass = 'strong-passphrase';
  late Directory dir;
  late _FakeStorage storage;
  late SecretStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifeline_store_test_');
    storage = _FakeStorage({'openai': 'sk-legacy', 'deepseek': 'sk-legacy-2'});
    store = SecretStore(rootPath: dir.path, storage: storage);
  });

  tearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  test('H1：锁定态 read 不回退旧后端，readAll 不泄漏', () async {
    await store.createVault(pass, {'openai': 'sk-vault'});
    expect(await store.read('openai'), 'sk-vault');
    store.lockVault();
    expect(await store.read('openai'), isNull);
    expect(await store.readAll(), isEmpty);
  });

  test('H1：锁定态 write/delete 抛受控 VaultException', () async {
    await store.createVault(pass, {'openai': 'sk-vault'});
    store.lockVault();
    await expectLater(
      store.write('openai', 'x'),
      throwsA(isA<VaultException>()),
    );
    await expectLater(
      store.delete('openai'),
      throwsA(isA<VaultException>()),
    );
  });

  test('H1b：migrateFromLocal 默认删除旧后端源键', () async {
    await store.createVault(pass, <String, String>{});
    await store.migrateFromLocal();
    expect(await store.read('openai'), 'sk-legacy');
    expect(await storage.read(key: 'openai'), isNull);
    expect(await storage.read(key: 'deepseek'), isNull);
  });

  test('H1b：createVaultFromLocal 迁移后删除旧后端源键', () async {
    await store.createVaultFromLocal(pass);
    expect(store.vaultExists, isTrue);
    expect(await store.read('openai'), 'sk-legacy');
    expect(await storage.read(key: 'openai'), isNull);
  });

  test('M4：forgetDevice 删除失败返回 false，成功返回 true', () async {
    await store.createVault(pass, {'openai': 'sk-vault'});
    expect(await store.hasDeviceCache(), isTrue);

    storage.failDelete = true;
    expect(await store.forgetDevice(), isFalse);
    expect(await store.hasDeviceCache(), isTrue);

    storage.failDelete = false;
    expect(await store.forgetDevice(), isTrue);
    expect(await store.hasDeviceCache(), isFalse);
  });
}
