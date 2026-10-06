# 开发指南（DEV）

> Lifeline · 履痕 的开发、构建、打包与常见问题。选型依据见 [`research/01-flutter-stack.md`](research/01-flutter-stack.md) 与 [`research/02-resume-compile.md`](research/02-resume-compile.md)。
> 架构与目录权威见 [`../ARCHITECTURE.md`](../ARCHITECTURE.md)。

---

## 1. 环境要求

| 项 | 版本/说明 |
|---|---|
| Flutter | **3.44.3 stable**（`go_router ^18` 要求 ≥3.44，不可降级） |
| Dart | **3.12.2**（随 Flutter） |
| Android | Android SDK、Build-Tools；Typst FFI 路线需 **NDK r27+**（16 KB page 对齐） |
| Windows | Visual Studio 2022（Desktop development with C++）+ CMake |
| Linux | `libsecret-1-dev`、`libjsoncpp-dev`；运行时 gnome-keyring/kwallet；`zenity`/`qarma`/`kdialog` |
| Python（构建期辅助） | Python 3（字体子集化 `tool/subset_fonts.py`） |

安装后自检：

```bash
flutter --version
flutter doctor -v
flutter config --list
```

---

## 2. 目录说明（开发视角）

| 路径 | 职责 |
|---|---|
| `lib/main.dart` | 入口：初始化 → `ProviderScope` → `App` |
| `lib/app.dart` | `MaterialApp.router` + 主题 + 国际化 + 路由 |
| `lib/core/` | 常量、`Result<T>`、日志、工具（hash/file/debounce/date）、主题 |
| `lib/data/models/` | `profile` `record` `attachment` `resume_doc` `settings` `ai_provider` `export_request` |
| `lib/data/json_store/` | JSON 真相源读写、文件监听 |
| `lib/data/db/` | drift 数据库、表、DAO、重建逻辑 |
| `lib/data/config/` | 本地配置（App 自身）与同步根 YAML 配置 |
| `lib/data/repositories/` | profile / attachment / resume 仓储 |
| `lib/features/` | onboarding / home / records / attachments / settings / ai / export / sync_guide |
| `lib/services/ai/` | LLM 客户端、提示词、vision |
| `lib/services/compile/` | `resume_compiler.dart`（DB → ResumeDocument 纯函数） |
| `lib/services/render/` | Renderer 接口 + Typst/DartPdf/DOCX/MD 实现 |
| `lib/services/watch/` | FS 监听 + 轮询 + debounce |
| `lib/services/import_export/` | 导入/导出 |
| `lib/l10n/` | `.arb` 本地化（`gen-l10n`） |
| `test/` | 单元 + widget 测试 |
| `tool/` | `fetch_typst.sh`、`subset_fonts.py` 等构建期脚本 |
| `assets/` | 字体（OFL）、Typst 模板、图标 |
| `.github/workflows/` | `build.yml` / `release.yml` |

---

## 3. 依赖版本

以 `pubspec.yaml` / `pubspec.lock` 为准；基线见 [`../README.md`](../README.md) §7 与 [`research/01-flutter-stack.md`](research/01-flutter-stack.md)。

关键约束：

- `flutter_riverpod ^3.0.0`（3.x 大版本，全项目统一）。
- `go_router ^18.0.2`（强绑 Flutter ≥3.44）。
- `drift ^2.28.0` + `drift_flutter ^0.2.4`；**不要**再加 `sqlite3_flutter_libs`（已 EOL，`sqlite3` 3.x 经 build hooks 自动打包）。
- `intl ^0.20.2`：由 `flutter_localizations` 按 Flutter 版本钉版，**不要手动超版**。

---

## 4. 获取依赖与代码生成

```bash
flutter pub get
```

### 4.1 drift 代码生成（build_runner）

```bash
dart run build_runner build --delete-conflicting-outputs
# 开发时持续监听：
dart run build_runner watch --delete-conflicting-outputs
```

- 产物为 `*.g.dart`（drift 表/DAO、序列化）。**禁止手改生成文件**。
- 修改 `lib/data/db/tables.dart`、`database.dart` 或带 `@DriftDatabase` 的文件后必须重新生成。

### 4.2 本地化

```bash
flutter gen-l10n
```

- 源为 `lib/l10n/app_zh.arb` / `app_en.arb`；`pubspec.yaml` 已设 `generate: true`。

### 4.3 Typst 与字体（构建期）

```bash
bash tool/fetch_typst.sh        # 下载对应平台 Typst 0.15.1 到 assets/typst/bin/
python3 tool/subset_fonts.py    # 按用字表子集化 CJK 字体，控制包体
```

---

## 5. 测试

```bash
flutter test                         # 全部单元 + widget 测试
flutter test test/data               # 仅数据层
flutter test --coverage              # 覆盖率
flutter analyze                      # 静态分析（flutter_lints ^5）
dart format --output=none --set-exit-if-changed lib test   # 格式检查
```

测试重点：

- JSON 真相源读写的**原子性**与**可重建性**（删 `index.sqlite` 后重建一致）。
- `ResumeCompiler` 纯函数：同输入 → 同 `ResumeDocument`。
- 冲突副本生成与解决流程。
- 日期/路径解析、敏感字段脱敏。

---

## 6. 构建与打包

### 6.1 开发运行

```bash
flutter run -d android
flutter run -d linux
flutter run -d windows      # 仅 Windows 主机
```

### 6.2 Release 构建

```bash
# Android
flutter build apk --release
flutter build appbundle --release
# Linux
flutter build linux --release
# Windows（必须在 Windows 主机构建）
flutter build windows --release
```

产物路径：

| 平台 | 产物 |
|---|---|
| Android | `build/app/outputs/flutter-apk/app-release.apk` / `.../bundle/release/app-release.aab` |
| Linux | `build/linux/<arch>/release/bundle/` |
| Windows | `build/windows/<arch>/runner/Release/` |

> **Windows 必须在 Windows runner/主机构建**：Flutter 不支持交叉编译。Linux 上无法产出 Windows 二进制。

### 6.3 便携打包

- Linux/Windows 将 `bundle/` / `Release/` 目录连同 `assets/typst/bin/`、字体一起压缩为便携 zip，随 Release 分发。

---

## 7. CI

`.github/workflows/`：

- `build.yml`：矩阵 `ubuntu-latest`（Android + Linux）/ `windows-latest`（Windows）；固定 Flutter 3.44.3；`pub get` → `build_runner` → 拉取 Typst/字体 → 构建 → 上传 artifact。
- `release.yml`：`v*` tag 触发，全平台产物 + 便携 zip 上传 Release。

CI 中务必验证 **SQLite 原生库随产物打包**。

---

## 8. 常见坑

### 8.1 Gradle 镜像 / 下载慢（中国大陆网络）

在 `android/` 与用户级 Gradle 配置中改用镜像：

- `android/settings.gradle(.kts)` 的 `pluginManagement.repositories` 与 `dependencyResolutionManagement.repositories` 增加阿里云镜像（置于 `google()`/`mavenCentral()` 之前）：
  ```
  maven { url 'https://maven.aliyun.com/repository/google' }
  maven { url 'https://maven.aliyun.com/repository/public' }
  maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
  ```
- 若下载 Gradle distribution 慢：修改 `android/gradle/wrapper/gradle-wrapper.properties` 的 `distributionUrl` 指向可用镜像。
- Flutter 国内镜像（可选）：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

### 8.2 Windows runner

- 无 Windows 主机时，只能靠 CI 的 `windows-latest`；本地无法交叉编译。
- 首次构建确保 VS2022 C++ 工作负载与 CMake 就绪；桌面窗口使用 `window_manager`，需按 `Platform` 条件调用（Android 无窗口概念）。

### 8.3 Linux 系统依赖

- 编译期：`sudo apt install libsecret-1-dev libjsoncpp-dev`（`flutter_secure_storage`）。
- 运行时：缺少 gnome-keyring/kwallet 时，`flutter_secure_storage` 会抛 `PlatformException`（如 `libsecret_error`）→ 应用**必须降级**到受权限文件（0600）并 UI 提示。
- `file_picker` 桌面依赖 `zenity`/`qarma`/`kdialog`，三者至少装其一；否则文件/目录对话框不可用（可改用 `file_selector`）。
- Linux 预编译 SQLite 库最低 **glibc 2.24**。

### 8.4 drift / sqlite3 native build hooks

- `sqlite3` 3.x 依赖 Dart build hooks 自动编译并打包原生库。
- 个别 Flutter 版本首建可能报缺原生库 → 执行一次：
  ```bash
  flutter config --enable-native-assets
  flutter clean && flutter pub get
  ```
- **不要**添加 `sqlite3_flutter_libs`（EOL，0.6.0 起不做事）。

### 8.5 版本钉版冲突

- `go_router 18` 绑 Flutter ≥3.44；`intl` 被 `flutter_localizations` 钉版。升级 Flutter 时同步核对两者。

### 8.6 文件监听与云同步目录

- `watcher` 在本地磁盘可靠；SMB/云同步盘（OneDrive/坚果云/Syncthing）**不保证 FS 事件**。
- 必须实现 **polling 兜底 + debounce（500ms）**，并在启动时做全量比对。
- Linux inotify 有 `max_user_watches` 上限，大目录需调 `/proc/sys/fs/inotify/max_user_watches`。

### 8.7 Android Typst（高风险）

- 官方无 Android 二进制；exec 方案脆弱（Android 10+ W^X、16 KB page、AAB 不解压）。
- 采用 FFI（`typst_flutter` 起步，锁版）作增强；**Phase 内先以 `DartPdfRenderer` 保证可用**，不可阻塞发布。
- 注意包体（+20~33MB/ABI）与 CJK 字体（需子集化）。

### 8.8 DOCX

- Dart 生态无成熟 DOCX 库（`docx_template` 停更、`docx_creator` 极新）。
- 首选模板法或手写 OOXML；ATS 必须**单列、标准章节标题、无表格/文本框**；**不要**由 Typst 精美 PDF 反向转 DOCX。

### 8.9 中文渲染

- 内嵌 OFL CJK 字体并子集化；PDF 复用同一字体文件；勿依赖系统字体（Linux 桌面可能缺字）。
- Typst 需显式设置 CJK 字体与回退。

---

## 9. 提交前检查清单

- [ ] `dart format` 无改动
- [ ] `flutter analyze` 无错误
- [ ] `flutter test` 通过
- [ ] `build_runner` 已重新生成（若改 schema/表）
- [ ] `pubspec.lock` 已更新（若改依赖）
- [ ] 文档（`README` / `ARCHITECTURE` / `docs/*`）已同步，追加变更日志行
- [ ] 未引入 GPL/AGPL 资产（对照 `NOTICE`）

---

## 变更日志

- 2026-10-06 初版：环境、目录、依赖、代码生成、测试、打包、CI 与常见坑（Gradle 镜像 / Windows runner / Linux libsecret / native hooks / 版本钉版 / 监听 / Typst / DOCX / 中文）。
