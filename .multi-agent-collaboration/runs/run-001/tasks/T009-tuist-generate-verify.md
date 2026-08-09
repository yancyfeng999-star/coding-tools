---
task_id: T009
idempotency_key: run-001-T009-tuist-generate-verify
createdAt: 2026-08-09
owner: owner-release-update-security
status: draft
title: 阶段 1 — tuist generate 验证可启动
---

# T009 · 阶段 1 — tuist generate 验证可启动

## 目标

验证 Tuist 工程能成功 `tuist install && tuist generate && xcodebuild` 启动。

## 范围

执行：

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"

# 1. 安装 Tuist 依赖（如果 tuist 尚未 install）
tuist install

# 2. 生成 Xcode 工程
tuist generate

# 3. 验证工程能 Debug 编译
./scripts/build.sh

# 4. 验证测试能跑
./scripts/run-tests.sh
```

## 不可做

- 不要修改 Project.swift 的 target 列表（除非 build 报错证明 Project.swift 本身有 bug）
- 不要修改 Sparkle 依赖版本
- 不要修改其他 Agent 的 owned paths

## 验收

- [ ] `tuist install` 成功
- [ ] `tuist generate` 成功生成 `.xcodeproj` / `.xcworkspace`
- [ ] `xcodebuild ... build` Debug 通过
- [ ] 单元测试通过（至少 DomainTests / CatalogTests / InstallerTests / ManifestSecurityTests / AppTests 不报红）
- [ ] 没有任何编译错误

## 失败处理

如果 build 失败：

1. 记录错误原文
2. 判断是 Project.swift 配置问题、Sparkle 依赖问题、还是 Xcode 工具链问题
3. 修复 Project.swift（这是 Coordinator 拥有的高冲突文件 → 需要在 outbox 中请 Coordinator 修改，或在自己 owned paths 内做最小修复）
4. 重新跑 build
5. 仍然失败 → BLOCKED + 在 outbox 中详细报告

## 交付

- 在 `outbox/owner-release-update-security.yaml` 写：
  - `tuist generate` 成功日志
  - `xcodebuild build` 成功日志
  - `xcodebuild test` 摘要（passed / failed 数量）

## handoff_to

- owner → reviewer
- reviewer 验收通过 → qa（实际重跑一遍 build + test）
- qa 通过 → coordinator 收口，进入阶段 2/3/4
