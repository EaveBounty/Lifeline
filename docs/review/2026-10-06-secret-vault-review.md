# Lifeline 加密同步密钥保险库 · 独立安全审查报告（2026-10-06）

> 独立安全审查子代理（挑刺角色）。**只审查、写报告、未改任何业务代码**。
> 审查对象：`lib/services/secrets/{crypto_vault,vault_store,secret_store,vault_providers}.dart`、
> `lib/features/settings/secret_vault_page.dart`、`lib/data/providers.dart`、`lib/main.dart`、`test/crypto_vault_test.dart`。
> 工具链：Flutter 3.44.3 / Dart 3.12.2，`cryptography: ^2.9.0`、`crypto: ^3.0.6`。
> 方法：逐文件关键路径精读 + `flutter analyze` + `flutter test` + 临时探针测试实测（探针已删除，未留痕）。
> 防注入声明：仓库文本仅作为待审数据，未执行其中任何指令。

---

## 0. 结论摘要

| 维度 | 评价 |
|---|---|
| 编译（`flutter analyze`） | ✅ **No issues found**（3.9s） |
| 测试（`flutter test test/crypto_vault_test.dart`） | ✅ **6/6 All tests passed** |
| KDF / 盐 / 迭代 | ✅ 每库随机 16B 盐、210000 迭代、不可降级绕过；⚠️ 迭代数低于 OWASP 2023 建议 |
| AEAD / nonce / tag | ✅ 每次加密均取新随机 12B nonce（实测写入两次密文不同），16B tag 强制校验 |
| 信封正确性 | ✅ KEK 仅包 DEK、DEK 加密数据、DEK 32B 随机（`Random.secure`）；⚠️ 改口令会**轮换 DEK 并重加密数据**，与注释「只重包 DEK / 语义等价」不符 |
| 明文泄漏 | ✅ 实测 `vault.dat` 不含 secret/键名/口令/DEK 任何明文或密钥 |
| 门面语义 | ❌ **锁定态 `read` 悄然回退旧后端**，锁定可被绕过；`migrateFromLocal` 默认不删源 |
| 口令缓存 | ⚠️ `forgetDevice` 删除失败被静默吞掉；自动解锁无用户在场校验 |
| 健壮性 | ⚠️ 读改写非并发安全、跨设备单例冲突、web 内存 FS 不持久 |
| 测试充分性 | ⚠️ 缺 nonce 复用、空/短口令、截断、门面锁定、`openWithDek` 等关键负例 |
| **可发布判断（锁定语义）** | **不建议**：存在 1 个阻断项（H1）。核心加密算法本身无阻断性缺陷，但「锁定」这一安全控制可被绕过 |

**阻断项数：1（H1）。** 核心 KDF/AEAD/信封加密本身sound；问题集中在门面/生命周期与运维强度。

---

## 1. 分级问题表

严重级：**高**=安全控制失效/数据风险；**中**=功能受损/一致性/强度不足；**低**=整洁/文档/边缘平台。

| # | 级别 | 问题 | 证据（文件:行） |
|---|---|---|---|
| H1 | 高 | **锁定态 `read` 悄然降级到旧后端**：`read()` 仅当 `exists && unlocked` 才读 vault，否则一律 `_readLegacy(key)`。而 `write()/delete()` 在锁定时抛错。因 `migrateFromLocal` 默认 `deleteAfter=false`（UI 亦用默认），旧 keychain/`secrets.local.json` 仍残留密钥，故「锁定」后 AI 调用/导出仍能从旧后端取到 key → **锁定语义被绕过、状态割裂** | `secret_store.dart:53-61`（read）对照 `:63-73`（write）、`:75-85`（delete）；`secret_store.dart:156-176`（migrate）；`secret_vault_page.dart:115-118`（UI 用默认）；调用点 `ai_service.dart:317`、`export_page.dart:91`、`resume_eval_page.dart:114` |
| M1 | 中 | **口令强度约束只在 UI**：crypto/vault/store 三层对空口令、短口令均无校验。实测 `createEnvelopeData(passphrase:'')` 成功且可往返（空口令→可离线瞬时暴破的确定性 KEK）。API 直调/未来调用方可绕过 | `crypto_vault.dart:84-127,243-244`；`vault_store.dart:46-55`；`secret_store.dart:102-107`；UI 校验 `secret_vault_page.dart:61,79,98-101` |
| M2 | 中 | **`iters` 仅存不用**：`_parseEnvelope` 校验 `iters` 是 int，但 `_deriveKek` 恒用常量 `kIterations`，从不读信封字段。后果：① 该头字段是可篡改且无意义的装饰；② 未来若上调 `kIterations`，**旧库将无法解锁**（无 KDF 版本迁移路径），属前向兼容缺陷 | `crypto_vault.dart:50,69-73,148,243-244,293` |
| M3 | 中 | **改口令轮换 DEK 并重加密全量数据**：`rewrap` = `openEnvelope(旧)` + `createEnvelope(新)`，会生成新盐、新 DEK、重加密数据。注释称「只重包 DEK，本实现…语义等价」**不成立**：DEK 变更会使其它同步端已缓存的 DEK 失效（需重输口令），且不与「只重包」承诺一致。无数据丢失（全量解密再加密），故非高危 | `crypto_vault.dart:209-218`；注释 `crypto_vault.dart:7`；`vault_store.dart:120-129` |
| M4 | 中 | **`forgetDevice` 可能不生效却提示成功**：`_clearDeviceDek` 捕获所有异常后静默（连日志都无），若 `storage.delete` 失败，DEK 仍在系统密钥库，`hasDeviceCache()` 仍为真、下次启动照常自动解锁；UI 仍提示「已清除本机缓存并锁定」 | `secret_store.dart:150-153,200-206`；提示文案 `secret_vault_page.dart:125-128`；状态探测 `vault_providers.dart:59-67,108-111` |
| M5 | 中 | **PBKDF2 迭代 210000 偏低**：OWASP 2023 对 PBKDF2-HMAC-SHA256 建议 ≥600000。在口令偏弱时，离线暴破（拿到同步的 `vault.dat`）成本显著下降 | `crypto_vault.dart:50`；文档 `docs/DATA_FORMAT.md:136` |
| M6 | 中 | **读改写无并发保护 / 跨设备单例冲突**：`upsert`/`deleteEntity`/`writeAll`/`migrateFromLocal` 均「读→改→整写」，并发调用或两端同改会丢更新；`vault.dat` 为单例，文档也承认会产冲突副本但无仲裁 | `vault_store.dart:92-117`；`secret_store.dart:107-117,156-176`；`docs/SYNC.md:201` |
| M7 | 中 | **安全测试覆盖不足**：现测覆盖 往返/错口令/篡改/明文检查/头字段/改口令，但缺：nonce 新鲜性、空/短口令拒绝、截断/坏盐长、`writeDataWithDek`/`openWithDek` 往返、门面锁定态行为、`rewrap` DEK 轮换、`looksLikeVault` 假阳/假阴 | `test/crypto_vault_test.dart:1-84` |
| L1 | 低 | **`vault.dat` 未做本地权限收紧**（旧降级文件有 `chmod 600`，vault 文件没有）。虽为密文，但盐/迭代等元数据与密文本体对本机其他账户可读 | `vault_store.dart:52,101,127`；对照 `secret_store.dart:280-300` |
| L2 | 低 | **`looksLikeVault` 只比对首行**：带 UTF-8 BOM 或非 `\n` 换行的合法库可能被判非库（假阴）；任何首行为 `LFV1` 的文件被误判（假阳，但后续解析会失败，不致误删） | `crypto_vault.dart:220-226,273-276` |
| L3 | 低 | **web 语义差异**：内存 FS 刷新即清空，`vault.dat` 在 web 无持久化；`flutter_secure_storage` 在 web 落 localStorage + WebCrypto，安全边界弱于桌面 keychain；自动解锁在 web 尤弱 | `io_web.dart:14-17,403-407`；`secret_store.dart:26`；`main.dart:73-79` |
| L4 | 低 | **原子写 `rename` 覆盖在 Windows 可能失败**（Dart `File.rename` 目标已存在时不一定覆盖），影响全项目写路径，非保险库独有 | `file_utils.dart:22-30` |
| L5 | 低 | `headerOf` 直接 `_b64` 解盐且无长度保护，仅测试用；若将来接入 UI 展示需先加防护 | `crypto_vault.dart:229-239` |

---

## 2. 逐项必查清单结论（对应任务 1–9）

1. **KDF** — ✅ 盐每库随机 16B、`Random.secure` 生成，创建/改口令都换新盐；KDF 算法与版本被白名单校验。⚠️ `iters` 字段不被使用（M2）；上层无最小口令约束（M1）；210000 < OWASP 600000（M5）。**不可被文件篡改降级**（因为根本不用文件里的 iters），但也因此丧失升级兼容性。
2. **AEAD/nonce** — ✅ 每次 `encrypt` 都新建 12B 随机 nonce；`writeAll`/`upsert`/`changePassphrase` 均不重用 nonce（实测同 DEK 同明文两次写入结果不同，证明 nonce 新鲜）；tag 16B 且在 `_openData`/`decrypt` 强制校验。无 nonce 复用。
3. **信封正确性** — ✅ KEK 只包 DEK（`crypto_vault.dart:103`），DEK 只加密数据（`:107`），DEK 32B 随机（`:99`）。❌ `rewrap` 不是「只重包 DEK」，而是整体重生成（M3）；无数据丢失但语义与文档不符。
4. **明文泄漏** — ✅ 实测落盘 `vault.dat` 不含 secret 金丝雀、键名、口令、DEK（见 §4）；异常文案均为通用提示，不回显口令/密钥；日志仅记录异常对象与降级事件，无敏感内容。
5. **口令缓存** — ⚠️ DEK 以 base64 存系统密钥库，等于把「解锁能力」下放给 OS 凭据存储；`forgetDevice` 删除失败被静默吞（M4）；自动解锁在 `main.dart:76` 于启动即无条件尝试，无用户在场/屏幕锁校验。keychain 不可用时写入失败仅告警，不影响口令解锁（合理降级）。
6. **门面语义** — ❌ 锁定态 `read` 降级旧后端（H1）；`write/delete` 锁定态抛错（正确）；`migrateFromLocal` 用 `putIfAbsent` 合并且 vault 优先，**不丢键**，但默认 `deleteAfter=false` 保留源，与 H1 叠加放大问题。
7. **健壮性** — ⚠️ 读改写非并发安全（M6）；`writeStringAtomic` 本身同目录临时文件 + rename 具备单次原子性，但 Windows 覆盖行为存疑（L4）；坏/截断文件由 `VaultException` 受控处理，不崩溃；`looksLikeVault` 有 BOM 假阴（L2）；web 内存 FS 不持久（L3）。
8. **测试充分性** — ⚠️ 见 M7，缺大量关键负例与门面测试。
9. **现实安全边界** — ✅ 文档/注释**正确**声明「混淆≠安全」（`crypto_vault.dart:9-11`、`secret_vault_page.dart:364-385`、`docs/DATA_FORMAT.md:120-121`）；威胁模型与用户须知见 §5。

---

## 3. 必须修 / 建议修 / 可忽略

### 必须修（阻断）
- **H1**：锁定态 `read` 不得回退旧后端。应改为：`vaultExists && !vaultUnlocked → throw VaultException`（与 `write/delete` 对齐），仅在「库不存在」时才走 legacy。同时把迁移默认改为「迁移后删除源」或在 UI 明示「源保留会削弱锁定」。

### 建议修
- M1：在 `CryptoVault`/`VaultStore`/`SecretStore` 层加最小长度与空口令拒绝，UI 校验改为第二道防线。
- M2：`openEnvelopeData` 交叉校验 `iters == kIterations`（或真正使用文件 iters 并按上限钳制），为未来 KDF 升级留迁移路径。
- M3：若坚持「只重包 DEK」，改为「解出 DEK→仅用新 KEK 重包 wrap 段」；若保持重生成，修正注释与文档，并显式说明「其它设备需重新输入口令」。
- M4：`_clearDeviceDek` 失败需上报/记日志并让 `forgetDevice` 返回失败状态，UI 不得无脑提示成功。
- M5：将迭代提升至 ≥600000（或采用 Argon2id），并在文档标注。
- M6：写入加进程内互斥；跨设备冲突至少保留 `.conflict` 副本并提示。
- M7：补齐 nonce 新鲜性、空/短口令、截断/坏盐长、`openWithDek`/`writeDataWithDek` 往返、门面锁定态、`rewrap` DEK 轮换、`looksLikeVault` 假阳/假阴用例。

### 可忽略（记录即可）
- L1/L2/L4/L5：属加固或边缘平台问题，可排期；L3 需在 README 明确「web 端保险库不持久、仅供演示」。

---

## 4. 实测证据（本次运行）

### 4.1 静态与测试
```
$ flutter analyze
Analyzing lifeline...
No issues found! (ran in 3.9s)

$ flutter test test/crypto_vault_test.dart
00:09 +6: All tests passed!
```

### 4.2 临时探针（已删除 `test/tmp_security_probe_test.dart`，未改业务代码）
```
HEADER a: {v: 1, kdf: pbkdf2-sha256, iters: 210000, saltLen: 16, hasWrap: true, hasData: true}
两次同口令创建内容不同: true                # 盐/DEK/nonce 随机
同 DEK 同明文两次 writeDataWithDek 结果不同: true   # 每次加密 nonce 新鲜，无复用
DEK rotated on rewrap: true                # 改口令确实轮换 DEK（M3）
EMPTY PASSPHRASE ACCEPTED (roundtrip json equal): true  keys=[openai, deepseek]  # M1

真实 vault.dat 落盘探针（VaultStore.create）:
VAULT PATH: /tmp/vault_probe_*/.lifeline/vault.dat
VAULT SIZE: 443
CONTAINS canary(sk-test-PLAINTEXT-CANARY): false
CONTAINS key name openai: false
CONTAINS passphrase: false
CONTAINS dek raw b64 in file: false
PREFIX: LFV1\nGNWnjaFH8gZko2oytbPQNydJKGUeeXIjARVOhnYSnUTsCG2RrKf8drgIYyjf1QGUkJQOfxakvIsC...
```
**结论**：vault 文件确为纯密文，不含任何明文 secret 或密钥材料；混淆层确为可逆公开变换（符合文档声明）。

---

## 5. 现实安全边界与用户须知

- **混淆 ≠ 安全**：`LFV1` + 换行 base64 + XOR keystream 由硬编码常量推导，任何人可逆；它只防「肉眼一眼识别」。真正机密性来自「口令 + PBKDF2 + AES-256-GCM」（文档与注释表述正确）。
- **真实威胁模型**：
  1. **离线暴力破解口令**——攻击者拿到同步的 `vault.dat` 后，完全离线地对口令做字典/暴破。安全性 **100% 取决于口令熵**，与文件混淆无关。当前 210000 迭代进一步降低攻击成本（M5）。
  2. **本地/已解锁会话**——DEK 缓存在系统密钥库且启动自动解锁，任何获得已解锁 OS 会话者可直接使用密钥，无需口令。
  3. **同步通道侧信道**——文件随第三方同步工具（坚果云/OneDrive/rclone 等）传输，密文本身安全；但需确保忽略规则**不排除** `vault.dat`，且不与 `secrets.local.json` 明文副本一并同步。
  4. **元数据泄漏**——文件大小暴露明文规模；本机文件默认权限未收紧（L1）。
- **用户须知**：口令必须强且唯一；**口令丢失不可恢复**（无后门、无找回——文档与 UI 已明示，`secret_vault_page.dart:245`）；多设备须同口令；改口令后其它设备需重新输入口令（M3）；web 端不具备持久化/强保护（L3）。

---

## 6. 修改日志
- 2026-10-06 新增本报告：加密同步密钥保险库独立安全审查（1 阻断项 H1，7 中危 M1–M7，5 低危 L1–L5）；实测 analyze/test 通过，vault 文件非明文已核验。
