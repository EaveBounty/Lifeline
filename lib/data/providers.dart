/// Riverpod 3 provider 层（冻结给 UI 的 API）。
///
/// 无同步根时所有 Async provider 返回空默认值，不抛错。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/logging.dart';
import '../core/platform/io_platform.dart';
import '../core/result.dart';
import '../services/compile/resume_compiler.dart';
import '../services/secrets/secret_store.dart';
import 'config/app_config.dart';
import 'db/record_index_factory.dart';

/// 内存索引（打开失败时的兜底；纯 Dart，全平台可用）。
import 'db/record_index_web.dart' show MemoryRecordIndex;
import 'models/ai_provider.dart';
import 'models/app_settings.dart';
import 'models/attachment.dart';
import 'models/export_request.dart';
import 'models/profile.dart';
import 'models/profile_record.dart';
import 'models/record_category.dart';
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

/// App 私有支持目录（io 端由 main 注入；web/未注入时为 null）。
///
/// 索引库是**设备本地、可重建**的派生缓存，放这里可避免
/// Android 分区存储下无法在外部同步文件夹内打开 SQLite（code 14）。
final appSupportDirProvider = Provider<String?>((ref) => null);

/// 索引数据库；无根时为 null。打开失败时回退内存索引（本次会话），不崩溃。
final databaseProvider = Provider<RecordIndex?>((ref) {
  final path = ref.watch(syncRootProvider.select((s) => s.path));
  if (path == null) return null;
  final supportDir = ref.watch(appSupportDirProvider);
  final indexPath = supportDir == null
      // Web / 未注入支持目录：沿用同步根（web 为内存 FS，忽略路径）。
      ? p.join(path, SyncLayout.dataDir, SyncLayout.indexFile)
      // 原生：放 App 私有目录，文件名按同步根哈希区分。
      : p.join(
          supportDir,
          'index',
          '${sha1.convert(utf8.encode(path)).toString().substring(0, 16)}.sqlite',
        );
  try {
    final db = openRecordIndex(indexPath);
    ref.onDispose(db.close);
    return db;
  } catch (e, st) {
    appLog.warning('索引库打开失败（$indexPath），本次会话回退内存索引: $e', e, st);
    final mem = MemoryRecordIndex();
    ref.onDispose(mem.close);
    return mem;
  }
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
      categories: current.categories,
      researchEnabled: current.researchEnabled,
      autoCompileEnabled: current.autoCompileEnabled,
      watchDebounceMs: current.watchDebounceMs,
      extra: current.extra,
    ));
  }

  // --- 分类（开放、可编辑）---

  Future<void> addCategory(CategoryDef def) async {
    final current = state.value ?? AppSettings.initial();
    final list = [...current.categories];
    if (list.any((c) => c.slug == def.slug)) return;
    list.add(def);
    await save(current.copyWith(categories: _renumber(list)));
  }

  Future<void> updateCategory(CategoryDef def) async {
    final current = state.value ?? AppSettings.initial();
    final list = [
      for (final c in current.categories) if (c.slug == def.slug) def else c,
    ];
    await save(current.copyWith(categories: sortedCategories(_renumber(list))));
  }

  Future<void> removeCategory(String slug) async {
    final current = state.value ?? AppSettings.initial();
    if (current.categories.length <= 1) return;
    final list = current.categories.where((c) => c.slug != slug).toList();
    await save(current.copyWith(categories: _renumber(list)));
  }

  /// 持久化用户拖拽后的顺序（按传入顺序写 order）。
  Future<void> reorderCategories(List<CategoryDef> ordered) async {
    final current = state.value ?? AppSettings.initial();
    await save(current.copyWith(categories: _renumber(ordered)));
  }

  List<CategoryDef> _renumber(List<CategoryDef> list) => [
        for (var i = 0; i < list.length; i++) list[i].copyWith(order: i),
      ];
}

/// 当前生效的分类（按 order 排序）；无设置时回退默认集。
final categoriesProvider = Provider<List<CategoryDef>>((ref) {
  final s = ref.watch(settingsProvider).value;
  final list = s?.categories ?? kDefaultCategories;
  return sortedCategories(list.isEmpty ? kDefaultCategories : list);
});

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

  /// 删除分类前，将该分类下的记录迁移到 [toSlug]，返回迁移数。
  Future<int> moveCategory(String fromSlug, String toSlug) async {
    final repo = _repo();
    if (repo == null) return 0;
    final n = await repo.moveCategory(fromSlug, toSlug);
    state = AsyncData(await repo.loadAll());
    return n;
  }

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

final secretStoreProvider = Provider<SecretStore>((ref) {
  final root = ref.watch(syncRootProvider.select((s) => s.path));
  return SecretStore(rootPath: root);
});

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
  final categories = ref.watch(categoriesProvider);
  return const ResumeCompiler().compile(
    profile: profile,
    records: records,
    language: language,
    categories: categories,
  );
});
