# 多代理协作文档总线

> Coding Tools 项目使用 [multi-agent-collaboration](../../AGENTS.md) 通用协议做并行开发。
> 所有跨 Agent / 子代理的通信都通过此目录下的文档。

## 目录说明

```text
.multi-agent-collaboration/
├── project.yaml          # 项目身份（只读）
├── protocol.yaml         # 协议版本（v3）
└── runs/                 # 每个 Run 一个目录
    └── run-001/          # 当前 Run
        ├── agents.yaml   # Agent Registry
        ├── state.yaml    # 全局状态（Coordinator 独占写）
        ├── events/       # 事件日志（每次一条）
        ├── tasks/        # 任务文档
        ├── inbox/        # 通用 Agent 收件箱
        ├── outbox/       # 通用 Agent 发件箱
        ├── locks/        # 资源锁
        ├── next-action.md  # 下一条可执行命令
        └── summary.md    # 收口时生成
```

## 协议版本

- 当前：`v3`（2026-08-09 由 Coordinator 初始化）
- 不继承其他项目的角色、权限或路径

## 治理模式

- 默认：`standard`（代码修改）
- 发布相关任务：`strict`（生产、权限、密钥、Release）
- 调研 / 文档：`light`

## 角色

详细见 [agents.yaml](./runs/run-001/agents.yaml)。

## 下一动作

见 [next-action.md](./runs/run-001/next-action.md)。
