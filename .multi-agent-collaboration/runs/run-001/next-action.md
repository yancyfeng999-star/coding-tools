# Run-001 · 下一条可执行动作

> 这是 Coordinator / 通用 Agent 看到本 Run 后**第一步该做的事**。
> 等价于"待办事项第一条"。

## 当前状态

- Run ID: `run-001`
- 状态: `ready`（已建好骨架，等待分派）
- 目标: 阶段 0 / 1 落地

## 第一批可分派任务（3 个并行）

| Task | Owner | 优先级 | 前置 |
| --- | --- | --- | --- |
| T001 | owner-catalog-installer | high | — |
| T002 | owner-catalog-installer | high | — |
| T009 | owner-release-update-security | high | — |

### T001 · 阶段 0 — 8 个 Stage 0 工具参数表补全

- 任务文档: `tasks/T001-stage0-tools.md`
- Owner: owner-catalog-installer
- 范围: `Catalog/tools/*.json` + `docs/STAGE0_TOOLS.md` 占位补全
- 不可做: 装工具、改 Project.swift、动其他 Agent owned paths

### T002 · 阶段 0 — SECURITY_MODEL / CATALOG_SCHEMA 评审

- 任务文档: `tasks/T002-security-schema-review.md`（占位）
- Owner: owner-catalog-installer
- 范围: 评审现有两份文档的可执行性，提出修订建议
- 不可做: 直接修改其他 Agent 的 owned paths

### T009 · 阶段 1 — tuist generate 验证可启动

- 任务文档: `tasks/T009-tuist-generate-verify.md`
- Owner: owner-release-update-security
- 范围: `tuist install && tuist generate && build && test`
- 不可做: 改 Project.swift target 列表 / 改 Sparkle 版本 / 动其他 Agent owned paths

## 调度命令（参考）

```bash
# Coordinator 通过 Mavis 的 task 工具委派子代理
# 使用 coder agent 执行 T001 / T002 / T009
# 提示词模板见各任务文档
```

## Reviewer / QA 启动条件

T001 / T002 / T009 任意一个产出 HANDOFF_READY 后：

1. Coordinator 派 reviewer 子代理（agent_name: reviewer）
2. Reviewer 产出 reviews/<task-id>-review.md
3. 评审通过 → Coordinator 派 qa 子代理
4. QA 跑实际验证 → 产出 qa-results/<task-id>-qa.md
5. QA 通过 → Coordinator 在 state.yaml 标 completed
