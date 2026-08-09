---
task_id: T001
idempotency_key: run-001-T001-stage0-tools
createdAt: 2026-08-09
owner: owner-catalog-installer
status: draft
title: 阶段 0 — 8 个 Stage 0 工具参数表补全
---

# T001 · 阶段 0 — 8 个 Stage 0 工具参数表补全

## 目标

为 `docs/STAGE0_TOOLS.md` 中的 8 个工具补全真实参数，支撑阶段 3 的安装实现。

## 范围

补全以下 8 个工具：

1. Git
2. Node.js
3. Python
4. Go
5. Rust
6. Visual Studio Code
7. Docker Desktop
8. iTerm2

每个工具必须包含：

- `packageName`（Homebrew 名称）
- `versionRule`（最低推荐版本）
- `url`（官方包 URL，必须 https）
- `sha256`（64 字符 hex）
- `bundleID`（GUI App 的 Bundle ID）
- `teamID`（10 字符 Apple Team ID）
- `supportedArchitectures`（arm64 / x86_64）
- `minimumMacOS`
- `riskLevel`

## 不可做

- 不要安装任何工具到本机
- 不要修改 Project.swift
- 不要修改其他 Agent 的 owned paths

## 输入

- `docs/STAGE0_TOOLS.md` 现有 8 个工具的占位表
- `docs/CATALOG_SCHEMA.md` 字段定义

## 验收

- [ ] 8 个工具全部参数补全
- [ ] 每个 SHA-256 与官网一致（不能猜；查官方下载页面或 Homebrew Formula 源）
- [ ] 每个 Team ID 通过 `codesign -dv --verbose=4 <app>` 或 Apple 官方注册查询确认
- [ ] 在 `Catalog/tools/` 下创建 8 个工具的 JSON 元数据（暂不要求签名；阶段 2 接入）
- [ ] 更新 `docs/STAGE0_TOOLS.md` 表格的占位字段

## 验证命令

```bash
# 校验 Catalog/tools/ 下 JSON 与 schema 一致
npx ajv-cli validate -s Catalog/schemas/catalog.schema.json -d "Catalog/tools/*.json" --errors=full

# （可选）查询 Bundle ID
osascript -e 'id of app "Visual Studio Code"'
```

## 风险

- 某些工具的 Team ID 需要从已安装的 App 提取；若本机未装，记录"待验证"并在 PR 描述中说明
- 某些工具的 sha256 需下载 dmg 后计算；若不想下载，从 Homebrew Formula 复制已知值并标注来源

## 交付

- 更新 `docs/STAGE0_TOOLS.md`
- 新增 `Catalog/tools/{git,nodejs,python,go,rust,vscode,docker-desktop,iterm2}.json`
- 在 `outbox/owner-catalog-installer.yaml` 写交付说明

## handoff_to

- owner → reviewer
- reviewer 验收通过 → qa
- qa 跑 `npx ajv-cli validate` 通过 → coordinator 收口
