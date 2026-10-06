# Changelog

本项目所有值得记录的变更均记于此文件。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 计划
- U0 脚手架；U1 数据层；U2 首启与设置；U3 信息表与附件；U4 首页完整简历；
  U5 编译管线与渲染器；U6 AI 录入/编译；U7 智能导出；U8 同步文档；U9 测试与 CI。

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
