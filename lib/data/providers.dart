/// Riverpod 3 provider 层（冻结给 UI 的 API）。
///
/// 无同步根时所有 Async provider 返回空默认值，不抛错。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/result.dart';
import '../services/compile/resume_compiler.dart';
import '../services/secrets/secret_store.dart';
import 'config/app_config.dart';
import 'db/database.dart';
import 'models/ai_provider.dart';
import 'models/app_settings.dart';
import 'models/attachment.dart';
import 'models/export_request.dart';
import 'models/profile.dart';
import 'models/profile_record.dart';
import 'models/resume_doc.dart';
import 'repositories/attachment_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/records_repository.dart';
import 'repositories/resume_repository.dart';
import 'repositories/root_manager.dart';
import 'repositories/settings_repository.dart';

/// 必须由 main 覆盖注入。
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('appConfigProvider must be overridden in main'),
);

final rootManagerProvider = Provider<RootManager>(
  (ref) => RootManager(ref.watch(appConfigProvider)),
);

/// 同步根状态。
class SyncRootState {
  const SyncRootState({
    this.path,
    this.initialized = false,
    this.loading = false,
  });

  final String? path;
  final bool initialized;
  final bool loading;

  bool get hasRoot => path != null && path!.isNotEmpty;

  SyncRootState copyWith({
    String? path,
    bool? initialized,
    bool? loading,
    bool clearPath = false,
  }) =>
      SyncRootState(
        path: clearPath ? null : (path ?? this.path),
        initialized: initialized ?? this.initialized,
        loading: loading ?? this.loading,
      );

  static const SyncRootState empty = SyncRootState();
}

final syncRootProvider =
    NotifierProvider<SyncRootController, SyncRootState>(
  SyncRootController.new,
);

class SyncRootController extends Notifier<SyncRootState> {
  @override
  SyncRootState build() {
    final rm = ref.watch(rootManagerProvider);
    return SyncRootState(path: rm.rootPath, initialized: rm.isInitialized);
  }

  RootManager get _rm => ref.read(rootManagerProvider);

  Future<RootProbe> probe(String path) => _rm.probe(path);

  Future<Result<void>> attach(String path) async {
    state = state.copyWith(loading: true);
    final result = await _rm.attach(path);
    _sync(result.isOk);
    return result;
  }

  Future<Result<void>> initializeAndAttach(String path) async {
    state = state.copyWith(loading: true);
    final init = await _rm.initialize(path);
    if (init.isErr) {
      state = state.copyWith(loading: false);
      return init;
    }
    final attached = await _rm.attach(path);
    _sync(attached.isOk);
    return attached;
  }

  Future<void> detach() async {
    await _rm.detach();
    state = SyncRootState.empty;
    _invalidateData();
  }

  void _sync(bool ok) {
    state = SyncRootState(path: _rm.rootPath, initialized: _rm.isInitialized);
    if (ok) _invalidateData();
  }

  void _invalidateData() {
    ref.invalidate(settingsProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(recordsProvider);
    ref.invalidate(attachmentsProvider);
    ref.invalidate(resumeLibraryProvider);
  }
}

/// 索引数据库；无根时为 null。
final databaseProvider = Provider<LifelineDatabase?>((ref) {
  final path = ref.watch(syncRootProvider.select((s) => s.path));
  if (path == null) return null;
  final file = File(p.join(path, SyncLayout.dataDir, SyncLayout.indexFile));
  final db = LifelineDatabase(file);
  ref.onDispose(db.close);
  return db;
});

// --- Settings ---

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final path = ref.watch(syncRootProvider.select((s) => s.path));
    if (path == null) return AppSettings.initial();
    return SettingsRepository(path).load();
  }

  String? get _path => ref.read(syncRootProvider.select((s) => s.path));

  Future<void> save(AppSettings settings) async {
    final path = _path;
    if (path != null) await SettingsRepository(path).save(settings);
    state = AsyncData(settings);
  }

  Future<void> upsertProvider(AiProvider provider) async {
    final current = state.value ?? AppSettings.initial();
    // B7：保存前剥离额外请求头中的密钥类字段，防止泄入可同步 YAML。
    final safe = provider.sanitized();
    final list = [...current.providers];
    final index = list.indexWhere((item) => item.id == safe.id);
    if (index >= 0) {
      list[index] = safe;
    } else {
      list.add(safe);
    }
    await save(current.copyWith(providers: list));
  }

  Future<void> removeProvider(String id) async {
    final current = state.value ?? AppSettings.initial();
    await save(current.copyWith(
      providers: current.providers.where((item) => item.id != id).toList(),
    ));
  }

  Future<void> setDefaultProvider(String? id) async {
    final current = state.value ?? AppSettings.initial();
    await save(AppSettings(
      schemaVersion: current.schemaVersion,
      language: current.language,
      themeMode: current.themeMode,
      defaultExportFormats: current.defaultExportFormats,
      defaultAiProviderId: id,
      providers: current.providers,
      researchEnabled: current.researchEnabled,
      autoCompileEnabled: current.autoCompileEnabled,
      watchDebounceMs: current.watchDebounceMs,
      extra: current.extra,
    ));
  }
}

// --- Profile ---

final profileProvider = AsyncNotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);

class ProfileController extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    final path = ref.watch(syncRootProvider.select((s) => s.path));
    if (path == null) return Profile.empty();
    return ProfileRepository(path).load();
  }

  ProfileRepository? _repo() {
    final path = ref.read(syncRootProvider.select((s) => s.path));
    return path == null ? null : ProfileRepository(path);
  }

  Future<void> save(Profile profile) async {
    await _repo()?.save(profile);
    state = AsyncData(profile);
  }

  Future<void> setField(String section, String key, ProfileField field) async {
    final repo = _repo();
    if (repo == null) return;
    state = AsyncData(await repo.setField(section, key, field));
  }

  Future<void> removeField(String section, String key) async {
    final repo = _repo();
    if (repo == null) return;
    state = AsyncData(await repo.removeField(section, key));
  }
}

// --- Records ---

final recordsProvider =
    AsyncNotifierProvider<RecordsController, List<ProfileRecord>>(
  RecordsController.new,
);

class RecordsController extends AsyncNotifier<List<ProfileRecord>> {
  @override
  Future<List<ProfileRecord>> build() async {
    final path = ref.watch(syncRootProvider.select((s) => s.path));
    if (path == null) return const [];
    final db = ref.watch(databaseProvider);
    if (db == null) return const [];
    return RecordsRepository(rootPath: path, db: db).loadAll();
  }

  RecordsRepository? _repo() {
    final path = ref.read(syncRootProvider.select((s) => s.path));
    final db = ref.read(databaseProvider);
    if (path == null || db == null) return null;
    return RecordsRepository(rootPath: path, db: db);
  }

  Future<void> add(ProfileRecord record) => _mutate((r) => r.save(record));

  /// 命名冲突说明：`AsyncNotifier` 自带 `update`，故用 `updateRecord`。
  Future<void> updateRecord(ProfileRecord record) =>
      _mutate((r) => r.save(record));
  Future<void> delete(String id) => _mutate((r) => r.delete(id));
  Future<void> importAll(List<ProfileRecord> records) =>
      _mutate((r) => r.importAll(records));
  Future<void> rebuildIndex() => _mutate((r) => r.rebuildIndex());

  Future<void> _mutate(Future<void> Function(RecordsRepository) op) async {
    final repo = _repo();
    if (repo == null) return;
    await op(repo);
    state = AsyncData(await repo.loadAll());
  }
}

// --- Attachments ---

final attachmentsProvider =
    AsyncNotifierProvider<AttachmentsController, List<Attachment>>(
  AttachmentsController.new,
);

class AttachmentsController extends AsyncNotifier<List<Attachment>> {
  @override
  Future<List<Attachment>> build() async {
    final db = ref.watch(databaseProvider);
    if (db == null) return const [];
    return db.allAttachments();
  }

  AttachmentRepository? _repo() {
    final path = ref.read(syncRootProvider.select((s) => s.path));
    final db = ref.read(databaseProvider);
    if (path == null || db == null) return null;
    return AttachmentRepository(rootPath: path, db: db);
  }

  Future<Attachment?> importFile(
    File source, {
    String? recordId,
    String? caption,
  }) async {
    final repo = _repo();
    if (repo == null) return null;
    final attachment = await repo.importFile(
      source,
      recordId: recordId,
      caption: caption,
    );
    state = AsyncData(await ref.read(databaseProvider)!.allAttachments());
    return attachment;
  }

  Future<void> delete(String id) async {
    final repo = _repo();
    if (repo == null) return;
    await repo.delete(id);
    state = AsyncData(await ref.read(databaseProvider)!.allAttachments());
  }
}

// --- Resume library ---

final resumeLibraryProvider =
    AsyncNotifierProvider<ResumeLibraryController, List<ResumeMeta>>(
  ResumeLibraryController.new,
);

class ResumeLibraryController extends AsyncNotifier<List<ResumeMeta>> {
  @override
  Future<List<ResumeMeta>> build() async {
    final path = ref.watch(syncRootProvider.select((s) => s.path));
    if (path == null) return const [];
    return ResumeRepository(path).listMeta();
  }

  ResumeRepository? _repo() {
    final path = ref.read(syncRootProvider.select((s) => s.path));
    return path == null ? null : ResumeRepository(path);
  }

  Future<void> saveMeta(ResumeMeta meta) async {
    final repo = _repo();
    if (repo == null) return;
    await repo.saveMeta(meta);
    state = AsyncData(await repo.listMeta());
  }

  Future<void> delete(String id) async {
    final repo = _repo();
    if (repo == null) return;
    await repo.delete(id);
    state = AsyncData(await repo.listMeta());
  }

  Future<void> refresh() async {
    final repo = _repo();
    state = AsyncData(repo == null ? const [] : await repo.listMeta());
  }
}

// --- Secrets ---

final secretStoreProvider =
    Provider<SecretStore>((ref) => SecretStore());

// --- 全量简历 ---

final fullResumeProvider = Provider<ResumeDocument?>((ref) {
  final path = ref.watch(syncRootProvider.select((s) => s.path));
  if (path == null) return null;
  final profile = ref.watch(profileProvider).value;
  final records = ref.watch(recordsProvider).value;
  if (profile == null || records == null) return null;
  // B2：编译语言接 settings.language（zh|en）。
  final language =
      ref.watch(settingsProvider.select((s) => s.value?.language ?? 'zh'));
  return const ResumeCompiler()
      .compile(profile: profile, records: records, language: language);
});
