# 同步指南（SYNC）

> Lifeline · 履痕**自身不执行同步**。本文给出把「同步根目录」交给 Syncthing / WebDAV / Git 的逐步配置、冲突与合并策略。
> 相关：数据格式见 [`DATA_FORMAT.md`](DATA_FORMAT.md)；设计原则见 [`ARCHITECTURE.md`](../ARCHITECTURE.md) §1。

---

## 1. 设计前提

- App 只读写用户选定的**同步根目录**，不写自身目录、不建私有协议。
- 同步工具负责**传输与冲突副本**；App 负责**对同步友好的数据形态**：一条一文件、原子写、纯文本真相源、索引可重建。
- 真相源为 JSON / YAML；`data/index.sqlite` 是可重建的派生文件。

---

## 2. 方案对比

| 维度 | Syncthing | WebDAV | Git |
|---|---|---|---|
| 拓扑 | P2P，设备直连 | 客户端 ↔ 服务端 | 客户端 ↔ 远端仓库 |
| 服务器需求 | 无 | 需 WebDAV 服务（坚果云/Nextcloud/群晖） | 需远端（GitHub/GitLab/自建） |
| 离线 | 局域网可用 | 受服务可用性影响 | 本地提交离线，推送需网 |
| 冲突产物 | `*.sync-conflict-<date>-<time>-<device>` | 依客户端，通常保留副本 | 分支合并冲突 + `.conflict` 兜底 |
| 版本历史 | 版本化（可配保留策略） | 视服务 | 最强 |
| 大附件 | 好 | 好（受配额） | 差（大文件进历史膨胀） |
| 移动端 | 官方 Android App | 官方/第三方 App | 需 Termux 等 |
| 加密 | 传输 TLS + 设备身份 | 传输 TLS | 传输 TLS；Git 内容明文 |
| 适合 | 多设备自动同步 | 已有云盘/跨网络 | 需要历史/审阅/回溯 |

**选择建议**：日常多端 → Syncthing；已有云盘 → WebDAV；需要版本历史/审阅 → Git（附件可另用 Syncthing/网盘）。

---

## 3. Syncthing 逐步配置

1. **安装**：各设备安装 Syncthing（桌面用官方版；Android 用官方 App；Linux 可用发行版包）。
2. **添加设备**：在 A 设备 Web UI（默认 `http://127.0.0.1:8384`）→ *Add Remote Device*，填入 B 设备 Device ID；在 B 端确认。
3. **共享文件夹**：*Add Folder* → Folder Path 选择**同步根目录**（如 `~/Lifeline`）→ Folder ID 记为 `lifeline` → 在 *Sharing* 勾选目标设备 → 对方接受。
4. **忽略文件**（关键）：为文件夹配置 `.stignore`：

   ```
   // 可重建索引与临时文件不进同步
   data/index.sqlite
   data/index.sqlite-*
   *.tmp-*
   .lifeline/tmp/
   secrets.local.json
   ```

   > `.stignore` 由 Syncthing 识别；如不愿在根目录放隐藏文件，可在文件夹设置 *Ignore Patterns* 中内联相同规则。
   > 密钥降级文件 `secrets.local.json` 实际位于 **App 支持目录**（不在同步根内），此处忽略规则为防御性保留。
5. **扫描与版本**：*Advanced* 可设 `Scan Interval`（如 60s）；开启 *File Versioning*（Simple/Staggered）保留历史。
6. **验证**：在一端新增一条记录 JSON，另一端应在数秒内出现；App 的 `ChangeWatcher` 检测到后自动重编译。

**注意**：`data/index.sqlite` 同步会引发无意义冲突，务必忽略；各设备本地重建。

---

## 4. WebDAV 逐步配置

1. **准备服务**：坚果云（个人版含 WebDAV）、Nextcloud、群晖 WebDAV Server、或自建 `rclone serve webdav`。
2. **桌面端**：
   - 用系统文件管理器挂载 WebDAV（Windows「映射网络驱动器」/ Linux `davfs2` / GNOME「在线账户」），将同步根置于挂载点。
   - 或使用 **rclone** 建 `remote:`，以一个本地目录与远端做 `rclone bisync` 双向同步。
3. **rclone bisync 示例**：

   ```bash
   rclone config                    # 添加 WebDAV remote，命名 mydav
   rclone bisync ~/Lifeline mydav:Lifeline \
     --create-empty-src-dirs --compare size,modtime,checksum \
     --resync                       # 首次建立基线
   ```

   排除索引与临时文件：

   ```bash
   rclone bisync ~/Lifeline mydav:Lifeline \
     --exclude "data/index.sqlite*" --exclude "*.tmp-*" \
     --exclude "secrets.local.json" --resync
   ```

4. **移动端**：用支持 WebDAV 的文件管理器/同步 App（如 Nextcloud App、FolderSync）指向同目录。
5. **冲突**：多数客户端在冲突时保留副本（如 `xxx (conflict).json`）；按 §6 处理。

> WebDAV 常见限制：单文件大小/配额、限流、挂载断连。附件多时注意配额。

---

## 5. Git 逐步配置

Git 适合需要**版本历史、审阅、回溯**的场景；附件（大二进制）建议另用 Syncthing/网盘，或使用 Git LFS（权衡成本）。

1. **初始化**：在同步根目录

   ```bash
   cd <SyncRoot>
   git init
   git remote add origin <私库 URL>
   ```

2. **`.gitignore`（同步根内）**：

   ```gitignore
   # 派生索引，可重建，勿入库
   data/index.sqlite
   data/index.sqlite-*
   # 运行时临时/锁文件
   *.tmp-*
   *.lock
   .lifeline/tmp/
   # 密钥降级文件（实际在 App 支持目录，此处防御性忽略）
   secrets.local.json
   # 系统文件
   .DS_Store
   Thumbs.db
   ```

3. **首次提交**：

   ```bash
   git add .
   git commit -m "init lifeline data"
   git branch -M main
   git push -u origin main
   ```

4. **多端使用**：
   - 开始编辑前 `git pull --rebase`；结束编辑后 `git add -A && git commit && git push`。
   - 建议开启 `git config pull.rebase true` 减少合并噪声。
5. **`.gitattributes`（可选，规范 diff）**：

   ```gitattributes
   *.json diff text
   *.yaml diff text
   *.md   diff text
   *.sqlite -diff
   ```

**Git 分支策略（多设备/多身份）**：

- 单人多设备：可各设备一个长期分支（`dev-laptop`/`dev-desktop`），定期向 `main` 合并；避免直接在同一 `main` 上并发提交。
- 需要"不同身份/不同求职方向"的资料版本：用分支管理（如 `resume/backend`、`resume/research`）。
- **冲突处理**：`profile.json` 单例冲突概率高，优先在单设备编辑后推送；记录级冲突多为同 `uuid` 不同内容，按 §6 人工择一或合并。

---

## 6. 冲突与合并策略

### 6.1 冲突来源

- 多端同时编辑同一文件（记录/`profile.json`/`lifeline.yaml`）。
- 云盘/同步工具产生的冲突副本。
- 索引与数据不一致（索引冲突应丢弃并重建）。

### 6.2 通用原则

1. **一条一文件**：把冲突面从"整库"缩到"单条记录"。
2. **原子写**：App 写盘先临时文件再 rename，避免半写被同步。
3. **`.conflict` 副本**：检测到冲突时保留双方为 `*.conflict-<device>-<timestamp>.json`，**禁止静默覆盖**。
4. **索引不入同步**：`index.sqlite` 冲突时直接删除重建。
5. **可追溯**：记录 `updated_at`、`source`、`ai.confidence`，便于判断取舍。

### 6.3 冲突解决流程（推荐）

1. 同步工具报告冲突 / App 检测到 `*.conflict-*`。
2. 在 App 冲突中心并列展示两版字段差异。
3. 用户选择：保留本地 / 保留远端 / 字段级合并。
4. 解决后写回原 `id` 文件（原子写），删除冲突副本。
5. 触发索引重建 → 重编译。

### 6.4 预防

- 尽量**串行编辑**：同一时间只在一台设备改 `profile.json`。
- 缩短同步间隔但避免过密（Syncthing 建议 ≥30s；Git 用 pull/rebase 习惯）。
- 大改动前先同步并提交一次基线。

---

## 7. 移动端（Android）要点

- **Syncthing**：Android 官方 App 可将同步根放于应用可访问目录；注意后台省电策略可能延迟扫描。
- **WebDAV**：FolderSync/Nextcloud App 定期同步；注意冲突文件名。
- **Git**：Termux + `git`，或使用支持 Git 的编辑器；操作较重，非首选。
- 移动端优先"只读浏览 + 轻量编辑"，避免与大文件附件同时双向同步。

---

## 8. 快速选择清单

- 只是想在手机和电脑之间自动同步、附件也一起 → **Syncthing**。
- 已经在用坚果云/Nextcloud → **WebDAV（rclone bisync）**。
- 想要每次改动都有历史、可回滚、可审阅 → **Git**（索引 gitignore；大附件另存）。
- 混合：数据用 Git、附件用 Syncthing/网盘，两者目录互不重叠。

---

## 变更日志

- 2026-10-06 初版：三方案对比、Syncthing/WebDAV/Git 逐步配置、冲突与合并策略、`.gitignore`/`.stignore` 建议。
