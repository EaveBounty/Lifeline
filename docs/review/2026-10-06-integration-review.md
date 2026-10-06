# Lifeline 集成交叉审查报告（2026-10-06）

> 独立交叉审查子代理（挑刺角色）。**只审查、未改任何代码**。
> 审查对象：多子代理并行实现后的 `lifeline`（Flutter 3.44.3 + Riverpod 3.x，Android/Windows/Linux）。
> 覆盖：数据层 / AI / 导出渲染 / UI / CI / 文档许可。
> 方法：逐文件关键路径阅读 + `flutter analyze` + `flutter test`。

---

## 0. 结论摘要

| 维度 | 评价 |
|---|---|
| 编译（`flutter analyze`） | ✅ No issues found（1.9s） |
| 测试（`flutter test`） | ✅ 5/5 All tests passed |
| 契约一致性（providers 冻结 API） | 基本吻合；`updateRecord` 命名冲突已规避，无 `.update(` 误用 |
| 安全 | 密钥不入 YAML/日志（有测试佐证）；但存在**路径遍历**与 `extra_headers` 持久化密钥风险 |
| 数据完整性 | **两处会导致附件索引丢失**；"索引可 100% 重建"对附件不成立 |
| 文档一致性 | 实现与 `DATA_FORMAT.md`/`AI_PIPELINE.md` schema 漂移较大 |
| **可发布判断** | **不建议直接发布**；需先修 4 个阻断项，再处理建议项 |

---

## 1. 分级问题表

严重级：**高**=数据丢失/安全/崩溃；**中**=功能受损/一致性；**低**=整洁/文档。

| # | 级别 | 问题 | 证据（文件:行） |
|---|---|---|---|
| A1 | 高 | `rebuildIndex()` 先 `clearAll()` 清空 `attachments` 表，随后只回填 `records`，**附件索引永久丢失且无扫描恢复路径**；与"可 100% 重建"承诺矛盾 | `records_repository.dart:77-81`、`database.dart:136-139`、`providers.dart:281-285` |
| A2 | 高 | AI 录入（Capture）导入图片附件后**未回写 `record.attachments`**；附件详情页/编译器/导出读的是 `record.attachments`，故 AI 附件在记录详情不可见，重建索引即失联 | `capture_page.dart:187-197`、`ai_service.dart:87-107`、`record_detail_page.dart:162-187`（对照 `record_edit_page.dart:658-673` 已回写） |
| A3 | 高 | **路径遍历**：`ResumeRepository._dir(id)`、`RecordsRepository._fileFor` 直接用来自磁盘/同步内容的 `id` 拼路径；恶意/误编辑的 `meta.json`/record JSON 里 `id="../../x"` 可越界删除/写入。附件 `relPath` 同理被 `attachmentFileOf` 拼接读取 | `resume_repository.dart:23,64`、`records_repository.dart:29-30,69-74`、`attachment_preview.dart:12-13` |
| A4 | 中 | 启动不校验被记忆的同步根是否仍存在：`hasRoot` 只看非空字符串，`databaseProvider` 用 `NativeDatabase.createInBackground` 直接在可能不存在的父目录开库（静态 `open()` 会建父目录但从未被调用）→ 异步异常或静默空态 | `providers.dart:74-79`、`app_config.dart:20-23`、`root_manager.dart:46-50`、`database.dart:54-64` |
| B1 | 中 | CJK 字体：`FontResolver` 的打包候选依赖 `assets/fonts/`，但 `pubspec.yaml` **未声明任何 assets**，候选恒失败；且显式跳过 `.ttc`，现代 Android/Linux 常见 Noto CJK 为 `.ttc` → 中文 PDF 可能缺字（优雅降级为 Helvetica，但正文不可读） | `font_resolver.dart:35-41,141`、`pubspec.yaml:63-65` |
| B2 | 中 | `fullResumeProvider` 以默认 `language='zh'` 编译，**未接 settings.language**（已知问题，确认存在于 `providers.dart:360-367`；`settings_page.dart:186-189` 可改语言但无效） | `providers.dart:360-367`、`resume_compiler.dart:15` |
| B3 | 中 | 导出忽略 `settings.defaultExportFormats`（硬编码 `['pdf','docx','md']`）；Provider 选择弹窗不预选 `defaultAiProviderId` | `export_service.dart:33`、`export_page.dart:149-167` |
| B4 | 中 | `autoCompileProvider` 为非 autoDispose 的 `Provider`，`app.dart` 条件 `ref.watch`；detach 后 provider 不再被监听可能不重算，旧 `ChangeWatcher`/轮询 Timer 泄漏并继续对已卸载根 invalidate。已确认**不会无限循环**（回调只 invalidate，不写盘） | `auto_compile.dart:11-36`、`app.dart:22-24`、`change_watcher.dart:52,86-96` |
| B5 | 中 | 文档 schema 与实现漂移：`lifeline.yaml`（`app.theme_mode` vs 文档 `app.theme`，缺 `sync/ui/prompt_preferences`）、`profile.json`（实现为 `sections{}` 包裹 vs 文档平铺）、record/profile **缺 `schema_version`**、`meta.json`/`spec.json` 字段名与结构不符 | `app_settings.dart:56-75`、`profile.dart:77-82`、`profile_record.dart:151-172`、`docs/DATA_FORMAT.md:49-79,100-161,280-331` |
| B6 | 中 | 密钥降级文件名/位置文档不符：实现为 App 支持目录 `secrets.local.json`，`constants.secretsFile='secrets.local.yaml'` 从未使用，README/ARCHITECTURE 却将其列为同步根文件 | `secret_store.dart:20`、`constants.dart:22`、`README.md:147`、`ARCHITECTURE.md:121` |
| B7 | 中 | `AiProvider.extraHeaders` 会随 `providers[]` 持久化到 `lifeline.yaml`；若用户在其中填 `Authorization`/密钥即泄入可同步 YAML（当前 UI 无入口，但模型/导入可触发） | `ai_provider.dart:69`、`app_settings.dart:62-65` |
| B8 | 中 | 导入 JSON / 记录保存不校验 `id` 为 UUID：`importAll` 直接以 `record.id` 建文件，可越界或覆盖 | `records_repository.dart:69-74`、`records_page.dart:84-103` |
| B9 | 中 | CI `build.yml` 的 `pull_request` 未声明 `permissions`（依赖仓库默认，建议 `contents: read`）；第三方 action 以浮动 tag（`@v4`/`@v2`）引用，未 pin SHA | `.github/workflows/build.yml:1-7,17-26` |
| C1 | 低 | 死依赖：`window_manager` 全仓无引用、从未初始化；`printing`/`yaml_edit`/`csv`/`intl`/`collection` 未见使用 | `pubspec.yaml:26,30,40,46,52,54`；grep 无引用 |
| C2 | 低 | `writeBytesAtomic` 用 `tmp.rename(target)` 覆盖；Windows 下 rename 覆盖行为需实测确认（潜在失败） | `file_utils.dart:21-29` |
| C3 | 低 | `setDefaultProvider` 手工重建 `AppSettings`（因 `copyWith` 无法置 null），新增字段易被漏掉 | `providers.dart:176-190` |
| C4 | 低 | `JsonFileStore._baseline` 为跨实例静态、永不清理；进程重启后首轮覆盖外部已改文件不备份（已在注释声明为有意） | `json_file_store.dart:20,71-81` |
| C5 | 低 | `AiService.tailor` / `AiService.research` 为死代码（导出走 `ExportService` 自有实现） | `ai_service.dart:180-291`、`export_service.dart:137-234` |
| C6 | 低 | 文档/资产缺失：README 引用的 `docs/assets/screenshot-*.png`、`tool/subset_fonts.py`、`flutter gen-l10n`/`lib/l10n/` 均不存在；README 列 `docx_template` 但 pubspec 无 | `README.md:71-80,213-217,242`、`ARCHITECTURE.md:69-72,105` |

---

## 2. 三档处置

### 必须修（阻断发布）

1. **A1 附件索引重建即丢失** — 重建流程应改为：扫描 `data/records/**` 与 `profile.json` 的 `attachments[]`/`photo.path` 重建 `attachments` 表；`clearAll()` 不得孤立清空不可再生数据。（`records_repository.dart:77`）
2. **A2 AI 录入附件未回写记录** — Capture 保存成功后应 `updateRecord(record.copyWith(attachments: [...rels]))`，与 `record_edit_page` 对齐。（`capture_page.dart:187`）
3. **A3 路径遍历** — 对 `resume id`/`record id` 施加 UUID/`[A-Za-z0-9._-]` 白名单校验并断言解析后路径位于根下；附件 `relPath` 必须 `p.normalize` 后校验前缀。（`resume_repository.dart:23`、`attachment_preview.dart:12`）
4. **A4 启动根校验** — 启动时 `probe` 记忆根，非 `initialized` 则清空本地 `sync_root` 并回到首启页；或在 `databaseProvider` 打开前 `ensureDir(parent)`。（`providers.dart:74`、`database.dart:54`）

### 建议修

- B1 字体：声明 `assets/fonts/` 并内嵌 OFL CJK（兑现 NOTICE/README 承诺），或至少支持从 `.ttc` 提取所需字体。
- B2 语言接线：`fullResumeProvider` 读取 `settingsProvider.language` 传入编译器。
- B3 导出：采用 `defaultExportFormats`，弹窗预选默认 Provider。
- B4 watcher 生命周期：改为 `autoDispose` + `ref.keepAlive` 显式策略，或确保 detach 时同步 `stop()`。
- B5/B6 文档对齐：统一 YAML/profile/meta/spec schema，补 `schema_version`；`secrets.local.*` 名称/位置三者一致，删除或启用 `constants.secretsFile`。
- B7 禁止 `extra_headers` 承载 `Authorization`（保存前剥离/告警）。
- B8 导入前校验 `id` 为 UUID。
- B9 `build.yml` 增加 `permissions: contents: read`，action pin SHA。

### 可忽略（暂不阻塞）

- C1 死依赖清理（减包体）；C2 待 Windows 实测；C3 记录用 `copyWith` 扩展；C4 首轮不备份可接受（已注释）；C5 删死代码；C6 占位文档/截图补齐。

---

## 3. 必查清单逐项结论

1. **契约一致性**：✅ `providers.dart` 暴露 `add/updateRecord/delete/importAll/rebuildIndex`，全仓无 `recordsProvider.notifier.update(` 误用，`AsyncNotifier.update` 冲突已用命名规避（`providers.dart:256-259`）。无空根崩溃：无根时所有 Async provider 返回空默认值（`providers.dart:124-132,143-147,239-245`）。`AsyncValue` 均有 `.when`/`.value ??` 处理。
2. **导出链路**：✅ `ExportPage` 取 `fullResumeProvider`、读密钥、经 `ResumeRepository(root)` 写 `data/resumes/<id>/resume.*`（`export_page.dart:60-128`、`export_service.dart:80-131`）。降级可用：`renderersFor` 对 PDF 返回 `[Typst, DartPdf]` 互为兜底（`renderer_registry.dart:16-33`）；Typst 未找到返回 `Err` 后继续下一渲染器（`typst_renderer.dart:75-78`、`export_service.dart:84-101`）。⚠ 但默认格式与默认 Provider 未接 settings（B3）。
3. **AI 链路**：✅ `analyzeEntry` 空输入拦截、vision 能力校验、无密钥引导（`ai_service.dart:129-139,294-325`；`capture_page.dart:255-281`）。JSON 解析经 `extractJsonBlock`+`_firstRecordMap`+`EntryDraft.fromJson`，非法分类抛 `FormatException` 转 `Err`（`ai_service.dart:63-84,163-177`）。模型输出仅作数据解析（`import 'dart:convert'`，无 `Process`/`eval`），提示词注入防御到位（`prompts.dart:15-52`、`export_service.dart:143-179,172-179`）。⚠ `EntryDraft.toRecord` 不含 attachments（即 A2）。
4. **安全**：⚠ 路径遍历见 A3；密钥不入 YAML/日志 ✅（`ai_provider.dart:61-70` 无密钥、`settings_repository.dart` 只写 `toJson`、测试 `data_layer_test.dart:57-77` 佐证）；提示词注入面有系统级防注入约束 ✅。CI `pull_request` 权限缺失见 B9。
5. **数据完整性**：原子写 ✅（`file_utils.dart:21-29`）；冲突副本 ✅ 但仅在同进程已知基线时（`json_file_store.dart:71-81`，C4）；一文件一记录 ✅（`records_repository.dart:29-30`）；⚠ 索引重建缺陷 A1；`fullResumeProvider` 语言未接 B2。
6. **自动编译**：`autoCompileProvider` 由 `app.dart:22-24` 挂载 ✅；不会无限循环 ✅（回调仅 invalidate，`auto_compile.dart:25-31`、`change_watcher.dart:45-52`）；dispose 会 `stop()` 并取消 Timer/Debouncer（`change_watcher.dart:86-96`、`debounce.dart:20-23`）。⚠ detach 生命周期泄漏 B4。
7. **首启铁律**：✅ 未发现任何启动自动 `initialize`；`initialize` 仅在用户确认后经 `initializeAndAttach` 调用于空/外来目录（`sync_root_setup_page.dart:52-79`）；直接 `attach` 已初始化目录不会创建结构（`root_manager.dart:121-145`）；`probe` 不修改内容（`root_manager.dart:59-70`）；外来目录二次确认后共存不删除 ✅。
8. **可运行性**：见 §4 原文。SQLite 原生库经 `drift_flutter → sqlite3_flutter_libs` 传递依赖已锁定（`pubspec.lock:1053`），Android 原生库风险低；`SharedPreferences` 在 `runApp` 前 `ensureInitialized` 后加载 ✅（`main.dart:12-16`）；`window_manager` 未初始化但全仓无引用（C1），不构成崩溃。
9. **许可合规**：LICENSE 为 PolyForm Noncommercial 1.0.0 全文 ✅（`LICENSE:11-141` 与官方文本一致）；NOTICE 逐项登记依赖/资产并明确禁止 GPL/AGPL 入包 ✅（`NOTICE:3-118`）；未发现 GPL/AGPL 混入。⚠ 内嵌字体在 NOTICE 声明但未实际打包（B1），属"声明与交付不一致"。

---

## 4. 可运行性：`flutter analyze` / `flutter test` 原文

```
===== FLUTTER ANALYZE =====
Analyzing lifeline...
No issues found! (ran in 1.9s)
===== ANALYZE EXIT: 0 =====
```

```
===== FLUTTER TEST =====
00:00 +0: loading .../test/data_layer_test.dart
00:00 +0: ... ProfileRecord JSON 往返 字段与列表完整保留
00:00 +1: ... AppSettings YAML 往返 保存后可完整读回
00:00 +2: ... RootManager.initialize 结构 创建目录与默认文件，且不破坏已有内容
00:00 +3: ... ResumeCompiler 基本编译 header/summary/分组与状态过滤
00:00 +4: ... 首启且无同步根时显示「选择同步文件夹」
00:01 +5: All tests passed!
===== TEST EXIT: 0 =====
```

运行时崩溃风险小结：
- 无根/根失效：A4（`NativeDatabase` 父目录缺失 + 无启动 probe）。
- 中文 PDF：B1（仅降级缺字，不崩）。
- 其余（`SharedPreferences`、`sqlite3` 原生库、`window_manager`）已排除或未触发。

---

## 5. 审查日志

- 2026-10-06 独立交叉审查：静态阅读 + analyze/test；产出分级问题表与三档处置，未改动任何业务代码。
