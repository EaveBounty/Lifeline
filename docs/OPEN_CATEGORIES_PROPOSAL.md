# 「履痕」开放分类推荐集 + 迁移方案（v1，给开发方）

> 依据：`open_brief.md`（软件 v0.4.2 已支持开放分类）、`taxonomy_proposal_v4.md`（已通过终审 ACCEPT，§6.3/§6.4 为 91 条落位权威结果）、`taxonomy_critique_v4.md`。
> 形态约束：软件**扁平**（无父子/无 subtype），分类集同时决定「记录列表分组」与「简历章节（按 order 逐类一节，空则跳过）」。
> 结论：推荐 **17 个分类**；91 条全部落位（合计 91，0 未归类）；迁移为「登记 categories → 改 category 字段并移目录 → 重建索引」，旧数据零丢失。

---

## 0. 一句话摘要

把 v4 的 13 个存储大类，按「简历章节」需要**拆开三个复合桶**（awards→竞赛/荣誉/奖助学金；credentials→证书/语言；activities→实践志愿/竞赛参与），并**保留 v4 已定的 leadership、archive 两类**，同时沿用 v4「projects 并入 works」的终审结论 → 得到 **17 个彼此同质、可直接作简历章节**的扁平分类。

**推荐分类数：17**（区间 14–20 的中位偏细；去掉空类可压到 16/15，见 §6）。

| # | slug | 中文名 | icon | order |
|---|---|---|---|---|
| 1 | education | 教育经历 | school | 1 |
| 2 | experience | 工作与实习 | work | 2 |
| 3 | research | 科研经历 | science | 3 |
| 4 | publications | 论文与知识产权 | menu_book | 4 |
| 5 | works | 项目与作品 | brush | 5 |
| 6 | competitions | 竞赛获奖 | emoji_events | 6 |
| 7 | honors | 荣誉表彰 | star | 7 |
| 8 | scholarships | 奖助学金 | attach_money | 8 |
| 9 | leadership | 学生工作 | groups | 9 |
| 10 | skills | 技能特长 | construction | 10 |
| 11 | certificates | 证书与资格 | verified | 11 |
| 12 | languages | 语言能力 | translate | 12 |
| 13 | trainings | 培训进修 | model_training | 13 |
| 14 | activities | 社会实践与志愿 | volunteer_activism | 14 |
| 15 | participation | 竞赛参与 | directions_run | 15 |
| 16 | archive | 档案资料 | bookmark | 16 |
| 17 | custom | 其他 | category | 17 |

---

## 1. 推荐分类集（可直接粘贴到 `lifeline.yaml` 的 `categories:` 块）

```yaml
categories:
  - slug: education
    label: 教育经历
    icon: school
    order: 1
  - slug: experience
    label: 工作与实习
    icon: work
    order: 2
  - slug: research
    label: 科研经历
    icon: science
    order: 3
  - slug: publications
    label: 论文与知识产权
    icon: menu_book
    order: 4
  - slug: works
    label: 项目与作品
    icon: brush
    order: 5
  - slug: competitions
    label: 竞赛获奖
    icon: emoji_events
    order: 6
  - slug: honors
    label: 荣誉表彰
    icon: star
    order: 7
  - slug: scholarships
    label: 奖助学金
    icon: attach_money
    order: 8
  - slug: leadership
    label: 学生工作
    icon: groups
    order: 9
  - slug: skills
    label: 技能特长
    icon: construction
    order: 10
  - slug: certificates
    label: 证书与资格
    icon: verified
    order: 11
  - slug: languages
    label: 语言能力
    icon: translate
    order: 12
  - slug: trainings
    label: 培训进修
    icon: model_training
    order: 13
  - slug: activities
    label: 社会实践与志愿
    icon: volunteer_activism
    order: 14
  - slug: participation
    label: 竞赛参与
    icon: directions_run
    order: 15
  - slug: archive
    label: 档案资料
    icon: bookmark
    order: 16
  - slug: custom
    label: 其他
    icon: category
    order: 17
```

### 1.1 排序理由（简历常规顺序）

`order` 即 `resume_compiler.dart` 生成章节的先后。采用「中文学术/求职简历」主轴：

1. **学历打头**：`education` 永远第一。
2. **经历次之**：`experience`（实习/工作）→ `research`（科研）→ `publications`（论文专利）→ `works`（项目作品），构成「做过什么」主干；论文/知识产权前置于作品，因本用户走科研/硕士路线，论文权重高。
3. **成果与荣誉成组**：`competitions`（竞赛获奖）→ `honors`（荣誉表彰）→ `scholarships`（奖助学金），是「得到什么」。
4. **软性能力**：`leadership`（学生工作）→ `skills` → `certificates` → `languages`，收尾。
5. **低权重/默认不上简历**：`trainings` → `activities` → `participation`（仅参赛）→ `archive`（默认排除）→ `custom` 兜底殿后。

> 说明：`order` 用户可在设置页调整；此处给的是理性默认值。求职向可把 `experience` 提到 `research` 前，不影响分类本身。

---

## 2. 每个分类的收录范围与边界规则

一句话收录范围 + 消歧规则（消歧规则取自 v4 §4.4/§5 的 category 层判据，因无 subtype，规则直接落到 category）：

| slug | 收录范围（一句话） | 边界 / 消歧规则 |
|---|---|---|
| **education** | 授予学历/学位的教育经历（学校、专业、学制）。 | 学历教育归此；**毕业论文/毕设 → research**；**学生干部任职 → leadership**。 |
| **experience** | 全职/实习/兼职、公司任职、创业任职。 | 企业/单位任职 → 此；**校内学生干部/社团职务 → leadership**。创业任職（法人/股东/创始人）仍归此。 |
| **research** | 科研项目/课题（大创、基金、科研训练）与毕业论文/毕设。 | **项目本体 → research**；**产出物（软件/装置）→ works**；同一实体用 `relations` 链接，不双计。 |
| **publications** | 论文、专利、著作权/软著、著作。 | **权利/文献 → 此**；**软件成品本体 → works**（软著是权利，作品是本体，可并存）。 |
| **works** | 项目与作品——工程/自研项目本体、软件作品、装置/硬件设计、设计成果。 | **科研项目 → research**；**竞赛名次 → competitions**；作品获同一竞赛奖不另建完整条。 |
| **competitions** | 学科竞赛**获奖**（含金/银/铜/一/二/三等奖、优胜奖、优秀奖、名次）。 | **有奖项词/名次 → 此**；**仅参赛/观众/参与证明 → participation**；**称号评优不属竞赛 → honors**。 |
| **honors** | 表彰荣誉/称号（优秀学生、三好、优秀团员/团干/干部、先进个人、优秀志愿者称号等）。 | **称号/表彰 → 此**；**参与/服务本身 → activities**；**金钱奖励 → scholarships**；裸「优秀奖」仍归 competitions。 |
| **scholarships** | 奖学金/助学金。 | 以「奖助学金」名义的金钱奖励 → 此；**竞赛奖金/名次 → competitions**。 |
| **leadership** | 学生干部、学生会/社团/工作室**负责人**（担任职务）。 | **担任职务 → 此**；**参加活动 → activities**；**因职务获奖/评优 → honors**；职务词限强词（团支书/班长/部长/社长/会长/队长/寝室长等）。 |
| **skills** | 专业技能/能力描述（非证书，如「嵌入式开发」「数据分析」）。 | **能力描述 → 此**；**证书/资格 → certificates**。 |
| **certificates** | 技能证书、职业资格、等级考试（计算机等级 NCRE、技能认证等）。 | **语言类证书 → languages**；**培训过程/结业 → trainings**；英语**竞赛**证书（NECCS）归此（非语言等级）。 |
| **languages** | 语言能力证明（CET-4/6、雅思、托福、普通话等级）。 | **语言类归此**；**语言竞赛 → competitions/participation**；**非语言证书 → certificates**。 |
| **trainings** | 培训进修及其结业（MOOC、青马工程、研修、骨干培训）。 | **有学习过程/结业 → 此**；**仅有证书且非过程 → certificates**。 |
| **activities** | 社会实践与志愿服务（志愿服务、公益、社团活动、社会实践）。 | **参与本身 → 此**；**获表彰 → honors**；**有竞赛性质 → participation**。 |
| **participation** | 竞赛参与（仅参赛/观众/参与证明/德育分，**无奖项**）。 | **无奖 → 此**；**有奖项/名次 → competitions**；**非竞赛类活动 → activities**。默认低权重、简历可整类剔除。 |
| **archive** | 档案与隐私（健康体检/影像、证照、简历证明、综测归档）。 | **私密/凭证/归档类 → 此**；默认**不进简历**（章节保留但可整体隐藏）。 |
| **custom** | 兴趣、推荐人、无法归类（兜底）。 | 上述皆不命中 → 此；建议留 `needs_review` 标记待人工确认。 |

> 三组高频混淆的定调：
> - **学科竞赛 vs 竞赛参与**：以「是否有奖项/名次」二分，`competitions`（获奖）对 `participation`（仅参赛）。
> - **证书 vs 语言**：语言类等级（CET/普通话/雅思托福）→ `languages`；其余资质 → `certificates`；语言「竞赛」既不是证书也不是等级 → 归竞赛类。
> - **项目 vs 作品**：科研项目/课题（大创、基金）→ `research`；工程/自研项目与产出物 → `works`（v4 终审 D2：旧 `projects` 并入 `works`）。

---

## 3. 旧 15 默认类 → 新分类 迁移映射表

| 旧 slug（默认 15） | 新 slug | 说明 |
|---|---|---|
| education | **education** | 原位 |
| experience | **experience** / **leadership** | 企业/实习/创业 → experience；学生干部 → leadership（**二义①**） |
| projects | **works** | 并入 works（v4 终审 D2；本数据集中旧 projects 为空，无实际迁移量） |
| research | **research** | 原位 |
| awards | **competitions** / **honors** / **scholarships** | 按获奖 / 称号 / 奖助学金三分 |
| publications | **publications** | 原位 |
| certificates | **certificates** | 原位（v4 曾拟改名 credentials，本方案保留 slug 以减少目录改造） |
| skills | **skills** | 原位 |
| languages | **languages** | 原位（不再并入 credentials） |
| activities | **activities** / **participation** / **certificates** | 志愿·社团 → activities；仅参赛 → participation；参赛**证书**（NECCS）→ certificates（**二义②**） |
| trainings | **trainings** | 原位 |
| works | **works** | 原位（projects 并入） |
| interests | **custom** | 收敛到 custom |
| references | **custom** | 收敛到 custom |
| custom | **archive** / **custom** | 隐私/证照/简历/综测 → archive；其余 → custom（**二义③**） |

**新增 slug**：competitions、honors、scholarships、leadership、participation、archive。
**移除 slug**：projects、awards、interests、references。
**二义 3 处**（experience、activities、custom）需逐条判定，判定规则见 §2 与 v4 §5；本数据集 91 条已按此重跑完毕（§4）。

---

## 4. 91 条现状 → 新分类 落位清单（合计 91）

按 v4 §6.3/§6.4 的子类结果归并到新 category（子类不再独立成类）：

| 新 slug | 条数 | 来源构成（v4 subtype） | 记录 id 前缀 |
|---|---:|---|---|
| education | 1 | education/本科 1 | f362c93e |
| experience | 3 | 公司任职 1 + 创业任职 2 | 6522b255 / 8e65afe4 / a930c264 |
| research | 2 | 科研项目 1 + 毕业论文 1 | 9e220955 / f1cf3cd8 |
| publications | 5 | 论文 3 + 专利 1 + 著作权 1 | 1e4950f7, 6bace271, 814403f0, 3e70efff, 9c91606e |
| works | 4 | 软件作品 3 + 装置设计 1 | 19fb3834, 2c43c446, 9795cc70, ee10370f |
| competitions | 30 | awards/学科竞赛 30 | 0389c05c,1334862f,1454e491,157a5e94,1c851158,2688b242,28277aa9,3b172c25,49132384,5ffa73ed,623df7dc,65b6f8e8,669410d5,70947df0,72c1944f,795e49fa,84c05f4e,85b87e09,93dbb69f,93f18f95,9466edd6,be5660fe,c19e091c,c53657ee,e153839c,e2730f6f,ea76ce33,f2a69bbc,f43aa21c,f54b868b |
| honors | 8 | awards/表彰荣誉 8 | 22d86d38, 5342ffae, 5f054406, 5f6497bc, bf9c2b20, c15ee0a3, c650de82, e2daec69 |
| scholarships | 4 | awards/奖学金 4 | 149afa1c, 57412088, 87b77e81, 8d9a57ca |
| leadership | 3 | experience/学生干部 3 | 1b35e3ce, 2559c5d4, 3af58192 |
| skills | 0 | （暂无） | — |
| certificates | 5 | 技能证书 3 + 等级考试 1 + NECCS 参赛证书 1 | 444a54c5, 9d946c73, a1cbc28c, 0f08493f, b20ebe7f |
| languages | 3 | 普通话 1 + 英语 2 | 005a5b70, 486b568f, dd891d10 |
| trainings | 4 | MOOC培训 2 + 青马工程 2 | 634c2742, 72e21e63, 3c1d78f7, 5e30b7a1 |
| activities | 8 | 志愿服务 6 + 社团活动 2 | 0eb3be49, 3cf3929a, 5cae5300, 60545726, 64da5aa6, f3ba2bb9, a825ace2, d813e61e |
| participation | 6 | awards/竞赛参赛 6 | 2252499d, 7569ac04, a8396cd4, c08a01b5, d218a26e, e54cd871 |
| archive | 5 | 健康隐私 1 + 档案证照 2 + 简历证明 1 + 综测归档 1 | 5e5851e5, c569b5ea, dff374c7, d8da7e39, cb3839ea |
| custom | 0 | （暂无） | — |
| **合计** | **91** | 逐类求和 | **91** |

**交叉校验**：competitions+honors+scholarships = 42（= 旧 awards）✓；certificates+languages = 8（= v4 credentials）✓；activities+participation = 14（= v4 activities，另 1 条 NECCS 移入 certificates）✓；works = 4（含旧 projects 0）✓。

> 5 条 `needs_review`（v4 §6.2，规则已给唯一落点，供人工复核，不阻断迁移）：`b20ebe7f`（NECCS 参赛证书→certificates）、`c15ee0a3`/`e2daec69`（优秀志愿者→honors）、`d813e61e`（参与类证明→activities）、`a825ace2`（单词打卡→activities）。

---

## 5. 实施步骤（迁移）

1. **登记分类**：把 §1 的 `categories:` 块写入同步根 `lifeline.yaml`（不存在则新建该顶层键）。此时软件已能按新 `order` 生成简历章节；未改动记录仍按旧 slug 显示为**额外章节**（标题=slug），故可增量迁移。
2. **备份**：整目录复制 `data/records/`（含 `state.json`），或打 tag。
3. **建目录**：新建 `data/records/{competitions,honors,scholarships,leadership,participation,archive}/`；`education/ experience/ research/ publications/ works/ skills/ certificates/ languages/ trainings/ activities/ custom/` 已存在沿用；`projects/ interests/ references/` 迁移后删除（空目录）。
4. **改字段 + 移目录**（逐条、原子）：按 §3 映射表把记录 JSON 的 `category` 改为新 slug，并把 `data/records/<old>/<id>.json` 移到 `data/records/<new>/<id>.json`。建议同时写 `legacy_category: <旧slug>` 便于回溯；**记录内 `fields.subcategory` 原样保留**（子类信息不丢，日后若要上 subtype 可直接复用）。三处二义（experience/activities/custom）按 §2 规则逐条判定。
5. **重建索引**：调用 `rebuildIndex`（`records_repository.dart`），全量重扫目录生成索引；`state.json` 记录一次迁移版本号。
6. **验收**：运行分类迁移回归（以 v4 §10 的 47 行断言为蓝本，断言新 category），核对 §4 计数合计 = 91。

**向后兼容说明**：
- 磁盘路径与 `category` 字段一律按 **slug**；未在 `categories:` 登记的 slug，记为可读记录并**追加为额外章节**（标题=slug），因此「先写 YAML、后改记录」或「漏改个别记录」都**不会导致数据不可读或丢失**。
- 旧 slug 若要平滑，可在迁移器内保留**旧 slug → 新 slug 别名表**（§3），读时自动重定向；写入侧只写新 slug。
- 未知/失配记录（应无）→ `custom` 并置 `needs_review`。

---

## 6. 权衡（记录细 vs 简历精简）

分类数 = 简历章节数，二者正向耦合。本方案 17 类已把原「一桶多物」（awards 42 条、activities 15 条）拆到同质，代价是章节变多。给开发方三个可调档位：

- **17 类（推荐）**：语义最清，简历默认约 14 个非空章节（skills/custom 恒空，archive 默认排除）。适合作为默认集。
- **16 类（精简）**：把 **participation 并入 competitions**（36 条），竞赛章节内用 `tags`/`fields`（如 `fields.result: 参赛`）区分获奖与参与，简历端只筛获奖。→ 少 1 个低价值章节。
- **15 类（最省）**：在 16 类上再把 **honors 并入 scholarships** 为「荣誉与奖励」（12 条），或将 **trainings 并入 activities**。适合只求「记录分组够细」而不在意简历颗粒度的用户。

**取舍原则**：竞赛参与（participation）、档案（archive）低权重，优先并入/隐藏；竞赛获奖、论文、科研、荣誉是求职/升学高信号，**不建议合并**。

---

## 7. 给开发方的一条增强建议（可选）

若将来既要「记录超细、简历精简」，建议给 `CategoryDef` 增加 `group`（父类/分组）或 `hidden_in_resume` 布尔字段——记录端可细到 20+ 类，简历端按 `group` 折叠或按开关隐藏，即可在**一个扁平存储**上同时满足两种粒度，而不必反复增删分类。
