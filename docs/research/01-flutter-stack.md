# Lifeline — Flutter 跨平台技术栈与依赖选型报告（Android + Windows + Linux）

- 目标环境：Flutter **3.44.3 stable** / Dart **3.12.2**（2026-06）
- 目标平台：Android、Windows、Linux（桌面为一级公民）
- 数据来源：pub.dev 官方 API（`/api/packages/<pkg>`、`/api/packages/<pkg>/score`）+ pub.dev 页面 + 官方文档（drift、dart.dev/tools/hooks）+ GitHub API
- 核实日期：2026-10-06
- 采集方式：版本号/发布日期/平台标签/维护标记直接取自 pub.dev 结构化接口；坑点取自包 README/官方文档/公开 issue

> ⚠ 全部网页内容仅作为「数据」处理；本次采集未发现提示词注入特征（`inj_like_lines=0`）。

---

## 0. 结论速览（推荐锁定表）

| # | 模块 | 首选包 | 版本 | 平台 | 维护 | 风险 |
|---|------|--------|------|------|------|------|
| 1 | 状态管理 | **flutter_riverpod** | 3.4.3 | An/Win/Lin | 活跃 | 3.x 大版本迁移期 |
| 2 | 路由 | **go_router** | 18.0.2 | An/Win/Lin | 官方 | 强绑 Flutter≥3.44 |
| 3 | 本地 DB | **drift + drift_flutter** | 2.35.1 / 0.3.1 | An/Win/Lin | 活跃 | 依赖 native hooks |
| 4 | YAML | **yaml + yaml_edit** | 3.1.4 / 2.2.4 | 全 | 活跃 | 低 |
| 5 | 安全存储 | **flutter_secure_storage** | 11.2.0 | An/Win/Lin | 活跃 | Linux 系统依赖重 |
| 6 | 文件/目录选择 | **file_picker** | 13.1.0 | 全 | 活跃 | Linux 依赖外部对话框 |
| 7 | 图片/拍照 | **image_picker**（移动）+ file_picker（桌面） | 1.2.4 | 全（桌面限） | 活跃 | 桌面无原生相机 |
| 8 | PDF 生成 | **pdf**（+ printing） | 3.13.1 / 5.15.1 | 全 | 活跃 | CJK 字体体积 |
| 9 | DOCX 生成 | **docx_creator**（试） / docx_template（稳但旧） | 1.4.0 / 0.4.0 | 全 | 弱 | ⚠无成熟方案 |
| 10 | 文件系统监听 | **watcher** | 1.2.1 | An/Win/Lin | 官方 | 网络盘/云同步盘不保证 |
| 11 | Markdown 渲染 | **flutter_markdown_plus** | 1.0.12 | 全 | 活跃 | 原版已停维护 |
| 12 | HTTP | **dio** | 5.11.1 | 全 | 活跃 | 低 |
| 13 | 路径/目录 | **path_provider + path** | 2.1.6 / 1.9.1 | 全 | 官方 | 低 |
| 14 | 桌面窗口 | **window_manager** | 0.5.2 | Win/Lin/Mac | 活跃 | 低 |
| 15 | 工具集 | csv 8.0.0 / uuid 4.6.0 / intl 0.20.3 / logging 1.3.0 / logger 2.8.0 / url_launcher 6.3.3 / crypto 3.0.7 | — | 全 | 官方 | intl 被 SDK 钉版 |
| 16 | 中文字体 | **chinese_font_library + 内置 OFL 字体** | 1.3.0 | 全 | 活跃 | 包体积 |

---

## 1. 状态管理：Riverpod vs Bloc

| 维度 | flutter_riverpod 3.4.3 | flutter_bloc 9.1.1 / bloc 9.2.1 |
|------|------------------------|----------------------------------|
| 平台标签 | android,ios,windows,linux,macos | 全平台 |
| SDK 约束 | `sdk ^3.12.0`, flutter `>=3.0.0` | `sdk >=2.14 <4.0` |
| pub 分数 | 140/160 | 160/160（flutter-favorite） |
| 点赞 / 30日下载 | 2910 / 3.44M | 8082 / 2.03M |
| 发布日期 | 2026-09-03 | flutter_bloc 2025-05-02 / bloc 2026-05-12 |
| 模式 | Provider/Notifier，编译期安全、无需 BuildContext 即可读 | Event/State 单向流，样板多、边界清晰 |

**建议：首选 Riverpod。**
理由：Lifeline 是本地优先（local-first）桌面+移动应用，存在「后台同步/监听触发重编译/DB 流」等**非 UI 上下文异步逻辑**，Riverpod 的 Provider 可在任意 isolate 上下文访问、天然支持依赖注入与 `StreamProvider`（直接对接 drift 的查询流），弱化 `BuildContext` 耦合。Bloc 更重、样板更多，适合事件严格的团队协作，但对单人或小团队桌面工具是负担。
- 备注：Riverpod 3.x 是相对 2.x 的大版本重写，生态迁移仍在收尾，锁定 `^3.4.3` 并全项目统一。可选 `riverpod_generator` 做代码生成（需 build_runner）。
- 备选：`flutter_bloc` 9.1.1（pub 评分满分、官方 flutter-favorite，若团队已熟悉 Bloc 语义可切）。

---

## 2. 路由：go_router

| 项 | 值 |
|----|----|
| 包 | **go_router 18.0.2**（2026-09-28） |
| 平台 | android,ios,windows,linux,macos,web（全） |
| 约束 | **`flutter >=3.44.0`**（与本项目环境精确匹配，见下风险） |
| 评分 | 150/160，flutter-favorite；5787 赞 / 4.46M 30日下载 |
| 备选 | auto_route（社区，代码生成，类型安全更强）；Navigator 2.0 原生（不推荐） |

**理由**：Flutter 官方维护的路由方案，声明式、支持深链、桌面返回键与 URL 语义统一，是当前生态默认推荐。
- ⚠ 风险：18.x 将 `flutter` 下界提到 **3.44.0**。本项目正是 3.44.3，**可用但被绑死**；若未来降级 Flutter 会解析失败。升级前须核对 go_router 与 Flutter 的版本对。
- 备选 `auto_route` 适合大型多级路由，但引入代码生成与额外迁移成本，本项目不必。

---

## 3. 本地 SQLite 数据库：drift（首选）

### 3.1 关键事实（已核实）

> **`sqlite3_flutter_libs` 已 EOL/过时。** 其 pub.dev 页面（版本 `0.6.0+eol`）明示：
> "Not used anymore, update to version 3.x of package:sqlite3 instead … Starting from version 0.6.0, this package no longer does anything."
> drift 官方平台文档亦确认：**"Starting from drift version 2.32.0, all native Dart and Flutter platforms are supported without any further setup or dependencies. Older versions required the use of sqlite3_flutter_libs … no longer necessary."**

`package:sqlite3` 3.x 采用 **Dart build hooks（原 native assets）** 自动编译并随应用打包 SQLite，无需外部构建配置。

### 3.2 方案对比

| 方案 | 版本 | 平台（pub 标签） | 说明 |
|------|------|------------------|------|
| **drift + drift_flutter** | 2.35.1 / 0.3.1 | android,ios,windows,linux,macos,web | **首选**：类型安全 SQL、迁移工具、对流查询（接 Riverpod StreamProvider）、drift_flutter 自动处理平台路径 |
| sqflite | 2.4.4+1 | **android,ios,macos only** | ❌ 桌面不支持，排除 |
| sqflite_common_ffi | 2.4.3 | 全 | 兼容 sqflite API 的 FFI 桌面实现；若坚持 sqflite API 可用，但需自行接线 |
| sqlite3（裸） | 3.7.0 | 全 | 底层 FFI 绑定，drift 依赖它；非类型安全直接写需谨慎 |
| sqlite_async | 0.14.5 | 全 | 高性能异步接口（drift 可经 drift_sqlite_async 桥接），本项目非必要 |

### 3.3 推荐依赖组合

```yaml
dependencies:
  drift: ^2.35.1
  drift_flutter: ^0.3.1
  path_provider: ^2.1.6
dev_dependencies:
  drift_dev: ^2.35.1
  build_runner: ^2.16.1
```

- **不要**再添加 `sqlite3_flutter_libs`；`sqlite3` 3.7.0 由 drift_flutter 传递引入。
- 需要后台线程：`NativeDatabase.createInBackground(File(...))`（drift 文档推荐，避免阻塞 UI isolate）。

### 3.4 代码生成链条现状（Flutter 3.44 生态）

- `build_runner 2.16.1`（2026-09-02）、`drift_dev 2.35.1`（2026-09-30）、`json_serializable 6.14.1`、`freezed 4.0.2`（2026-09-18）**均在活跃维护且兼容当前 SDK**。
- 历史 issue（dart-lang/build#3237）为老 analyzer 0.41 时期问题，**已 closed**，与当前无关。
- ⚠ **最大技术风险：native build hooks 的启用状态。** Dart build hooks 已 GA（dart.dev/tools/hooks，文档对应 Dart 3.13.3，Flutter build-hooks 总 issue #129757 于 2025-11-13 closed）。但**部分 Flutter 版本消费带 build hook 的包时可能仍需一次性开关**：
  ```bash
  flutter config --enable-native-assets   # 若首次构建 SQLite 失败再执行
  ```
  验证动作：在 CI/首建中确认 SQLite 被自动编译并随产物打包；若报缺失原生库，执行上述开关并 clean 重建。
- Linux 预编译库最低 **glibc 2.24**（sqlite3 3.6.0 起），兼容性良好。

---

## 4. YAML 读写（读取 + 程序化编辑写回）

| 包 | 版本 | 用途 | 平台 | 评分 | 说明 |
|----|------|------|------|------|------|
| **yaml** | 3.1.4（2026-08-28） | 解析为 Dart 对象 | 全 | 160/160，16.3M dl/30d | 只读解析 |
| **yaml_edit** | 2.2.4（2026-02-13） | **保注释/格式的增量编辑** | 全 | 160/160，9.3M dl/30d | 官方（dart-lang），写入时保留原始排版 |

**建议**：`yaml` 读取 + `yaml_edit` 写回。两者同属 dart-lang，配合 `path_provider` 定位配置文件，满足「程序化编辑并保留用户注释」需求。
- 备选：若只需简单读写且不在意注释，直接用 `yaml` 的 `loadYaml` + 手写序列化即可（但会丢注释）。

---

## 5. 安全存储（API Key 本地密钥库）

| 项 | 值 |
|----|----|
| 包 | **flutter_secure_storage 11.2.0**（2026-09-16） |
| 平台 | android,ios,windows,linux,macos,web（全） |
| 约束 | `sdk >=3.8 <4.0`, flutter `>=3.19.0` |
| 评分 | 160/160；4495 赞 / 4.78M 30日下载 |
| 机制 | iOS/macOS Keychain；Android 自研 cipher（RSA-OAEP + AES-GCM）；Windows 凭据管理器（wincred）；**Linux 走 libsecret / Secret Service（gnome-keyring / kwallet）** |

**建议**：作为首选，但必须处理 Linux 现实约束。
- ⚠ **Linux 构建依赖**：编译期需 `libsecret-1-dev` + `libjsoncpp-dev`；打包/部署文档需声明。Debian/Ubuntu：`sudo apt install libsecret-1-dev libjsoncpp-dev`。
- ⚠ **Linux 运行时依赖**：必须有可用的 Secret Service 守护进程（gnome-keyring/kwallet）。**无头/最小化发行版、纯 KDE/平铺 WM 无 keyring、或 CI 容器中会失败**（公开 issue #778 报 `libsecret_error`）。
- **降级策略（强烈建议实现）**：捕获 `PlatformException` → 落盘到「应用支持目录下非同步文件（0600 权限）」+ 明确 UI 提示「本机无系统密钥环，密钥以本地受权限保护文件存储，未加密」。可选加壳：用 `cryptography 2.9.0`（2025-11-21，活跃）以机器派生密钥做 AES-GCM 包裹。
- 避免 `encrypt 5.0.3`（2023 年停更）；如要纯 Dart 加密选 `cryptography` 或 `pointycastle`。
- Windows 侧正常（Credential Manager），风险低。

---

## 6. 文件/文件夹选择器（选择同步根目录）

| 包 | 版本 | 平台 | 评分 | 目录选择 | 说明 |
|----|------|------|------|----------|------|
| **file_picker** | 13.1.0（2026-09-15） | 全 | 160/160，4.18M dl/30d | `getDirectoryPath()` 支持桌面 | 单依赖、API 统一 |
| file_selector | 1.1.0（2025-11-21） | 全 | 160/160，665k dl/30d | `getDirectoryPath()`（federated） | Flutter 官方 (flutter.dev)，Linux 走 GTK |

**建议：首选 file_picker**（统一 API，覆盖文件+目录+多选，桌面目录选择可用）。
- ⚠ **Linux 坑**：file_picker 的 Linux 实现**调用外部对话框工具** `zenity` / `qarma` / `kdialog`（三者至少装其一），纯 Qt/最小化环境可能缺失 → 需在部署文档声明或改为 file_selector。
- ⚠ **Windows 坑**：历史上 `getDirectoryPath()` 有「等待选择时 UI 冻结」报告（issue #1478）。上线前在 Windows 实测；如复现，改用 **file_selector**（GTK/Windows 原生对话框）作后备。
- 备选 file_selector 由 flutter.dev 官方维护，桌面原生对话框更稳，但 API 分散、部分桌面特性需按端适配。

---

## 7. 图片选择 / 拍照（导入佐证图片）

| 包 | 版本 | 平台 | 说明 |
|----|------|------|------|
| **image_picker** | 1.2.4（2026-10-06） | 全（桌面**有限**） | 移动端相机+相册；**Windows/Linux 仅为包装** |
| file_picker / file_selector | 见 §6 | 全 | 桌面端选择图片文件 |

**建议：分端策略。**
- **Android**：`image_picker`（`ImageSource.camera` / `.gallery`）。
- **Windows / Linux**：pub.dev 明确「桌面为 limited support」，且 **`ImageSource.camera` 在桌面不支持**（除非自行设置 `cameraDelegate`）。桌面用 `file_picker`/`file_selector` 选图即可满足「导入佐证图片」。
- 若桌面确需摄像头，另接 `camera` 插件（需自行适配桌面），非本项目必要。

---

## 8. 纯 Dart PDF 生成（含 CJK 字体嵌入）

| 包 | 版本 | 平台 | 评分 | 说明 |
|----|------|------|------|------|
| **pdf** | 3.13.1（2026-09-19） | 全 | 160/160，1.63M dl/30d | 纯 Dart 生成，`sdk >=3.12` |
| printing | 5.15.1（2026-09-19） | 全 | 预览/打印/分享 | 配套包 |
| syncfusion_flutter_pdf | 35.1.37 | 全 | 790 赞 | **许可证限制**（社区版有条件），弃用优先 |

**建议：`pdf` + `printing`。**
**CJK 字体嵌入方案**：
1. 捆绑一款 **OFL/开源** 中文字体（推荐 **Noto Sans SC** 或 **Source Han Sans / 思源黑体**，OFL 许可可商用）。
2. 加载与全局主题：
   ```dart
   final cjk = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'));
   final theme = pw.ThemeData.withFont(base: cjk, bold: cjkBold);
   ```
3. `pdf` 包会做**字形子集化**，只嵌入实际用到的字形以控制体积。
- ⚠ 风险：完整 CJK TTF 体积大（思源黑体全量可达 10MB+）。**强烈建议用 fonttools 预子集**成项目实际字表，或用体积较小的 Noto Sans SC；勿用 Courier 等无 CJK 内置字体（issue #850）。
- 备选：`PdfGoogleFonts`（printing）拉取 Google Fonts 的 CJK，但依赖网络，离线应用不推荐。

---

## 9. DOCX 生成 —— ⚠ 本报告唯一「无成熟方案」模块

| 包 | 版本 | 最近发布 | 平台 | 点赞/30日下载 | 评估 |
|----|------|----------|------|---------------|------|
| **docx_creator** | 1.4.0 | 2026-09-30 | 全（纯 Dart） | 12 / 10.9k | 功能最全的现代纯 Dart 生成器（fluent builder、读写、HTML/Markdown→DOCX，MIT）；但**生态极年轻**，GitHub 仓库 **0 star**、发布与仓库提交时间不一致，未经大规模验证 |
| docx_template | 0.4.0 | **2023-09-21** | 全 | 107 / 2.7k | 模板填充思路成熟、被引用多，但**已近 3 年未更新**，Word 新格式/边界未跟进 |
| docx_tmpl | 1.0.0 | 2026-09-09 | 全 | 0 / 105 | 新包，Jinja2 风格模板，零采用 |
| docxtpl | 0.0.1 | 2021 | — | 18 / 25 | ❌ `is:dart3-incompatible`，弃用 |
| nrb | 4.1.4 | 2026-10-02 | 全 | 11 / 598 | 报告/表格生成器（含 Word/Excel/PDF 导出），偏重，非纯 DOCX 库 |
| dart-docx-toolkit（GitHub） | — | — | 全 | — | HTML/Markdown/Quill↔DOCX 双向转换；未见成熟 pub 包形态 |

**结论**：**Dart 生态没有「维护活跃 + 被广泛采用」的 DOCX 生成库**。
- 推荐策略（按序）：
  1. **模板驱动**用 `docx_template 0.4.0`（若需求可被「占位符填充固定 .docx 模板」覆盖，最省心；但接受其停更风险，需自测 Word 打开兼容）。
  2. **程序化构建**用 `docx_creator 1.4.0` 做**试点验证**（POC：生成含中文、表格、图片的 DOCX，用 Word/WPS 打开校验），通过后再纳入。
  3. **兜底**：本应用核心是「导出可读文档」，若 DOCX 非硬需求，优先 PDF（§8，成熟）或 Markdown（§11）导出；DOCX 作为可选能力并明确告知用户「兼容性可能不完全」。
- 若中文 DOCX 是重点，务必验证**中文字体在 Word 端的回退**（通常交给 Word 用系统字体渲染，无需嵌入）。

---

## 10. 文件系统监听（监测外部同步文件夹变化）

| 项 | 值 |
|----|----|
| 包 | **watcher 1.2.1**（2026-01-08，dart-lang 官方） |
| 平台 | android,ios,windows,linux,macos（无 web，本项目不需要） |
| 评分 | 150/160；247 赞 / **12.88M 30日下载** |
| 机制 | `DirectoryWatcher` 递归监听；Linux 用 inotify，Windows 用 ReadDirectoryChangesW，**不支持的场景自动回退到 polling** |

**建议：`watcher` 作为一致 API 首选。**
- 三大平台均受官方支持，是 Flutter/Dart 工具链自用的监听库，可靠性最高。
- ⚠ **核心风险：网络盘 / 云同步盘（SMB、NFS、OneDrive、坚果云、Syncthing 等）不保证产生本地 FS 事件**。若同步根目录位于此类卷：
  - 采用 **polling 策略**（`PollingDirectoryWatcher`）或**事件 + 定时轮询的混合**，对变化做 **debounce** 后再触发重编译。
  - inotify 有 `max_user_watches` 上限（大目录需调 `/proc/sys/fs/inotify/max_user_watches`）。
- 备选 `directory_watcher` 在 pub.dev 已不可用（查询返回 ERR），不采用。
- 结论：**本地磁盘可靠；云同步目录需轮询兜底**——这是设计方案里必须显式处理的点，而非选包能解决。

---

## 11. Markdown 渲染

| 包 | 版本 | 最近发布 | 状态 | 30日下载 | 说明 |
|----|------|----------|------|----------|------|
| flutter_markdown | 0.7.7+1 | 2025-05-06 | ❌ **is:discontinued + is:unlisted** | 156k | **Google 于 2025-04-30 停止维护**，勿用于新项目 |
| **flutter_markdown_plus** | 1.0.12 | 2026-07-10 | 活跃（社区 fork，Foresight Mobile） | **732k** | 原 API 兼容的继任者，迁移成本低 |
| markdown_widget | 2.3.2+8 | 2025-04-26 | 活跃度一般 | 8k | 功能全但下载量低 |
| gpt_markdown | 1.3.1 | 2026-10-04 | 活跃 | 165k | 面向 LLM 流式输出（代码块/表格/LaTeX）优化 |

**建议：`flutter_markdown_plus 1.0.12`**（原包 API 兼容，生态下载量最大，迁移顺滑）。
- 若大量渲染 LLM 输出且需流式/代码高亮，可选 `gpt_markdown`。
- ⚠ 切勿依赖已 discontinued 的 `flutter_markdown`。

---

## 12. HTTP 客户端（接入 OpenAI 兼容 LLM / 图生文 vision）

| 包 | 版本 | 平台 | 评分 | 说明 |
|----|------|------|------|------|
| **dio** | 5.11.1（2026-09-04） | 全 | 160/160，4.68M dl/30d | 拦截器、取消、超时、FormData、流式响应、进度回调 |
| http | 1.6.0（2025-11-10） | 全 | 官方基础库 | 轻量，无拦截器/重试 |

**建议：`dio`。**
理由：对接 OpenAI 兼容接口需要 **Bearer 鉴权拦截器、请求/流式响应、超时与重试、多部分上传（图片 base64/表单）**，dio 原生覆盖；`dio` 的 `ResponseType.stream` 便于处理 SSE 流式回复。
- 注意：SSE 流式解析可搭配 `dio` + 自写续帧解析，或加 `web_socket_channel`（若上游支持 WS）。

---

## 13. 路径与目录

| 包 | 版本 | 平台 | 说明 |
|----|------|------|------|
| **path_provider** | 2.1.6（2026-06-15） | android,ios,windows,linux,macos | flutter-favorite；应用文档/支持/临时目录的标准获取方式 |
| **path** | 1.9.1（2024-10-17） | 全 | Flutter SDK 通常已钉版；跨平台路径拼接/规范化，**勿手动拼 `\`/`/`** |

**建议**：二者配合。SQLite 库文件、配置、导出目录统一走 `path_provider` + `path.join`，避免桌面端路径分隔符差异。

---

## 14. 桌面窗口管理

| 包 | 版本 | 平台 | 评分 | 说明 |
|----|------|------|------|------|
| **window_manager** | 0.5.2（2026-07-04） | windows,linux,macos | 160/160，739k dl/30d | 窗口尺寸/最小尺寸/居中/置顶/标题栏/关闭拦截 |
| window_size | — | 桌面 | — | 记忆窗口尺寸/位置的轻量方案 |
| bitsdojo_window | 较旧 | 桌面 | — | 自定义标题栏 |

**建议：`window_manager 0.5.2`。**
理由：活跃、平台标签精确对应桌面三端，支持设置最小尺寸、屏幕居中、关闭时确认（适合「有未保存资料」的提示）。注意它**不支持 Android**（移动端无窗口概念），需按 `Platform` 条件调用。
- 备选 `window_size` 用于持久化窗口几何尺寸（与 window_manager 可共存）。

---

## 15. 工具集（CSV/JSON/UUID/i18n/日志/URL/哈希）

| 包 | 版本 | 用途 | 评分/下载 | 备注 |
|----|------|------|-----------|------|
| csv | 8.0.0（2026-03-19） | CSV 导入导出 | 150/160，787k | JSON 用内置 `dart:convert` |
| uuid | 4.6.0（2026-07-15） | 生成稳定 ID | 160/160，15.3M | v4/v7 |
| intl | 0.20.3（2026-06-25） | 格式化/复数/日期 | 160/160，11.4M | ⚠ 见下 |
| flutter_localizations | SDK | 本地化 | — | 与 ARB + `flutter gen-l10n` 配合 |
| logging | 1.3.0（2024-10-17） | 结构化日志（dart-lang） | 160/160，10.9M | 轻量、可控等级/输出 |
| logger | 2.8.0（2026-09-05） | 带颜色/美化控制台日志 | 150/160，2.9M | 开发期友好 |
| url_launcher | 6.3.3（2026-10-02） | 打开外链/系统应用 | 160/160，7.06M | flutter-favorite |
| crypto | 3.0.7（2025-11-04） | 文件哈希（SHA-256） | 160/160，12.5M | 大文件配 `AccumulatorSink` 流式哈希 |

**建议**：`csv` + `dart:convert`（JSON）；`uuid ^4.6.0`；日志用 `logging`（应用内结构化落盘）+ 可选 `logger`（仅 debug 控制台）；`url_launcher`；文件哈希用 `crypto`（**流式读取 + SHA-256**，避免大文件一次性读入内存，同时可作为「文件是否变更」的判定依据，与 §10 监听互补）。

⚠ **intl 版本钉版风险**：`flutter_localizations` 会**按 Flutter 版本精确钉死 intl 版本**（本环境 3.44.x 对应 intl 0.20.x）。若其它包对 intl 有更严格约束，会解析冲突。**对策**：优先使用 Flutter 内置 `flutter gen-l10n`（ARB）方案，`intl` 依赖写 `any` 或与 SDK 匹配的版本，**不要手动升级 intl 到超出 SDK 钉版的版本**。备选本地化方案 `slang` / `easy_localization` 可绕开 intl 钉版，但引入新范式。

---

## 16. 中文字体打包方案（体积权衡）

| 方案 | 说明 | 体积 | 评价 |
|------|------|------|------|
| **内置 OFL 字体 + 子集化** | 捆绑 Noto Sans SC / 思源黑体，用 fonttools `pyftsubset` 仅保留项目用字 | 全量 5–10MB+ → 子集后数十 KB–数百 KB | **推荐**：离线稳定、体积可控、许可清晰 |
| chinese_font_library 1.3.0（2026-08-18） | 跨平台中文字体族回退辅助（UI 渲染） | 极小 | 作为**字体族回退**的编排层，配合内置字体用 |
| google_fonts 9.0.0 | 运行时拉取 Google Fonts | 0（但需网络） | ❌ 离线应用的 UI 会闪烁/失败；不适宜作主方案 |
| DroidSansFallback | Android 系统常见回退字体 | ~4.5MB | 可作为 Android 回退，跨桌面不一致 |
| 依赖系统字体 | Windows 微软雅黑 / Linux Noto | 0 | 体积最省但**跨平台渲染不一致**，桌面 Linux 可能缺字 |

**建议**：UI 侧内置一款**子集化 OFL 中文字体**（统一三端渲染），并用 `chinese_font_library` 管理平台字体族回退；**PDF 生成复用同一字体文件**（§8）。字体与许可（OFL）放入 `assets/fonts/` 并在 `pubspec.yaml` 声明、随包附带 LICENSE。
- 权衡：子集化需要维护「用字表」；若产品文案会迭代，可保留一份全量字体在构建期做子集，而非提交全量到仓库。

---

## 17. 风险清单（按严重度）

1. **【高】DOCX 无成熟方案**：`docx_creator` 极新（0 star）、`docx_template` 停更 3 年。需 POC 验证或降级为 PDF/Markdown 导出（§9）。
2. **【高】drift/sqlite3 native build hooks**：sqlite3 3.x 靠 build hooks 自动编译打包。多数情况开箱即用，但个别 Flutter 版本需 `flutter config --enable-native-assets`；CI 首建必须验证产物含 SQLite 原生库（§3.4）。
3. **【高】flutter_secure_storage 的 Linux 现实性**：编译需 `libsecret-1-dev`+`libjsoncpp-dev`，运行时需 gnome-keyring/kwallet。无头/最小系统会失败 → 必须实现「本地受权限文件」降级与 UI 提示（§5）。
4. **【中】文件系统监听 × 云同步目录**：watcher 本地可靠，但 SMB/云同步盘事件不可靠，需 polling 兜底 + debounce（§10）。
5. **【中】file_picker 桌面坑**：Linux 依赖 zenity/qarma/kdialog 外部对话框；Windows 目录选择有历史冻结报告 → 备 file_selector（§6）。
6. **【中】flutter_markdown 已 discontinued**：必须改用 `flutter_markdown_plus`，否则后续无安全/兼容更新（§11）。
7. **【低】go_router 强绑 Flutter≥3.44**、**intl 被 SDK 钉版**：版本升级时需协同核对（§2、§15）。
8. **【低】image_picker 桌面无原生相机**：桌面改用文件选择；移动端保留相机（§7）。

---

## 18. 与「无成熟方案」有关的模块汇总

- **DOCX 生成**：无「活跃维护 + 广泛采用」的 Dart 包。仅 `docx_template`（停更）/`docx_creator`（新）两弱选项，或改用 PDF/Markdown。
- **跨云同步盘的可靠 FS 监听**：`watcher` 本身成熟，但「云同步目录下 100% 可靠的变更通知」在三大平台均无保证，须以轮询兜底（属方案层缺口，非选包问题）。

---

## 19. 建议的 pubspec 骨架（供后续实现参考）

```yaml
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"

dependencies:
  flutter: { sdk: flutter }
  flutter_localizations: { sdk: flutter }
  flutter_riverpod: ^3.4.3
  go_router: ^18.0.2
  drift: ^2.35.1
  drift_flutter: ^0.3.1
  path_provider: ^2.1.6
  path: ^1.9.1
  yaml: ^3.1.4
  yaml_edit: ^2.2.4
  flutter_secure_storage: ^11.2.0
  file_picker: ^13.1.0
  image_picker: ^1.2.4
  pdf: ^3.13.1
  printing: ^5.15.1
  docx_creator: ^1.4.0        # 或 docx_template: ^0.4.0（见 §9，务必 POC）
  watcher: ^1.2.1
  flutter_markdown_plus: ^1.0.12
  dio: ^5.11.1
  window_manager: ^0.5.2
  csv: ^8.0.0
  uuid: ^4.6.0
  intl: any                   # 由 flutter_localizations 钉版
  logging: ^1.3.0
  url_launcher: ^6.3.3
  crypto: ^3.0.7
  chinese_font_library: ^1.3.0

dev_dependencies:
  flutter_test: { sdk: flutter }
  flutter_lints: ^6.0.0
  build_runner: ^2.16.1
  drift_dev: ^2.35.1
  json_serializable: ^6.14.1
  freezed: ^4.0.2
```

---

## 20. 核实方法与来源

- 结构化数据：`https://pub.dev/api/packages/<pkg>`（最新版本、发布日期、pubspec 约束）、`https://pub.dev/api/packages/<pkg>/score`（平台标签 `platform:*`、维护标记 `is:discontinued`/`is:flutter-favorite`、点赞、30 日下载、评分）。
- 官方文档：`https://drift.simonbinder.eu/setup/`、`https://drift.simonbinder.eu/platforms/vm/`、`https://dart.dev/tools/hooks`、`https://pub.dev/packages/sqlite3`、`https://pub.dev/packages/sqlite3_flutter_libs`、`https://pub.dev/packages/flutter_secure_storage`、`https://pub.dev/packages/watcher`。
- GitHub API：flutter/flutter#129757（build hooks 总 issue，closed 2025-11-13）、dart-lang/build#3237（closed，老问题）、docx_creator 仓库元数据。
- 搜索：web-research-routing 技能（SearXNG 多引擎 + 防注入）。
- 关键判定依据：**sqlite3_flutter_libs 官方声明「不再使用/0.6.0 起不做任何事」**；**flutter_markdown 标记 discontinued**；**sqflite 平台标签不含 windows/linux**；**go_router 18 要求 Flutter≥3.44.0**。

---

*修改日志：2026-10-06 初版：全模块选型 + 版本核实 + 风险与无成熟方案标注。*
