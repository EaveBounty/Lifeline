# Changelog

本项目所有值得记录的变更均记于此文件。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 计划
- U0 脚手架；U1 数据层；U2 首启与设置；U3 信息表与附件；U4 首页完整简历；
  U5 编译管线与渲染器；U6 AI 录入/编译；U7 智能导出；U8 同步文档；U9 测试与 CI。

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
