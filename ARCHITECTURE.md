# Lifeline · 履痕 — 系统架构蓝图 (ARCHITECTURE)

> 个人资料管理软件。Flutter 跨平台（Android / Windows / Linux）。
> 本文件是**唯一权威蓝图**：目录结构、数据格式、模块边界、编译管线、构建与 CI。
> 变更须同步本文件并在文末追加变更日志行。

---

## 0. 一句话定位

Lifeline 把散落的个人信息（教育、工作、项目、奖项、论文、证书、附件……）以**可外部挂载、可被任意工具同步的纯文本文件夹**为真相源，聚合成一份**不断自动编译的完整简历**，并能用 AI 自动录入、按岗位**定向编译导出**。

---

## 1. 核心设计原则

| 编号 | 原则 | 落地 |
|---|---|---|
| P1 | **数据/配置与软件解耦** | 所有用户数据在用户选定的「同步根目录」；App 自身只读、不写自身目录 |
| P2 | **软件不做同步** | 仅读写文件夹；同步交给 Syncthing / WebDAV / Git（软件内给出推荐与指南） |
| P3 | **文本优先、可 diff、可合并** | 真相源 = JSON / YAML（易被 Git 合并、Syncthing 同步）；SQLite 仅为**可重建索引** |
| P4 | **禁止私自创建目录** | 首启必须由用户**亲自选择**同步根位置；空目录需二次确认后初始化 |
| P5 | **一切可重建** | 删除 `index.sqlite` 可由 JSON 100% 重建；删除模板可由仓库恢复 |
| P6 | **编译 = DB→ResumeDocument 的纯函数** | 任何数据变更 → 规范化 → 渲染；同结构数据必得同结果 |
| P7 | **平台能力抽象** | 渲染/字体/密钥存储/文件选择等平台差异一律藏在 Interface 之后 |
| P8 | **安全默认** | 密钥不进同步 YAML；网络动作先汇报后批准；提示词注入防御 |

---

## 2. 技术栈（版本以 `pubspec.yaml` 为准）

| 层 | 选型 | 版本 | 备注 |
|---|---|---|---|
| 语言/框架 | Flutter / Dart | 3.44.3 / 3.12.2 | 环境已装 |
| 状态管理 | `flutter_riverpod` | 3.4.3 | 见 research 01 |
| 路由 | `go_router` | 18.0.2 | 要求 Flutter ≥3.44 |
| 结构化索引 | `drift` + `drift_flutter` | 2.35.1 / 0.3.1 | SQLite，全平台 |
| YAML | `yaml` + `yaml_edit` | 3.1.4 / 2.2.4 | 读写+程序化编辑 |
| 密钥 | `flutter_secure_storage` | 11.2.0 | **含降级**（见 §7.4） |
| 文件/目录选择 | `file_picker`（备 `file_selector`） | 13.1.0 | 桌面依赖 zenity/kdialog |
| 图片 | `image_picker`(移动) + `file_picker`(桌面) | 1.2.4 | |
| PDF 通用 | `pdf` + `printing` | 3.13.1 / 5.15.1 | 纯 Dart 兜底，全平台 |
| PDF 桌面精品 | Typst 二进制 | 0.15.1 (Apache-2.0) | Windows/Linux |
| PDF 安卓 | Typst FFI（`typst_flutter` 起步） | 3.0.0(锁版) | **风险项**，见 §6.3 |
| DOCX | `docx_template`（模板法）→ 手写 OOXML 兜底 | 0.4.0 | **无成熟方案**，见 §6.4 |
| FS 监听 | `watcher` + polling 兜底 | 1.2.1 | 云盘事件不可靠 |
| Markdown | `flutter_markdown_plus` | 1.0.12 | 原 `flutter_markdown` 已停维 |
| HTTP/LLM | `dio` | 5.11.1 | OpenAI 兼容 |
| 桌面窗口 | `window_manager` | 0.5.2 | |
| 其他 | `path_provider`,`path`,`uuid`,`intl`,`logging`,`url_launcher`,`crypto`,`csv` | — | |
| 字体 | 内嵌 OFL CJK + Latin（子集化） | — | 离线可用，防白屏 |

> 依赖以 `docs/research/01-flutter-stack.md` 为准；每次升级须更新本表 + README。

---

## 3. 目录结构（代码）

```
lifeline/
├── ARCHITECTURE.md          README.md  LICENSE  COMMERCIAL.md  NOTICE  CHANGELOG.md
├── pubspec.yaml  analysis_options.yaml  .gitignore  .metadata
├── docs/
│   ├── research/01-flutter-stack.md   02-resume-compile.md
│   ├── DATA_FORMAT.md       # 磁盘数据格式权威说明
│   ├── AI_PIPELINE.md       # 自动录入/编译/导出 提示词与流程
│   ├── SYNC.md              # Syncthing/WebDAV/Git 指南
│   └── DEV.md               # 构建/打包/CI 说明
├── assets/
│   ├── fonts/               # 内嵌字体(OFL)，含 CJK
│   ├── typst/               # 简历模板(.typ) + 许可说明(仅宽松许可)
│   └── icons/
├── lib/
│   ├── main.dart            # 入口: 初始化 → ProviderScope → App
│   ├── app.dart             # MaterialApp.router + 主题 + 国际化 + 路由
│   ├── core/
│   │   ├── constants.dart   # 应用常量、目录名、文件后缀
│   │   ├── result.dart      # Result<T> 错误封装
│   │   ├── logging.dart
│   │   ├── utils/           # hash.dart file_utils.dart debounce.dart date_widgets
│   │   └── theme/           # app_theme.dart (M3, 亮/暗)
│   ├── data/
│   │   ├── models/          # profile.dart record.dart attachment.dart resume_doc.dart
│   │   │                    # settings.dart ai_provider.dart export_request.dart
│   │   ├── json_store/      # json_repository.dart  file_watcher.dart
│   │   ├── db/              # database.dart tables.dart dao/*.dart rebuild.dart
│   │   ├── config/          # app_config.dart (本地)  sync_config.dart (YAML)
│   │   └── repositories/    # profile_repo attachment_repo resume_repo
│   ├── features/
│   │   ├── onboarding/      # sync_root_setup_page.dart
│   │   ├── home/            # full_resume_page.dart  widgets/*
│   │   ├── records/         # list/edit/detail/import
│   │   ├── attachments/     # gallery/preview
│   │   ├── settings/        # settings_page.dart ai_settings_page.dart
│   │   ├── ai/              # capture_page.dart (自动录入)  recompile_controller
│   │   ├── export/          # questionnaire_page.dart resume_manager_page.dart
│   │   └── sync_guide/      # sync_guide_page.dart
│   ├── services/
│   │   ├── ai/              # llm_client.dart  prompts/*.dart  vision.dart
│   │   ├── compile/         # resume_compiler.dart (DB→ResumeDocument)
│   │   ├── render/          # renderer.dart(接口) typst_renderer.dart
│   │   │                    # dart_pdf_renderer.dart docx_renderer.dart md_renderer.dart
│   │   ├── watch/           # change_watcher.dart (FS+poll+debounce)
│   │   └── import_export/   # importer.dart exporter.dart
│   └── l10n/                # app_zh.arb app_en.arb (gen-l10n)
├── test/                    # 单元 + widget 测试
├── tool/                    # fetch_typst.sh  subset_fonts.py  (构建期辅助)
├── .github/workflows/       # build.yml  release.yml
├── android/  windows/  linux/
```

---

## 4. 磁盘数据格式（同步根目录）

> 权威细则见 `docs/DATA_FORMAT.md`。以下为结构总览。

```
<SyncRoot>/                     # 由用户在首启时亲自选择，App 不擅自创建
├── lifeline.yaml               # 设置(YAML，无密钥，可安全同步)
├── data/
│   ├── profile.json            # 单例：身份/联系方式/求职意向/自我评价/偏好
│   ├── records/<category>/<uuid>.json     # 一条一文件，降低同步冲突
│   ├── index.sqlite            # 派生索引(可重建，建议 .gitignore)
│   └── resumes/<resume-id>/
│       ├── meta.json           # 岗位/企业/要求/用途/状态/版本/评分
│       ├── spec.json           # 该定向简历的 ResumeDocument(裁剪后)
│       ├── resume.pdf  resume.docx  resume.md
├── attachments/<yyyy>/<sha1[-8]>-<原文件名>           # 相对路径被记录索引
└── .lifeline/
    └── state.json              # schema_version / 迁移记录 / 最近编译状态
```

> 密钥降级文件 `secrets.local.json` **不在同步根内**，位于 App 支持目录
> （`getApplicationSupportDirectory()`），默认不同步（见 `DATA_FORMAT.md` §3）。

### 4.1 记录（Record）通用 schema
```jsonc
{
  "schema_version": 1,
  "id": "uuid-v4",
  "category": "education|experience|projects|awards|publications|certificates|
               skills|activities|trainings|languages|research|works|interests|references|custom",
  "title": "string",
  "organization": "string?",
  "role": "string?",
  "location": "string?",
  "start_date": "YYYY-MM | YYYY-MM-DD | null",
  "end_date": "YYYY-MM | null (=进行中)",
  "description": "markdown string",
  "highlights": ["量化成果(STAR)"],
  "tags": ["string"],
  "fields": { "major": "...", "gpa": "...", "...": "类目专属结构化键值" },
  "attachments": ["attachments/2026/ab12cd34-证书.jpg"],
  "links": [{"label":"","url":""}],
  "source": {"type":"manual|ai|import","raw":"原始输入","ref":"来源"},
  "ai": {"model":"...","confidence":0.0,"reviewed":true},
  "created_at":"ISO8601","updated_at":"ISO8601",
  "status":"active|archived",
  "order": 0
}
```

### 4.2 profile.json（单例，尽量全面的「信息表」）
顶层为 `{ schema_version, sections{}, photo_path, updated_at }`；`sections` 为
`分区 -> 字段 -> { key, value, attachments[], source }`。已知分区键（见 `ProfileSections`）：
`identity`、`contact`、`career_objective`、`summary`、`online`、`strengths`、
`languages_overview`、`interests_overview`、`references_overview`、`custom`（未知键照常渲染）。
`photo_path` 为头像/证件照相对路径。
> 每个字段均带 `source` 与 `attachments`，实现「一切有出处」。

### 4.3 附件（Attachment）索引
SQLite 表 `attachments`：`id, record_id?, rel_path, filename, mime, size, sha1, caption, created_at`。
真相源是文件本身 + record 内的相对路径数组；索引可重建。

---

## 5. 模块与数据流

```
外部文件夹(JSON/YAML) ── watcher ──┐
                                   ▼
  用户编辑/AI录入 ──> Repository ──> JSON 写回 ──> 重建索引(drift) ──> ChangeNotifier/Stream
                                                                        │
                          ┌─────────────────────────────────────────────┘
                          ▼
             ResumeCompiler (纯函数: DB → ResumeDocument)
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
  首页 Full Resume (Flutter 原生渲染)   Renderer 抽象
                                       ├─ TypstRenderer (桌面)
                                       ├─ DartPdfRenderer (全平台兜底)
                                       ├─ DocxRenderer
                                       └─ MarkdownRenderer
```

### 5.1 真相源与索引
- JSON/YAML = 真相源。所有写操作先写临时文件再原子 rename。
- drift 索引在启动与文件变更时增量重建；损坏可全量重建。

### 5.2 变更→重编译（自动编译）
`ChangeWatcher`（`watcher` + 轮询兜底 + debounce 500ms）监听 `data/` → 触发 `ResumeCompiler` →
首页通过 Riverpod 自动刷新；导出时使用缓存的 `ResumeDocument`。

---

## 6. 简历编译与导出管线

### 6.1 ResumeDocument（IR，平台无关）
由 `ResumeCompiler` 从 DB 生成：`Header, Summary, Sections[Section{title, items[Item]}]`。
所有渲染器（Typst/PDF/DOCX/MD）都消费**同一 IR**，保证多格式一致。

### 6.2 首页「完整简历」
Flutter 原生渲染（`CustomScrollView` + sections），实时反映 DB；不是导出文件。
可一键「编译为 PDF/DOCX/MD」以验证。

### 6.3 PDF 渲染（分平台，抽象在 `Renderer` 接口后）
| 平台 | 实现 | 说明 |
|---|---|---|
| Windows/Linux | **Typst 0.15.1 内嵌二进制** `Process.run` | 模板 `assets/typst/*.typ`，数据经 `sys.inputs` 传 JSON |
| Android | Typst **FFI**（起步 `typst_flutter`，锁版；长期 `typst-as-lib`+NDK） | 风险：包体 +20~33MB/ABI + CJK 字体；失败则退 `DartPdfRenderer` |
| 全平台兜底 | `pdf` 纯 Dart | 无外部依赖，排版较弱 |

> **Android Typst 属高风险**：Phase 内先以 DartPdfRenderer 保证可用，Typst-FFI 作为增强项 POC，不可阻塞发布。

### 6.4 DOCX
- 首选 `docx_template` 模板法（ATS 友好的单列朴素版式）。
- 若不可用 → 手写 OOXML 模板字符串替换（最小可用）。
- **不**由精美 Typst PDF 反向转换（ATS 与多列冲突）。

### 6.5 Markdown
纯 Dart 直接由 IR 渲染，供二次加工与版本对比。

### 6.6 智能导出流程
1. 问卷（用途/岗位/企业/行业/页数/风格/语言/取舍倾向）→ `ExportRequest`
2. 调研步：LLM 结合 `docs/AI_PIPELINE.md` 模板，产出岗位需求分析 + 裁剪策略（可选联网）
3. 裁剪：IR → AI 精简 → 校验（关键信息不丢）→ `spec.json`
4. 渲染 → `resume.{pdf,docx,md}`
5. 落盘 `data/resumes/<id>/` 并登记 `meta.json`（岗位/要求/文档/状态/是否需重生成）

---

## 7. AI 子系统

### 7.1 Provider 配置
支持多家 OpenAI 兼容厂商；`providers[]` 存 YAML（`id/name/base_url/model/capabilities`），
密钥经 `key_ref` 指向系统密钥库（或本地降级文件 `secrets.local.json`，App 支持目录）。
能力：`text`、`vision`、`json`。保存前剥离 `extra_headers` 中的 `Authorization`/密钥类头部。

### 7.2 自动录入（Capture）
输入文字或佐证图片 →（图片走 vision）→ LLM 输出**严格 JSON**：
`{category, title, fields, optimized_description, highlights, tags, attachments_suggestions, missing_questions, confidence}` →
用户确认/微调 → 写 JSON → 重建索引 → 触发重编译。

### 7.3 自动编译
见 §5.2。变更监测 + 纯函数编译 + UI 实时刷新。

### 7.4 密钥安全与降级
优先 `flutter_secure_storage`；Linux 缺 libsecret/gnome-keyring 或无桌面会话时，降级到
App 本地受权限文件（非同步根内），并在 UI 显式提示风险与迁移方法。

---

## 8. 首启与设置

### 8.1 首启（强制）
1. 启动即检查本地 App 配置中的 `sync_root`；若记忆的根经 `RootManager.probe` 校验非
   `initialized`（目录不存在/被删除/不再含 `lifeline.yaml`），则清空本地 `sync_root` 并回到首启页。
2. 无 → 进入 `SyncRootSetupPage`：**必须用户亲自选择**目录。
3. 目录已有 `lifeline.yaml` → 打开；为空 → 弹确认「是否在此初始化 Lifeline 结构？」→ 同意后才创建。
4. 写本地 App 配置（不在同步根内）记录 `sync_root`；初始化 `state.json`。

### 8.2 设置页
外观/语言、同步根切换、**API/模型厂商设置**、导出默认格式、AI 提示词偏好、数据重建（重建索引）、
同步方式推荐入口、关于/许可与署名。

---

## 9. 构建与 CI

- 本地（Linux）：`flutter build apk`、`flutter build linux`。
- **Windows 产物必须在 Windows runner 构建**（Flutter 不支持交叉编译）→ GitHub Actions。
- `.github/workflows/build.yml`：矩阵 `ubuntu-latest`(android+linux) / `windows-latest`(windows)；
  步骤含 setup-flutter、pub get、拉取 Typst 二进制与字体（`tool/` 脚本）、构建、上传 artifact。
- `.github/workflows/release.yml`：`v*` tag 触发，构建矩阵产物 + 便携 zip 上传 Release。

---

## 10. 许可与合规

- 仓库：`EaveBounty/Lifeline`，许可 **PolyForm Noncommercial 1.0.0**。
- 署名：代码版权「长沙市果垂素宇工程设计有限公司」；GitHub 用户名/URL 除外。
- 内嵌第三方资产（Typst 二进制 Apache-2.0、简历模板 MIT/Apache/Unlicense、字体 OFL）逐项登记于 `NOTICE`，
  **禁止**引入 GPL/AGPL 资产入发行包。
- `COMMERCIAL.md` 说明商用授权获取方式。

---

## 11. 风险登记（Top）

| # | 风险 | 影响 | 缓解 |
|---|---|---|---|
| R1 | Android 无 Typst 官方二进制 | PDF 精美度/包体 | 抽象层 + DartPdf 兜底；Typst-FFI 仅增强 POC |
| R2 | DOCX 无成熟 Dart 包 | 无法导出 Word | 模板法 + 手写 OOXML 兜底 + Markdown 兜底 |
| R3 | 云盘目录 FS 事件不可靠 | 自动重编译漏触发 | polling 兜底 + 手动刷新 + 启动全量比对 |
| R4 | Linux 密钥库缺失 | API Key 存不了 | 权限文件降级 + UI 提示 |
| R5 | drift/sqlite3 原生库随包 | 桌面/CI 首建失败 | CI 首建即验证；必要时固定版本 + native assets |
| R6 | 多端并发写 JSON 冲突 | 数据覆盖 | 一条一文件 + 原子写 + 冲突副本 `.conflict` + 文档建议 Git 分支策略 |
| R7 | 提示词注入（AI 读入不可信内容） | 越权/数据外泄 | 输入视作数据、输出严格 schema 校验、不执行模型指令 |

---

## 12. 实施阶段（Action Units）

- **U0** 脚手架 + 依赖 + 目录 + 主题 + 路由 骨架
- **U1** 数据层：models / JSON 真相源 / drift 索引 / YAML 配置 / 根目录管理
- **U2** 首启同步根选择 + 初始化确认 + 设置页骨架
- **U3** 信息表与附件：CRUD、预览、编辑、导入导出
- **U4** 首页完整简历（原生渲染）
- **U5** 编译管线 + Renderer 抽象（MD/DartPdf 先行；Typst 桌面；DOCX）
- **U6** AI：Provider 设置 + 自动录入 + 自动编译
- **U7** 智能导出 + 简历管理
- **U8** 同步推荐 UI + 文档
- **U9** 测试、交叉审查、CI、发布

> 每单元遵循 PLAN→ACTION→(执行子代理→多角度审查子代理)→REVIEW，并在 README 追加日志。

---

## 变更日志
- 2026-10-06 初版：锁定技术栈、数据格式、编译管线、风险与实施阶段。
- 2026-10-06 修复对齐（A1-A4/B1-B9）：附件索引可随重建恢复、AI 录入回写附件、id/附件路径白名单与越界校验、启动根 probe 校验、内嵌 CJK 字体、语言/导出默认项接线、watcher autoDispose、`extra_headers` 脱敏、导入 id 校验、CI `permissions: contents: read`；profile 结构更正为 `sections{}`、补 `schema_version`、`secrets.local.json` 更正为 App 支持目录。
