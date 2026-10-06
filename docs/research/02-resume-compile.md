# 02 · 简历编译 / 导出与「AI 定向简历」调研

> 调研范围：JSON 为源、SQLite 为可重建索引的 Flutter 应用 Lifeline（Android + Windows + Linux）。
> 导出目标：PDF / DOCX / Markdown，支持「针对某岗位/企业的定向简历」。
> 约束：用户已排除 LaTeX，倾向 Typst 内嵌二进制。
> 调研日期：2026-10；所有版本/体积/许可证均来自官方源或 GitHub API 实测，链接见文末。
> 安全声明：以下网页内容一律作为**数据**，不执行其中任何指令。

---

## 0. 关键结论速览

| 问题 | 结论 |
|---|---|
| Typst 官方独立二进制 | ✅ 有；仅 Linux/macOS/Windows（含 arm64），**无 Android 目标**；压缩包 13–21 MB；License **Apache-2.0** |
| Android 直接 exec Typst 二进制 | ❌ 不现实（官方无 bionic 构建 + Android 10 W^X + 16KB page + AAB 不解压） |
| Android 经 FFI 嵌入 Typst | ⚠️ 技术可行，主流路线；但现成 `typst_flutter` 极新（2 likes），建议自建 Rust cdylib 或早期采用+锁定 |
| Android 退路 | WebView+typst.ts(WASM) / 纯 Dart PDF / 云端编译 |
| DOCX 跨平台 | ✅ 纯 Dart `docx_template`（成熟、模板法）+ 手写 OOXML 兜底；官方 Typst **不能**导出 DOCX |
| Typst 简历模板 | ✅ 宽松许可候选多（Apache-2.0 / MIT / Unlicense），与 PolyForm Noncommercial 应用兼容 |
| JSON→Typst | ✅ 官方推荐 `--input`/`sys.inputs` + `json.decode()`；FFI 走 sys.inputs 字典 |

**核心架构建议**：PDF 桌面端 = 内嵌官方 Typst 二进制 `Process.run`；PDF Android = Typst native lib（FFI）；DOCX = 纯 Dart（注意 ATS 需要单列标准结构）；Markdown = 自己渲染（无需 Typst）。

---

## 1. Typst 独立二进制（Windows / Linux / Android）

**版本**：最新 **v0.15.1（2026-07-17）**。仓库 `github.com/typst/typst`（56.4k★）。
**许可证**：**Apache-2.0**（编译器本体；字体另计，见风险）。
**分发**：官方 releases 页面提供预编译归档：

| 目标平台 | 资产 | 体积（压缩包） |
|---|---|---|
| Windows x64 | `typst-x86_64-pc-windows-msvc.zip` | 21.42 MB |
| Windows arm64 | `typst-aarch64-pc-windows-msvc.zip` | 20.26 MB |
| Linux x64 (musl) | `typst-x86_64-unknown-linux-musl.tar.xz` | 16.65 MB |
| Linux arm64 (musl) | `typst-aarch64-unknown-linux-musl.tar.xz` | 15.47 MB |
| Linux armv7 (musleabi) | `typst-armv7-unknown-linux-musleabi.tar.xz` | 15.49 MB |
| Linux riscv64 (gnu) | `typst-riscv64gc-unknown-linux-gnu.tar.xz` | 16.32 MB |
| macOS arm64 / x64 | `*-apple-darwin.tar.xz` | 13.77 / 14.91 MB |

> 说明：以上是**归档压缩体积**，解压后单一可执行文件较大（数十 MB）。Typst 自更新：`typst update`；Windows 另有 `winget`、Linux 有发行版仓库、macOS 有 Homebrew。

**Android**：官方 releases **没有** `android` / `aarch64-linux-android` 目标。唯一相近的 `armv7-unknown-linux-musleabi` 是 **musl libc**（面向 Linux），Android 用 **bionic**，且 ELF interpreter 指向 `/system/bin/linker64` 而非 musl/glibc 的 `ld-*.so`——**不能直接在 Android 运行**（详见 §2）。

**Windows/Linux 桌面端结论**：可直接内嵌对应平台官方二进制，用 `dart:io Process.run` 调 `typst compile`，稳定、零编译，推荐作为桌面 PDF 主链路。

---

## 2. Android 运行 Typst 的可行性（关键风险）

Android 的内核策略（Android 10+ W^X，禁止可写页同时可执行、禁止从 data 目录 chmod 后 exec 第三方二进制）使「下载/打包一个可执行文件再 exec」变得脆弱甚至不可行。分三条路线评估：

### (a) 二进制改名 `.so` 放 `jniLibs/` 后 exec（hack）
社区（tyolab 2026-07 实战贴）总结三大陷阱：
1. **ELF interpreter 不匹配**：必须用 `GOOS=android`（NDK 外部链接）构建，interpreter 才会指向 `/system/bin/linker64`；用 `linux` 目标会报 `ENOENT`（"No such file or directory"，即便文件存在）。
2. **16 KB page 对齐**：Android 15/16（如 Galaxy S25）将页大小从 4 KB 提到 16 KB，二进制需按 16 KB（建议 64 KB）对齐；Google Play 上传时强制检查 `.so` 对齐。Rust/NDK 需用 **NDK r27+ / Rust ≥1.77** 产出 16 KB 对齐的 `.so`。
3. **AAB 不一定把 `.so` 解压到磁盘**：现代 AAB 可能只在内存映射，导致无文件可 exec。可行 hack 是 `memfd_create`（**API 30 / Android 11+**）把二进制作为匿名内存 fd，再 exec `/proc/self/fd/<n>`，并设 `useLegacyPackaging=true`；API 26–29 需回退到 `codeCacheDir`+chmod（SELinux 可能仍拦截）。

**评价**：hack 可行但**极脆弱**（版本碎片、厂商 SELinux、Play 政策、未来封堵）。而且**官方 Typst 二进制不是 Android 构建**，必须自行交叉编译 Rust → 本质等价于路线 (b)。**不推荐。**

### (b) Typst 作为 native library 经 FFI（推荐路线）
- **现成方案 `typst_flutter` v3.0.0（2026-09-14，Apache-2.0）**：`pub.dev/packages/typst_flutter`，`github.com/ajmalbuv/typst_flutter`。将 Typst 引擎以 Rust FFI 原生嵌入，支持 **Android/iOS/macOS/Windows/Linux**，无需 WebView/服务器；支持 `sys.inputs` 字典、虚拟文件系统、Flutter assets、`@preview` 包自动下载、`query()` 提取 JSON、实时预览组件。
  - 预编译原生库体积（实测 GitHub Release v3.0.0）：**Android arm64 28.5 MB / armv7 21.7 MB / x64 33.4 MB / x86 33.2 MB**；Linux x64 33.3 MB；Windows x64 26.8 MB；iOS 55.4 MB；macOS 152 MB。**AAB 按 ABI 拆分后 arm64 场景约 +28 MB**。
  - **采用风险很高**：仓库仅 **1★/0 fork**，pub.dev **2 likes、119 次下载/30 天**（2026-10 数据），发布历史从 v2.0.0(2026-05) 起算，属极新个人项目。生产使用需**锁版本 + 自建 fork + 冒烟测试**，并准备随时自行维护。
- **自建 cdylib（更可控）**：用 `typst-as-lib`（MIT，126★）或 `typst-cffi`，配 **cargo-ndk + Android NDK r27+** 编出 `libtypst_android.so`（确保 16 KB 对齐），Dart 侧 `dart:ffi` 调用，输入经 `sys.inputs` 传 JSON。工作量大但可控、许可清晰。
- **C API 生态**：`libtypst`（WangHaoZhengMing）提供 C-FFI 桥，但仅 **1★、无 License 文件**，不成熟；`typst-as-lib`（MIT）声明「easily use typst from rust」，常被 `typst-bake` 等使用，是自建方案的较优底座。

### (c) 退路方案
1. **WebView + typst.ts (WASM)**：`github.com/Myriad-Dreamin/typst.ts`（**Apache-2.0，1228★，活跃**）把 Typst 编译到 WASM，浏览器内可直接产出 PDF（离线可用）。Android 通过隐藏 WebView 运行 JS+WASM，Dart↔JS 传 JSON，产出 PDF 字节回传。缺点：包体大、WASM 大文件/多页 PDF 内存吃紧、桥接复杂、首次加载慢。
2. **纯 Dart PDF**：`pdf` 3.13.1（**纯 Dart，跨平台**，排版能力基础）或 `syncfusion_flutter_pdf` 35.1.37（能力强，**商业许可**，社区版有条件）。牺牲 Typst 排版质量，但与首页 Flutter 原生渲染可共享布局数据。
3. **云端编译**：服务端跑 Typst（官方二进制，见 §1）暴露 API，客户端上传 JSON 拿 PDF。最简单可靠，但违背「离线优先」，需处理隐私（简历含个人信息）与网络依赖。

**Android 结论**：
- 直接 exec 官方 Typst 二进制 → **不可行/不推荐**。
- 现实可行 = **FFI 原生嵌入**。短期可用 `typst_flutter` 快速验证（接受其不成熟风险）；长期生产建议 **自建 `typst-as-lib` + NDK 的 cdylib**。
- 若不能接受 +28 MB 包体与 Rust 构建链，退路优先级：**WebView+typst.ts(WASM) > 纯 Dart PDF > 云端**。注意：Typst **不生成 DOCX**，DOCX 始终需独立链路（§3）。
- 额外风险：Typst 需字体，**中文需自带 CJK 字体**（Noto Sans/Serif CJK，单字重可达 8–20 MB），显著影响包体；FFI/WASM 方案都需提供字体数据接口。

---

## 3. DOCX 生成（跨平台，尤其 Android）

Typst 只输出 PDF/PNG/SVG/HTML（v0.15 起有实验性 bundle/html），**不支持 DOCX**。DOCX 必须另走链路。Dart 选项实测：

| 方案 | 最新版 | 维护/热度 | 许可 | 能力 | 跨平台 | 评价 |
|---|---|---|---|---|---|---|
| **`docx_template`** | 0.4.0 (2023-09) | 107 likes，2.7k dl/月 | MIT* | 模板引擎：以 Word content-control 占位符填充（循环/表格等） | 纯 Dart，全平台 | 成熟且久经使用，但**发布较旧**；适合「设计 Word 模板 + 数据回填」 |
| `docs_gee` | 1.5.0 (2026-08) | 37 likes，24.9k dl/月，160/160 | 见仓库 | 纯 Dart 生成/读取 DOCX 与 PDF，富文本/表格/列表 | 纯 Dart，全平台 | 较新、下载量高，仓库 `erykkruk/docs_gee`；需审代码/许可 |
| `docx_creator` | 1.4.0 (2026-09) | 12 likes，10.9k dl/月 | 见仓库 | 纯 Dart 创建/读取/转换，HTML/MD 导入导出，PDF 导出 | 纯 Dart，全平台 | 很新，API 较全，采用需谨慎验证 |
| `docx_mailmerge` | 2.0.0 (2024-11) | 7 likes | MIT* | 在 DOCX merge field 上做邮件合并 | 纯 Dart | 场景偏窄 |
| **手写 OOXML 模板替换** | — | — | 自研 | DOCX = ZIP(OOXML XML)；用 Dart `archive` 解包→替换 `word/document.xml` 占位符→重打包 | 纯 Dart，全平台 | **零依赖、完全可控、可最小化**；缺点：需自行处理 XML 转义与格式片段 |
| `officecli`（本机技能/CLI） | — | — | 依工具 | 建/读/改/校验 docx/xlsx/pptx | 桌面 CLI | **Android 无法运行外部 CLI**；仅 Windows/Linux 桌面边车可用 |
| 服务端 `python-docx` 边车 | — | — | BSD | 服务端生成 DOCX | 需服务端 | 违背离线；仅作云端备选 |

**DOCX 结论**：
1. **首选 `docx_template`**（内容控件模板法）：先做一份设计好的 Word 模板，运行时用 JSON 数据填充；`docx_template` 在纯 Dart 全平台可用，Android 亦可运行。缺点：需 Word/LO 制作模板、库较旧（注意测试 Dart 3 兼容）。
2. **若需完全程序化 + 无模板**：优先 **手写 OOXML**（`archive` 包 + XML 模板字符串，或基于 `docs_gee`/`docx_creator` 二次开发）。对「结构固定的简历」而言，手写 `document.xml` 片段最稳、包体最小、无第三方风险。
3. **桌面端**可选 `officecli`/LibreOffice headless 做格式校验，但**不要成为核心依赖**。
4. **ATS 兼容提醒**：无论哪种，DOCX 必须 **单列、标准标题（Work Experience/Education）、无表格/文本框/图形/页眉栏**，否则 ATS 解析会丢内容（见 §5）。Typst 生成的精美多列 PDF 直接转 DOCX 会破坏可解析性——建议 **DOCX 用独立、朴素的模板**，而非从 Typst 排版反向导出。

---

## 4. Typst 简历模板候选

筛选标准：**宽松许可（MIT/Apache-2.0/Unlicense/CC0）**，与主程序 **PolyForm Noncommercial 1.0.0** 兼容（can embed/redistribute，只需保留版权声明）；**排除 GPL/AGPL**（会传染、且与 PolyForm 不兼容）。

| 模板 | 链接 | 许可 | 热度 | 特点 |
|---|---|---|---|---|
| **brilliant-CV** | `github.com/yunanwg/brilliant-CV` | **Apache-2.0** | 844★ | 功能最全；多语言/模块化；`@preview` 可直接引用；适合工程化嵌入 |
| **modern-cv** | `github.com/ptsouchlos/modern-cv` | **MIT** | 627★ | 受 Awesome-CV 启发的现代排版；YAML 数据；结构清晰易改 |
| **imprecv** | `github.com/jskherman/imprecv` | **Apache-2.0** | 514★ | 无花哨、YAML 版本控制友好；数据驱动，适合 JSON/YAML 注入 |
| **basic-typst-resume-template** | `github.com/stuxf/basic-typst-resume-template` | **Unlicense** | 246★ | **明确面向 ATS**；极简单列，解析友好 |
| **vantage-typst** | `github.com/sardorml/vantage-typst` | **MIT** | 93★ | 简洁、ATS 友好，易裁剪 |
| neat-cv | `github.com/dialvarezs/neat-cv` | MIT | 77★ | 现代优雅，Awesome CV 风格 |
| modern-typst-resume | `github.com/peterpf/modern-typst-resume` | Unlicense | 68★ | 现代简洁 |

**不推荐内嵌**（许可冲突）：`wusyong/resume.typ`（**AGPL-3.0**）、`elegaanz/vercanard`（**GPL-3.0**）。
`NorthSecond/Auto_Typst_Resume_Template`（NOASSERTION，需人工核验）、`fky2015/resume-ng-typst`（MIT，高信息密度）可作备选。

**推荐 3 个**：**brilliant-CV（Apache-2.0，功能全）**、**modern-cv（MIT，排版好）**、**basic-typst-resume-template（Unlicense，ATS 单列）**。
实施提示：模板需支持「从统一数据结构注入」——优先选 YAML/JSON 数据驱动的 `imprecv`、`modern-cv`，改造成读 `sys.inputs`（§6）。

---

## 5. 定向简历方法论（用于写 AI 提示词）

### 5.1 ATS 关键词优化（最高优先级）
- **从 JD 出发，而非旧简历**：提取岗位标题 + 硬技能 + 工具名，原样落入 headline 与经历正文。
- **措辞对齐**：JD 用「Kubernetes」就不要写「K8s 集群管理」——用 JD 的确切术语；同义可并置。
- **格式硬规则**：**单列布局**；标准章节标题（Work Experience / Education / Skills）；**禁用表格、文本框、图形、多栏、页眉页脚放关键信息**；导出 `.docx` 或**文本型 PDF**，不要扫描图/图片 PDF。
- **量化匹配率**：对照具体 JD 自检遗漏关键词后补齐（Jobscan 类思路）。
- **2025 数据**：据 Jobscan《State of the Job Search 2025》，~99.7% 招聘方在 ATS 使用关键词过滤——关键词是硬门槛。

### 5.2 页数与地区惯例
- **美国**：严格，早期职业 **1 页**；丰富经验最多 2 页；联邦/学术例外更长。
- **英国/欧洲**：通常 2 页可接受（英式 CV）。
- **德国**：偏好 **tabular Lebenslauf**（含照片/日期/签名），结构固定。
- **学术 CV**：不限页数，含发表/项目/教学。
- **中国/东亚**：中文简历 1–2 页，常含政治面貌/照片/年龄等本地字段（与欧美差异大，**应做地区模板切换**）。
- 应用侧建议：**按「职位所在地区」选择模板与页数策略**，作为定向参数之一。

### 5.3 成果写法（STAR / XYZ）
- **STAR**（Situation-Task-Action-Result）：简历不写全 4 段，而是**压缩为单条 bullet**——以动作开头、以结果收尾。
- **XYZ（Google 公式）**：「通过 [Z] 达成 [X]，并以 [Y] 度量」；动词 + 指标。
- **量化原则**：每类成就尽量带数字（%、金额、规模、周期、排名）；无硬数字时用范围/相对量（如「Top 5%」「从 0 到 1」）。
- **反模式**：删「负责/参与/协助」等弱动词；删无结果描述；每条 bullet ≤2 行。

### 5.4 定向裁剪策略（AI 提示词要覆盖）
1. **JD 解析** → 抽取：必备技能、加分技能、职责动词、行业术语、公司价值观/产品关键词。
2. **证据映射**：把候选人真实经历映射到最相关 3–5 条，**重排优先级**（相关在前），弱相关压缩或省略。
3. **术语替换**：将经历改写成 JD 术语 + 量化结果，**不得编造事实**（合规红线）。
4. **信息架构（优先级）**：联系信息 → 一句话定位/headline（对齐岗位）→ 核心技能（对齐 JD 关键词）→ 经历（倒序、相关优先）→ 项目 → 教育 → 证书。
5. **输出两版**：① 给人看的 Typst 精美 PDF；② 给 ATS 看的**朴素单列 DOCX**。二者共享同一 JSON 源、不同模板。
6. **可追溯**：AI 只做「选取/改写/排序」，所有生成内容须能回指到源 JSON 字段，便于用户审校与撤回。

### 5.5 常见简历结构（可作 JSON schema 参考）
`Contact` · `Headline/Target` · `Summary`（可选）· `Skills`（分类）· `Experience[]`（role/company/dates/bullets[]）· `Projects[]` · `Education[]` · `Certifications/Awards` · `Languages` · `Links`。

---

## 6. JSON → Typst 数据传递模式

Typst 官方机制：`sys.inputs` 把命令行 `--input key=value` 暴露为字符串字典；复杂数据用 `json` 解析。

**官方 CLI 模式（桌面）**
```bash
typst compile --input data=@data.json resume.typ out.pdf   # 或 --input data='{"name":...}'
```
```typst
// resume.typ
#let data = json.decode(sys.inputs.at("data"))
// 或（Typst 的 json() 支持从文件读）
#let data = json("data.json")
= #{data.name}
#for job in data.experience [ ... ]
```
> 注意：`sys.inputs` 的 value **永远是字符串**，复杂结构需 `json.decode(...)`；命令行含空格需引号包裹。

**FFI / typst_flutter 模式**：`typst_flutter` 直接接受 `sys.inputs` 字典与虚拟文件系统（可用 raw bytes / Flutter assets），把 JSON 作为 input 或虚拟 `.json` 文件注入，模板侧同样 `json.decode`。这避免了命令行长度/转义问题，是移动端推荐做法。

**三种注入策略对比**：
1. **`sys.inputs` + `json.decode`**（推荐）：数据与模板解耦，最干净；适合运行时数据。
2. **`json("data.json")` + 虚拟 FS**：需要把 JSON 作为文件写入虚拟 FS；适合大对象与复用。
3. **代码生成 `.typ` 前奏**（`#let resume = (json literal)`）：把 JSON 转成 Typst 原生值字面量拼进 `.typ`；类型安全、无需 decode，但需自己做转义与 Typst 值映射（字符串/数组/字典/`datetime`）。适合「编译期固定 schema」的批量导出。

**推荐**：
- 统一在 Dart 侧定义 **ResumeDocument** 数据模型 → 序列化为 JSON → 经 `sys.inputs`（或虚拟 FS）注入 Typst。
- 模板只做「展示」，业务逻辑（定向裁剪）在 Dart/AI 层完成；模板内用 `#let d = json.decode(sys.inputs.resume)` 统一取值，杜绝模板内硬编码。
- **中文注意**：需为 Typst 提供 CJK 字体并设置 `#set text(font: "Noto Sans CJK SC")`（或 `font-fallback`）；字体数据随应用打包，注意包体。
- **页数控制**：在 Dart 侧按目标页数裁剪内容，再把「已裁剪数据」喂模板，避免 Typst 侧复杂自适应。

---

## 7. 综合推荐方案

| 目标格式 | Windows/Linux 桌面 | Android | 说明 |
|---|---|---|---|
| **PDF（精美）** | 内嵌官方 Typst v0.15.1 二进制，`Process.run` | `typst_flutter`（短期）/ 自建 `typst-as-lib` cdylib（长期） | 共享同一 `.typ` 模板 + `sys.inputs` JSON |
| **PDF（退路）** | 纯 Dart `pdf` 包 | WebView+typst.ts(WASM) 或 纯 Dart `pdf` | 云编译为最后手段 |
| **DOCX（ATS）** | `docx_template`（模板法）或手写 OOXML | 同左（纯 Dart） | **独立朴素单列模板**；不由 Typst 反向转换 |
| **Markdown** | Dart 直接渲染（无需 Typst） | 同左 | 与 JSON 模型一一映射，最简单 |

**统一数据流**：`SQLite(索引) ← JSON(源)` → `ResumeDocument` 模型 →（AI 定向裁剪）→ 同一 JSON → { Typst 模板→PDF, DOCX 模板→DOCX, MD 渲染器→MD }。

---

## 8. 风险清单（Top）

1. **Android Typst 无官方二进制、exec hack 脆弱**：官方无 bionic 目标，Android 10+ W^X + 16KB page + AAB 不解压三座大山；只能走 FFI（+~28 MB/ABI）或 WASM/纯 Dart/云端退路。
2. **`typst_flutter` 过于年轻**：1★/0 fork、2 likes、119 dl/30d（2026-10）；生产需锁版本、自建 fork、备好自维护或切换到自建 cdylib。
3. **包体与字体**：Typst native 库 20–33 MB + CJK 字体 8–20 MB；需 ABI 拆分 + 字体子集化，否则 Android APK/AAB 显著膨胀。
4. **DOCX 与 ATS 的排版冲突**：Typst 多列精美 PDF 满足 ATS 需另出朴素单列 DOCX；两者必须共享数据但独立模板。
5. **模板许可传染**：严禁嵌入 GPL/AGPL 模板（如 wusyong/AGPL、vercanard/GPL）；只用 MIT/Apache-2.0/Unlicense，并保留版权声明。
6. **Typst 版本兼容**：模板 `@preview` 包与 Typst 0.15.x 可能有破坏性变更；内嵌编译器版本需与模板锁定。
7. **许可证合规**：主程序 PolyForm Noncommercial 1.0.0 与 Apache-2.0/MIT 内嵌兼容；但需在「关于/许可」页列出 Typst(Apache-2.0)、字体(OFL) 与各模板许可与版权。

---

## 9. 参考来源（均为实测/官方）

- Typst 仓库与 releases（v0.15.1，Apache-2.0）：https://github.com/typst/typst 、 https://github.com/typst/typst/releases
- Typst 安装/开源页：https://typst.app/open-source
- Typst `sys.inputs` 文档：https://typst.app/docs/reference/foundations/sys/
- typst_flutter（v3.0.0，Apache-2.0）：https://github.com/ajmalbuv/typst_flutter 、 https://pub.dev/packages/typst_flutter
- typst.ts（Apache-2.0，1228★）：https://github.com/Myriad-Dreamin/typst.ts
- typst-as-lib（MIT）：https://crates.io/crates/typst-as-lib ；typst-cffi：https://lib.rs/crates/typst-cffi
- Android 原生二进制打包三陷阱（tyolab，2026-07）：https://tyolab.com/blog/2026/07/25-shipping-a-native-go-binary-inside-an-android-apk-elf-linkers-16-kb-pages-and-the-memfd-trick
- Android 16KB page size（React Native 0.77 说明）：https://reactnative.dev/blog/2025/01/21/version-0.77
- Dart DOCX/PDF 包：https://pub.dev/packages/docx_template 、 https://pub.dev/packages/docs_gee 、 https://pub.dev/packages/docx_creator 、 https://pub.dev/packages/docx_mailmerge 、 https://pub.dev/packages/pdf 、 https://pub.dev/packages/syncfusion_flutter_pdf
- Typst 简历模板：https://github.com/yunanwg/brilliant-CV 、 https://github.com/ptsouchlos/modern-cv 、 https://github.com/jskherman/imprecv 、 https://github.com/stuxf/basic-typst-resume-template 、 https://github.com/sardorml/vantage-typst
- ATS 简历方法论：https://www.jobscan.co/blog/ats-resume/
- 简历页数地区惯例：https://thetailorcv.com/blog/ats-resume-length-guide 、 https://resumly.ai/blog/how-long-should-a-resume-be
- STAR/量化：https://airesume.guru/blog/star-method-resume-bullets

---

_修改日志_
- 2026-10-06 初版：完成 6 项调研（Typst 二进制 / Android 可行性 / DOCX / 模板 / 定向方法论 / JSON→Typst），含版本·体积·许可证实测与风险退路。
