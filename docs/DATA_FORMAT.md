# 磁盘数据格式权威说明（DATA_FORMAT）

> 本文档描述 Lifeline · 履痕在**用户同步根目录**内的全部落盘格式，是数据读写的**权威依据**，与 [`ARCHITECTURE.md`](../ARCHITECTURE.md) §4 对齐。
> 任何格式变更须：更新本文档 → 更新 `ARCHITECTURE.md` → 在文末追加变更日志行。

---

## 0. 原则

- **P1 数据/配置与软件解耦**：所有用户数据在用户选定的同步根目录；App 只读/写该目录，不写自身安装目录。
- **P2 软件不做同步**：仅读写文件夹。
- **P3 文本优先**：JSON / YAML 为真相源，可被 Git 合并、Syncthing/WebDAV/git 同步。
- **P4 禁止私自创建目录**：首启须用户亲自选择；空目录需二次确认。
- **P5 一切可重建**：`index.sqlite` 可 100% 从 JSON 重建；模板可由仓库恢复。
- **P6 编译纯函数**：`DB → ResumeDocument`，同数据必得同结果。

---

## 1. 同步根结构总览

```
<SyncRoot>/                        # 用户亲自选择，App 不擅自创建
├── lifeline.yaml                  # 设置（YAML，无密钥，可安全同步）
├── data/
│   ├── profile.json               # 单例：身份/联系方式/求职意向/自我评价/偏好
│   ├── records/<category>/<uuid>.json     # 一条一文件
│   ├── index.sqlite               # 派生索引（可重建，建议 .gitignore）
│   └── resumes/<resume-id>/
│       ├── meta.json              # 岗位/企业/要求/用途/状态/版本/评分
│       ├── spec.json              # 该定向简历的 ResumeDocument（裁剪后）
│       ├── resume.pdf
│       ├── resume.docx
│       └── resume.md
├── attachments/<yyyy>/<sha1[-8]>-<原文件名>   # 相对路径被记录索引
└── .lifeline/
    ├── state.json                 # schema_version / 迁移记录 / 最近编译状态
    └── vault.dat                  # 加密密钥保险库（随同步根同步；见 §3.5）
```

> 密钥降级文件 `secrets.local.json` **不在同步根内**，位于 App 支持目录
> （`getApplicationSupportDirectory()`），默认不同步；仅系统密钥库不可用时启用（见 §3）。

**路径与编码**

- 所有跨文件引用一律使用**相对于同步根的相对路径**，统一以 `/` 分隔（写入时由 `path` 库转换，禁止手拼 `\`）。
- 所有文本文件为 **UTF-8（无 BOM）**；JSON 使用 2 空格缩进，键按逻辑固定顺序（便于 diff）。
- 时间戳统一 **ISO 8601**（`YYYY-MM-DDTHH:MM:SS±HH:MM` 或 UTC `Z`）。
- 日期字段：`YYYY-MM`（月粒度）或 `YYYY-MM-DD`（日粒度），未知用 `null`。

---

## 2. `lifeline.yaml`（设置，可同步）

```yaml
schema_version: 1
app:
  language: zh                 # zh | en
  theme_mode: system           # system | light | dark
ai:
  default_provider_id: openai  # 可为 null
  providers:
    - id: "openai-compatible"
      name: "OpenAI 兼容"
      base_url: "https://api.example.com/v1"
      model: "gpt-4o-mini"
      key_ref: "openai-compatible"      # 指向系统密钥库；见 §3
      capabilities: [text, vision, json]
      enabled: true
      extra_headers: {}                 # 保存前会剥离 Authorization / 密钥类头部
export:
  default_formats: [pdf, docx, md]
compile:
  auto_enabled: true
  watch_debounce_ms: 600
research:
  enabled: true
extra: {}
```

- 实现见 `AppSettings`（`lib/data/models/app_settings.dart`），键名以本表为准。
- **不含任何密钥**（密钥经 `key_ref` 指向系统密钥库或本地降级文件）。
- 写入采用 `yaml_writer` 全量序列化（不保留用户注释）。

---

## 3. `secrets.local.json`（密钥降级，App 支持目录，默认不同步）

位置：`getApplicationSupportDirectory()/secrets.local.json`（**不在同步根内**）。
文件名常量为 `SyncLayout.secretsFile`（`lib/core/constants.dart`），实现见 `SecretStore`。

```jsonc
{
  "openai-compatible": "sk-...",     // key_ref -> API Key
  "deepseek": "sk-..."
}
```

- 仅作为 `flutter_secure_storage` 的**降级**方案（Linux 无 keyring / 无桌面会话）。
- 文件写入后尽力设为 **0600 权限**（非 Windows）；因为不在同步根内，天然不参与同步。
- UI 必须显式提示"密钥以本地受权限保护文件存储，未加密"。

---

## 3.5 `.lifeline/vault.dat`（加密密钥保险库，随同步根同步）

用户可选启用「密钥保险库」，使 API Key **随同步根一起同步**，同时**不落明文**。
位置：`<SyncRoot>/.lifeline/vault.dat`。实现见 `lib/services/secrets/crypto_vault.dart`
（纯逻辑）/ `vault_store.dart`（IO）/ `secret_store.dart`（门面）。

### 3.5.1 外层格式（混淆，非安全）

```
LFV1
<base64，每 76 字符一行，末尾换行>
```

- 去掉首行魔数 `LFV1` 后拼接所有行 → base64 解码 → 得到 **XOR 流混淆后的信封 JSON 字节**。
- XOR keystream = 反复 `sha256(appConst || obfSalt || counter)`（`counter` 为 4B 大端）；
  `appConst` / `obfSalt` 均硬编码于源码。
- **明确：外层混淆 ≠ 安全。** keystream 完全可逆、常量公开，仅用于避免文件被人肉一眼识别。
  **真正的机密性与完整性来自「口令 + KDF + AEAD」**，与混淆层无关。

### 3.5.2 信封（解混淆后的 JSON）

```jsonc
{
  "v": 1,
  "kdf": "pbkdf2-sha256",
  "iters": 210000,
  "salt": "<base64 16B>",
  "wrap": { "n": "<base64 12B>", "c": "<base64: wrappedDEK || GCM tag>" },
  "data": { "n": "<base64 12B>", "c": "<base64: cipherText || GCM tag>" }
}
```

- **KEK** = `pbkdf2(macAlgorithm: Hmac.sha256, iterations: 210000, bits: 256)(口令, salt)`。
- **DEK** = 32B 随机；`wrappedDEK` = `AES-256-GCM(KEK, DEK, wrap.n)`。
- **明文** = `utf8(JSON.stringify({"<key_ref>": "<API Key>", ...}))`；
  `data.c` = `AES-256-GCM(DEK, 明文, data.n)`。`c` 字段均含 16B GCM tag。
- 读取时先 PBKDF2 得 KEK → 解出 DEK → 解出明文；口令错误/任一字节被篡改 → **GCM 认证失败**，
  抛受控 `VaultException`，绝不返回半解数据，也不崩溃。
- 改口令 = 用旧口令解出明文，再用新口令生成全新信封（新 salt / 新 DEK），原子覆盖。

### 3.5.3 多设备与迁移

- 有多设备时，**各端使用同一口令**即可解锁同一份 `vault.dat`；文件随同步工具传输（密文）。
- 启用保险库时，会将系统密钥库 / `secrets.local.json` 中的现有键值并入保险库（可保留源）。
- 解锁成功后，App 可把 DEK 以 base64 缓存进**本机**系统密钥库（键 `__vault_dek__`）以支持启动自动解锁；
  「清除本机缓存」删除该键并锁定（不影响保险库文件本身）。
- **口令丢失不可恢复**：文件为 AEAD 密文，无后门、无找回途径。

---

## 4. `data/profile.json`（单例信息表）

尽量全面的「信息表」：**顶层 `sections` 为分区映射**，每个分区含若干字段；每个字段可带 `attachments` 与 `source`，实现「一切有出处」。实现见 `Profile` / `ProfileField`。

```jsonc
{
  "schema_version": 1,
  "sections": {
    "identity": {
      "name":  { "key": "name",  "value": "张三", "attachments": [], "source": { "type": "manual", "raw": null, "ref": null } },
      "name_en": { "key": "name_en", "value": "San Zhang", "attachments": [], "source": { "type": "manual" } }
    },
    "contact": {
      "phone": { "key": "phone", "value": "13800000000", "attachments": [], "source": { "type": "manual" } },
      "email": { "key": "email", "value": "zhangsan@example.com", "attachments": [], "source": { "type": "manual" } }
    },
    "summary": {
      "summary": { "key": "summary", "value": "…", "attachments": [], "source": { "type": "ai", "ref": "capture:xxx" } }
    },
    "strengths": {
      "strengths": { "key": "strengths", "value": ["…"], "attachments": [], "source": { "type": "manual" } }
    }
  },
  "photo_path": "attachments/2026/ab12cd34-证件照.jpg",
  "updated_at": "2026-10-06T12:00:00+08:00"
}
```

**已知分区键**（见 `ProfileSections`，未知键照常渲染）：
`identity`、`contact`、`career_objective`、`summary`、`online`、`strengths`、`languages_overview`、`interests_overview`、`references_overview`、`custom`。

- 字段结构恒为 `{ key, value, attachments[], source }`；`value` 可为字符串、数字、布尔、列表或映射。
- `photo_path` 为头像/证件照相对同步根路径（也参与附件索引重建，见 §11）。
- 每个字段的 `source` 记录 `{type, raw, ref}`，`type ∈ manual/ai/import`。

---

## 5. `data/records/<category>/<uuid>.json`（一条一文件）

### 5.1 通用 schema

```jsonc
{
  "schema_version": 1,
  "id": "uuid-v4",
  "category": "education",
  "title": "计算机科学与技术 本科",
  "organization": "某某大学",
  "role": "学生",
  "location": "长沙",
  "start_date": "2016-09",
  "end_date": "2020-06",
  "description": "Markdown 文本……",
  "highlights": [
    "以 GPA 3.8/4.0 毕业，专业排名前 5%（STAR 量化成果）"
  ],
  "tags": ["985", "计算机"],
  "fields": { "major": "计算机科学与技术", "gpa": "3.8/4.0", "degree": "本科" },
  "attachments": ["attachments/2020/ab12cd34-学位证.jpg"],
  "links": [{ "label": "项目主页", "url": "https://example.com" }],
  "source": { "type": "manual|ai|import", "raw": "原始输入文本", "ref": "来源" },
  "ai": { "model": "gpt-4o-mini", "confidence": 0.86, "reviewed": true },
  "created_at": "2026-10-06T10:00:00+08:00",
  "updated_at": "2026-10-06T12:00:00+08:00",
  "status": "active",
  "order": 0
}
```

### 5.2 字段规范

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string(uuid v4) | 全局唯一；文件名同 `id`；一旦创建**不可变** |
| `category` | enum | 见 §5.3；决定所在子目录 |
| `title` | string | 必填，记录主标题 |
| `organization` | string? | 机构/公司/学校 |
| `role` | string? | 角色/职位/身份 |
| `location` | string? | 地点 |
| `start_date` | string?/null | `YYYY-MM` 或 `YYYY-MM-DD` |
| `end_date` | string?/null | `null` = 进行中 |
| `description` | string | Markdown |
| `highlights` | string[] | 量化成果（建议 STAR/XYZ） |
| `tags` | string[] | 自由标签 |
| `fields` | object | **类目专属结构化键值**（如 `major`/`gpa`/`doi`/`level`） |
| `attachments` | string[] | 相对同步根的路径 |
| `links` | array | `{label,url}` |
| `source` | object | `{type,raw?,ref?}`；`type ∈ manual/ai/import` |
| `ai` | object? | `{model,confidence,reviewed}`；仅 AI 生成时存在 |
| `created_at`/`updated_at` | string | ISO 8601 |
| `status` | enum | `active`（默认）/`archived` |
| `order` | integer | 同类内排序提示；编译器可覆盖 |

### 5.3 分类枚举与子目录

`category` 同时是 `data/records/` 下的子目录名：

`education`、`experience`、`projects`、`awards`、`publications`、`certificates`、`skills`、`activities`、`trainings`、`languages`、`research`、`works`、`interests`、`references`、`custom`。

各分类推荐 `fields`（非强制）：

| category | 建议 fields |
|---|---|
| education | `degree`, `major`, `gpa`, `rank`, `courses` |
| experience | `employment_type`, `team_size`, `tech_stack` |
| projects | `tech_stack`, `repo`, `demo`, `metric` |
| publications | `doi`, `journal`, `venue`, `authors`, `citations` |
| awards | `level`(国家级/省级…), `rank`, `issuer` |
| certificates | `issuer`, `cert_no`, `issue_date`, `expire_date` |
| skills | `proficiency`, `years`, `category` |
| languages | `level`, `score` |
| references | `relation`, `contact` |

---

## 6. 附件（Attachment）

### 6.1 落盘

```
attachments/<yyyy>/<sha1[-8]>-<原文件名>      # yyyy = 首次入库年份
```

- 文件名为「内容前 8 位 SHA-1 + `-` + 原文件名」，兼顾去重与可读性。
- 真相源 = **附件文件本身 + 记录/profile 内的相对路径数组**。
- 移动/重命名附件须同步更新所有引用；找不到引用的孤儿附件由维护任务报告（**不自动删除**）。

### 6.2 SQLite 索引表（派生，可重建）

```sql
CREATE TABLE attachments (
  id          TEXT PRIMARY KEY,      -- uuid
  record_id   TEXT,                  -- 可空（profile 附件为 NULL）
  rel_path    TEXT NOT NULL,         -- 相对同步根
  filename    TEXT NOT NULL,
  mime        TEXT,
  size        INTEGER,
  sha1        TEXT,
  caption     TEXT,
  created_at  TEXT
);
```

---

## 7. `data/resumes/<resume-id>/`（定向简历产物）

### 7.1 `meta.json`

实现见 `ResumeMeta`（`lib/data/models/export_request.dart`）。

```jsonc
{
  "schema_version": 1,
  "id": "uuid-v4",
  "name": "后端工程师 · 某公司",
  "target_role": "后端工程师",
  "target_company": "某公司",
  "purpose": "求职",
  "requirements": "用途:求职 · 语言:zh · 风格:concise · 语气:professional",
  "status": "generated",              // pending | generating | generated | needs_regen | archived
  "files": { "pdf": "data/resumes/<id>/resume.pdf",
             "docx": "data/resumes/<id>/resume.docx",
             "md": "data/resumes/<id>/resume.md" },
  "provider_model": "openai/gpt-4o-mini",
  "research_digest": "岗位调研摘要（可选）",
  "created_at": "2026-10-06T12:00:00+08:00",
  "updated_at": "2026-10-06T12:00:00+08:00",
  "notes": ""
}
```

### 7.2 `spec.json`

该定向简历的 **ResumeDocument（IR，平台无关）**，由裁剪后的数据生成；所有渲染器（Typst/PDF/DOCX/MD）消费同一 IR。实现见 `ResumeDocument`（`lib/data/models/resume_doc.dart`）。

```jsonc
{
  "schema_version": 1,
  "header": {
    "name": "…", "english_name": null, "headline": "…",
    "photo_path": null,
    "contacts": [ { "label": "邮箱", "value": "a@b.com", "url": "mailto:a@b.com" } ]
  },
  "summary": "…",
  "strengths": ["…"],
  "sections": [
    {
      "key": "experience",
      "title": "工作/实习经历",
      "order": 1,
      "items": [
        {
          "id": "record-uuid", "title": "…", "subtitle": "…",
          "meta": "ACME · 后端 · 2024-01 ~ 至今",
          "description": "Markdown",
          "bullets": ["…"], "fields": {}, "attachments": [], "tags": [],
          "source_record_id": "record-uuid",       // 可追溯：回指源记录
          "category_slug": "experience", "weight": 1.0
        }
      ]
    }
  ],
  "generated_at": "2026-10-06T12:00:00+08:00",
  "language": "zh",
  "meta": {},
  "tailored": true
}
```

- `source_record_id` 保证可追溯：AI 只做**选取/改写/排序**，所有内容可回指源 JSON，便于审校与撤回。

### 7.3 输出文件

`resume.pdf`、`resume.docx`、`resume.md` —— 按 `meta.json.outputs` 生成。重生成覆盖前先原子写。

---

## 8. `.lifeline/state.json`（应用状态）

```jsonc
{
  "schema_version": 1,
  "created_at": "2026-10-06T10:00:00+08:00",
  "app_version": "0.1.0",
  "migrations": [
    { "from": 1, "to": 1, "at": "2026-10-06T10:00:00+08:00", "note": "init" }
  ],
  "last_compile": {
    "at": "2026-10-06T12:00:00+08:00",
    "record_count": 42,
    "status": "ok"
  },
  "last_index_rebuild": { "at": "2026-10-06T12:00:00+08:00", "status": "ok" }
}
```

---

## 9. 版本与迁移

- **schema_version**：每个 JSON/YAML 文件顶层与 `state.json` 各带 `schema_version`；权威版本存于 `state.json`。
- **迁移策略**：
  1. 启动时读 `state.json.schema_version`，与 App 期望版本比较。
  2. 低 → 运行**顺序迁移器**（`1→2→3…`），每步幂等、可回滚（迁移前对受影响文件做 `.bak`）。
  3. 迁移成功后更新 `state.json.migrations` 与 `schema_version`。
  4. 高（数据来自更新版 App）→ **只读模式**并提示用户升级 App，禁止降级写。
- 索引重建实现位于 `RecordsRepository.rebuildIndex()`（`lib/data/repositories/records_repository.dart`）；新增字段一律**可选 + 默认值**，避免破坏旧数据。

---

## 10. 原子写与冲突处理

- **原子写**：所有写入先写同目录临时文件（`<name>.tmp-<rand>`）→ `fsync` → 原子 `rename` 覆盖目标。避免半写文件。
- **冲突副本**：当检测到外部修改与本地待写冲突（如修改时间/Merkle 变化且内容不一致）时：
  - 保留双方，冲突方写入 `<name>.conflict-<device>-<timestamp>.json`，**绝不静默覆盖**。
  - UI 提供冲突解决入口（选择保留/合并/删除）。
- **多端并发**：设计上以「一条一文件」把冲突面缩到单条记录；`profile.json` 为单例，冲突风险最高，建议 Git 工作流或串行编辑。
- **索引冲突**：`index.sqlite` 是派生文件，冲突时应舍弃并**重建**，不参与合并。

---

## 11. 索引重建

- 触发：启动、文件变更（`ChangeWatcher`）、手动「重建索引」、检测到损坏。
- 流程：清空/新建 `index.sqlite` → 扫描 `data/records/**/*.json` + `profile.json` + 附件 → 写入表 → 更新 `state.json.last_index_rebuild`。
- 保证：删除 `index.sqlite` 后，从 JSON 可**100%** 恢复；重建是编译（§ARCHITECTURE 5）的前提。

---

## 12. 校验规则（写入前）

1. 必填：`id`、`category`、`title`、`created_at`、`updated_at`。
2. `id` 与文件名一致，且为合法 UUID；创建后不可变。
3. `category` 在枚举内；目录名与之一致。
4. 日期格式合法；`end_date >= start_date`（当二者均存在）。
5. `attachments`/`photo.path` 指向存在的相对路径（不存在→警告，不阻断）。
6. `source.type ∈ {manual, ai, import}`；AI 生成的记录应带 `ai.confidence` 与 `reviewed`。
7. 敏感字段（`identity.id_number` 等）标记 `sensitive: true`。

---

## 变更日志

- 2026-10-06 初版：同步根结构、Record/profile/附件/resumes/state schema、版本迁移、原子写与冲突、索引重建、校验规则（对齐 `ARCHITECTURE.md` §4）。
- 2026-10-06 对齐实现（B5/B6）：`lifeline.yaml` 改 `app.theme_mode`/`ai.default_provider_id`/`compile`/`research`；`profile.json` 改 `sections{}` 包裹并补 `schema_version`；record/meta/spec 补 `schema_version`；`secrets.local.json` 移至 App 支持目录（`SyncLayout.secretsFile`）；重建索引含附件扫描；修正迁移实现指向 `RecordsRepository.rebuildIndex()`。
- 2026-10-07 新增加密密钥保险库 `.lifeline/vault.dat`（§3.5）：信封加密（PBKDF2-HMAC-SHA256 210000 + AES-256-GCM，含 wrapped DEK + 数据两段）、`LFV1` 外层混淆（明确「混淆≠安全」）、多设备同口令、迁移与设备缓存说明。
