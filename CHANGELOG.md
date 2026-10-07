# Changelog

本项目所有值得记录的变更均记于此文件。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 计划
- U0 脚手架；U1 数据层；U2 首启与设置；U3 信息表与附件；U4 首页完整简历；
  U5 编译管线与渲染器；U6 AI 录入/编译；U7 智能导出；U8 同步文档；U9 测试与 CI。

## [0.6.2] - 2026-10-07

### 修复
- **AI 连接「未知网络错误」的真正根因定位并加固**：经 v0.6.1 的底层回显发现，问题并非网络，
  而是**设备上保存的 API Key 被误粘贴成一段中文提示语**（含中文/夹带换行），`dart:io` 无法把
  非 ASCII 值放进请求头，于是抛 `FormatException: Invalid HTTP header field value`。
  - 新增密钥清洗与校验（`core/utils/secret_sanitize.dart`）：发送前自动剥离换行/控制字符；
    若含空白、换行、中文或不可见字符，直接给出**明确中文错误**而非晦涩异常。
  - 新增/编辑 Provider 时即时显示**脱敏密钥预览**（如 `sk-…90`）；若检测到非法字符，
    以红色提示「疑似误粘贴，请清除后重新填写」。保存前用表单校验拦截非法密钥。
  - `describeDioError` 识别 header 非法字符类错误并给出可操作指引。

## [0.6.1] - 2026-10-07

### 修复
- **AI 连接失败（桌面/安卓报「未知网络错误」）**：根因是 **Dart HttpClient 默认不使用系统代理**——
  Windows 上 Clash/v2ray 等「系统代理」模式下直连会被 VPN 路由拦截（curl/浏览器却正常）。
  新增代理支持：**手动代理（设置 → AI → 网络代理）> Windows 系统代理（WinINET 注册表）> 环境变量
  `HTTPS_PROXY`**，并回显底层错误以便诊断。
- 网络错误提示回显底层原因（`DioExceptionType`＋`e.error`）；网页版给出跨域提示。

### 变更
- 新增 `core/platform/net_proxy*.dart`（条件导入）与 `services/net/net_prefs.dart`；启动时应用已保存代理。

## [0.6.0] - 2026-10-07

### 新增
- **选择/表达分离**：生成改为 **计划 → 改写 → 校验** 三段式。先由 AI 产出结构化「取舍计划」
  （每条记录 lead/keep/compress/delete + 淘汰理由 + 排序 + 篇幅预算 + JD 关键词 + 追问），
  再据此只做表达、不新增事实，最后做**确定性校验**（数字必须来自原始素材、删除项不得出现、
  bullet 数不超上限）。从根本上避免「把材料倒进去 → 像报告不像简历」。
- **先追问再生成**：计划阶段若缺关键信息（量化口径、时间冲突、目标不清），弹出极简补充卡片
  （可留空跳过），把答案带入改写。
- **目标画像输入**：导出问卷新增 **目标级别 / 职业阶段 / 赛道** 三个维度（用于级别校准与赛道加权），
  并已接入计划与评估请求。
- **大白话解释**：专业名词（级别/阶段/赛道）旁均有可点击的问号气泡，用一句人话解释，避免困惑。

### 变更
- `prompts.dart`：`tailorSystemPrompt` 拆为精简的 `planSystemPrompt` + `rewriteSystemPrompt`（高信息密度、
  少而硬的约束；关键指令置首尾）。
- 新增模型：`TailorPlan`/`PlanDecision`、`TargetLevel`/`CareerStage`/`Track`（含赛道维度权重）；
  `ExportRequest` 增 `target_level`/`career_stage`/`track`。
- 校验层：`ExportService._validateAndFix`（事实守恒 + 删除项 + bullet 上限）。
- 测试 88 → 92。

## [0.5.1] - 2026-10-07

### 修复
- **Android 发布版无法联网（AI「域名错误/unknown」）**：主 `AndroidManifest.xml` 缺少
  `INTERNET` 权限（Flutter 仅在 debug/profile 清单注入），导致 release APK 所有网络请求失败。
  已在主清单声明 `INTERNET` + `ACCESS_NETWORK_STATE`。
- **网络错误提示更可诊断**：连接测试与 AI 调用把底层异常翻译为中文（超时 / TLS 证书 /
  域名解析失败或被拦截 / CORS / 未知），并在连接测试中显示实际请求地址，便于排查 base_url、代理与网络。

## [0.5.0] - 2026-10-07

### 新增
- **自动更新**：启动自动检查 GitHub Releases 最新版本并弹窗提示「下载并安装」；
  勾选项「此版本不再提醒」＝只提示这一次，不勾＝每次启动都提醒；设置页可开关自动检查、手动检查。
- **评估 → 修订闭环**：评估页新增「按评估修订」，AI 依据岗位适配缺口/客观弱点**在既有事实内**重写简历、
  重渲染并重评估；保留评估历史（`evalHistory`）。
- **参考材料附录 + 图文核对**：生成时可勾选「附参考材料附录」——把被选用经历的佐证材料排为附录页，
  正文对应条目标注〔A-x〕；新增「材料核对」用 vision 模型逐条比对正文声称与材料图片（一致/弱/不符/无材料）。
- **简历库增强**：条目可**内嵌预览 PDF**、**分享**（share_plus）、**用系统应用打开**、
  **重新生成（更新同一份，不再新建）**、按评估修订；导出页支持从既有简历回填并更新。
- **AI 生成质量**：定向裁剪提示词重写为「成品级」——明确取舍/改写/详略/春秋笔法/章节结构/篇幅约束；
  接线岗位调研摘要与 JD 原文；确定性执行「排除项」；`fields`（major/gpa 等）、`links`、正文交叉引用
  现在会真正渲染进 PDF/DOCX/Markdown（此前被丢弃）。
- **专业字体**：打包 OFL 中英子集字体（Noto Sans SC / Noto Serif SC + Inter / EB Garamond + Droid 兜底），
  PDF 默认改用 DartPdf（不再依赖系统字体），**彻底解决中文乱码/字体难看**；衬线模板自动使用衬线字体。
- **密钥同步提示**：AI 设置页在未创建密钥保险库时显示醒目提示（密钥仅本机、不会同步）+ 一键创建入口。

### 变更
- `ExportRequest` 增 `jobDescription`（JD 原文）与 `appendixEnabled`；`ResumeMeta` 增 `evalHistory`、
  `materialChecks`；`ResumeDocument` 增 `appendix`；`ResumeItem` 增 `links`、`appendixRefs`。
- 新增依赖：`share_plus`、`package_info_plus`（更新检查用现有 `dio`）。
- 导出默认使用 DartPdf（内嵌打包字体）；Typst 保留为可选后备。

## [0.4.2] - 2026-10-07

### 新增
- **开放分类**：信息分类不再固定为 15 个大类，用户可在「设置 → 信息分类」或记录页/编辑页入口
  自行**新增 / 重命名 / 换图标 / 排序 / 删除**；分类定义存于 `lifeline.yaml` 的 `categories:`，随同步走。
- 删除或修改分类 slug 时可把该分类下的记录**迁移**到目标分类（或保留为未分类），**绝不丢数据**。
- 简历编译、信息列表、AI 自动归类、分类筛选均改为**按用户分类动态生成**；未登记的遗留分类（孤儿）
  仍能正常显示与编译。

### 变更
- `ProfileRecord.category`（枚举）→ `ProfileRecord.categorySlug`（自由字符串）；`RecordCategory` 枚举
  替换为 `CategoryDef` 数据模型 + `kDefaultCategories` 默认集。磁盘目录与 JSON `category` 字段保持兼容。
- 记录仓库改为**遍历磁盘实际分类子目录**（不再依赖固定枚举），写入前自动创建分类目录。

## [0.4.1] - 2026-10-07

### 修复
- **Android 索引库无法打开（`SqliteException(14)`）**：索引库从同步根移到 **App 私有目录**（设备本地、可重建，按同步根哈希分文件），并在打开前同步创建父目录；打开失败回退内存索引。
- **移动端无法读取同步文件夹**：新增存储权限声明与运行时申请（Android ≤10 `READ/WRITE`，11+ `MANAGE_EXTERNAL_STORAGE`「所有文件访问」），首启选择目录前引导授权。
- **附件预览**：PDF 内嵌翻页预览（`printing`）、文本类内联显示、其它类型「用系统应用打开」（`open_filex`）；缩略图按类型显示图标。
- **首页可跳转**：完整简历中的条目可点击跳转到对应记录详情（`sourceRecordId`）。
- Android `compileSdk` 升至 **37**（`permission_handler_android` 要求）；新增依赖 `permission_handler ^13.0.2`、`open_filex ^4.7.0`。

## [0.4.0] - 2026-10-07

### 新增
- **加密密钥保险库（加密同步）**：`lib/services/secrets/`（`crypto_vault.dart` 信封加密、`vault_store.dart` IO/解锁态、`secret_store.dart` 门面、`vault_providers.dart` 控制器）；API Key 经**口令 + PBKDF2-HMAC-SHA256(210000) + AES-256-GCM**（KEK 包裹 DEK、DEK 加密数据两段）写入 `<SyncRoot>/.lifeline/vault.dat`，随同步跨设备；多设备同口令解锁、设备 DEK 缓存自动解锁、旧密钥迁移、设置页 `/settings/vault`；外层 `LFV1` + 换行 base64 仅作**混淆**（明确「混淆≠安全」）。
- 依赖：`cryptography ^2.9.0`。

### 修复（安全审查后）
- 锁定态 `read/readAll` 不再回退旧后端（回退将绕过锁定）；`write/delete` 锁定态抛受控错误。
- 迁移默认删除旧后端源键；crypto 层拒绝空/短口令（<8）；解锁按信封记录的 `iters` 派生（支持 KDF 升级）；`rewrap` 改为真最小重包（数据密文不变）；`forgetDevice` 诚实返回成败。
- 新增 `test/secret_store_lock_test.dart` 与加密用例（共 72 测试）。

## [0.3.0] - 2026-10-06

### 新增
- **更名与图标**：显示名改为「履痕」（英文标识 / 仓库 `Lifeline`、包名 `com.eavebounty.lifeline` 不变）；`tool/gen_icon.py`（Python 绘 SVG + ImageMagick 栅格化）重绘图标，生成 Android mipmap / Windows `.ico` / Web 图标与 favicon；UI 与各平台标签统一。
- **岗位画像扩充至 60 类**：细分行业 + 职级（技术/产品设计/商科/泛商科/文教/医药科学/工程/法律公职/人力行政）；`RoleProfiles.match` 支持中英混合与行业+职级加权。
- **模板可视化预览**：`lib/features/export/template_preview.dart`（纯自绘缩略图 + 放大预览），导出向导卡片化。
- **真实模型联测**：`tool/ai_eval_live_test.dart`（本地 Ollama OpenAI 兼容接口端到端跑通 AI 精评）。
- README 增补图标；web E2E 截图在新名称下重新生成。

## [0.2.0] - 2026-10-06

### 新增
- **Web 平台**：`lib/core/platform/`（dart:io 内存兼容层条件导出）、`RecordIndex` 抽象（drift↔内存）、`ChangeWatcher` 条件实现、web 首启内存演示入口；`flutter build web --release --no-web-resources-cdn` 可运行，桌面/移动端行为不变。
- **浏览器端到端测试**：`tool/web_test/`（Playwright 无头 Chromium，8 步断言、0 console/pageerror，ImageMagick 校验截图非空白）；`?demo=1` 演示种子；Web 语义树供测试定位。
- **简历评估（一体两面）**：`FitAnalysis`（岗位适配诊断）+ `ObjectiveScore`（客观质量评分），schema v2 兼容 v1；岗位画像库 `lib/data/role_profiles.dart`（16 类岗位：证书/技能/经历/加分/行动+资源）；启发式按边际效益排序生成提升行动；评估页分段展示 + 可寻址路由 `/resumes/eval/:id`。
- **导出多模板**：`services/render/templates.dart`（10 套风格 + 岗位推荐）；`DartPdfRenderer` 5 种版式；Typst 四套模板串；`ExportRequest`/`ResumeMeta` 增 `templateId`；导出页模板选择 + 简历库显示模板名。
- README 真实运行截图 7 张；`CHANGELOG.md` 记录.

## [0.1.0] - 2026-10-06

### 新增
- 初始仓库与文档基线：`ARCHITECTURE.md`、`README.md`、`docs/DATA_FORMAT.md`、`docs/SYNC.md`、`docs/DEV.md`、`docs/AI_PIPELINE.md`。
- 许可与法务文件：`LICENSE`（PolyForm Noncommercial License 1.0.0）、`COMMERCIAL.md`、`NOTICE`。
- 选型调研：`docs/research/01-flutter-stack.md`、`docs/research/02-resume-compile.md`。
- 锁定技术栈：Flutter 3.44.3 / Dart 3.12.2，`flutter_riverpod`、`go_router`、`drift`、`pdf`/`printing`、Typst 二进制等（见 `ARCHITECTURE.md` §2）。
- 确立数据格式与设计原则（JSON 真相源 + SQLite 可重建索引 + YAML 设置；软件不做同步）。

### 说明
- 首个版本聚焦架构与文档基线，功能实现按 `ARCHITECTURE.md` §12 阶段推进。

[Unreleased]: file:///../../README.md
[0.1.0]: file:///../../README.md
