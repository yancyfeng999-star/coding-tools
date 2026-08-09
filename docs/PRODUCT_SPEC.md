# Coding Tools · 产品合同

> 这是「阶段 0 — 产品和安全契约」的最终交付。开发计划的精简版，所有 Agent / 子代理开工前必读。

## 1. 一句话定位

> **可信的开发工具目录 + 安全安装器 + 学习入口 + 启动器**

不是「万能安装器」。Coding Tools 不接管未审核工具，不执行任意 Shell，不静默 sudo，不二次分发内容。

## 2. 目标用户与核心动作

| 用户类型 | 核心动作 | 价值 |
| --- | --- | --- |
| 新 macOS 开发者 | 浏览推荐工具 → 看清来源 → 一键安装 | 不踩坑装到恶意工具 |
| 全栈工程师 | 维护 Node/Python/Go 多版本 → 在项目目录里切换 | 不污染全局 |
| 团队 Lead | 让新人按统一目录装环境 | 团队一致 |
| 老用户 | 已装工具一键启动、教程聚合 | 不切多个网站 |

核心链路：

```text
发现工具 → 查看介绍 → 安装 → 启动 → 学习
```

## 3. v1.0.0 范围

### 支持

- macOS 14 Sonoma 及以上
- Apple Silicon + Intel Universal Binary
- 简体中文 + English
- 浅色 / 深色 / 跟随系统
- 20–30 个审核过的工具（Stage 0 验证 8 个 + 后续扩展）
- Homebrew Formula + Homebrew Cask + mise + 官方 DMG/ZIP/PKG
- Sparkle 2 应用内自动更新
- 教程知识库（仅元数据 + 原文链接）

### 不支持

- 任意远程 Shell / sudo 自动执行
- 视频下载 / 二次分发
- 付费内容抓取
- 全局 `brew upgrade` / `mise upgrade` 自动执行
- Windows / Linux / iOS
- 云账号 / 团队策略（v2.0）
- 服务型工具的自动启停（v1.0 只展示说明）

## 4. 数据模型（精简版）

```text
Tool                安装方式、分类、启动能力、风险
InstallOption       type/source/packageName/versionRule/downloadURL/sha256/bundleID/teamID
Installation        当前已安装版本、路径、架构、Bundle ID、Team ID、健康状态
ContentItem         教程/视频元数据（仅引用原文）
OperationLog        任何安装/检测/启动操作的结构化日志
CatalogSnapshot     远程签名目录的本地缓存 + 过期时间 + 撤销列表
```

完整定义见 [CATALOG_SCHEMA.md](./CATALOG_SCHEMA.md) 与开发计划 §8。

## 5. 安装流程（v1.0.0 标准行为）

### 5.1 安装前显示预览

```text
工具：Node.js
版本：22.x
来源：Homebrew Formula
操作：brew install node
权限：当前用户权限
下载：官方 Homebrew 源
预计变化：安装 CLI 和运行时
```

### 5.2 用户确认后

1. 检测前置条件（Homebrew / mise 是否安装）
2. 确认安装源
3. 显示安装队列
4. 执行受控进程（**强类型参数，禁止拼接 shell**）
5. 实时显示输出（redactedOutput）
6. 支持取消
7. 安装完成后重新检测
8. 验证版本、路径、架构
9. 写入结构化 OperationLog
10. 提供「启动 / 打开教程」按钮

### 5.3 不能做

- 默认执行 sudo
- 自动修改 `.zshrc`
- 自动覆盖用户 `PATH`
- 自动添加未知 Homebrew tap
- 自动修改 SSH、Git、Docker 配置
- 自动执行 post-install 脚本
- 自动升级所有工具

## 6. 工具更新与应用更新分开

| 维度 | Coding Tools 自身 | 工具自身 |
| --- | --- | --- |
| 默认策略 | 后台检查 / 后台下载 / 后台安装 | 自动检查；下载需用户确认；安装需用户点击 |
| 升级方式 | Sparkle 2 + Appcast | 单独触发 |
| 失败处理 | 保留旧版本 | 保留旧版本 + 失败诊断 |
| 批量 | — | 默认关闭 |
| `brew upgrade` 全局 | 永远不自动 | 永远不自动 |
| `mise upgrade` 全局 | 永远不自动 | 永远不自动 |

## 7. 隐私与权限

- **沙盒**：开启。`com.apple.security.app-sandbox = true`
- **网络客户端**：仅 HTTPS，禁用 HTTP 明文
- **下载**：仅当用户明确点击安装时启动下载
- **文件访问**：只读访问 `~/Library`、`/Applications`、`/usr/local`、`/opt/homebrew`；不写用户任意目录
- **执行**：仅执行 Homebrew / mise / `open` / `NSWorkspace`；不调用 `/bin/sh -c`
- **遥测**：不收集；所有数据保存在本机
- **日志脱敏**：必须过滤 Token、Cookie、环境变量、用户路径

## 8. 内容策略

- 只保存元数据：标题、作者、原文 URL、缩略图、标签、难度、发布时间
- 默认打开原文（外跳）
- 视频用官方嵌入（YouTube iframe）或外跳
- 不下载、不重写、不绕过付费墙
- YouTube Data API Key **不放客户端**（v1.0 由服务端聚合）

## 9. 验收标准（v1.0.0 发布前）

- [ ] 支持 20–30 个审核工具
- [ ] 至少支持 Homebrew Formula / Cask / mise 三类
- [ ] 8 个 Stage 0 工具安装和检测全部通过
- [ ] 不存在任意远程 Shell 执行能力
- [ ] 所有安装日志包含来源、版本、结果
- [ ] 所有安装包使用 HTTPS
- [ ] 官方安装包支持 SHA-256 + 签名校验
- [ ] 中英文完整可用
- [ ] 浅色 / 深色 / 跟随系统完整可用
- [ ] 教程内容都有来源 URL
- [ ] 离线可以浏览缓存目录
- [ ] Sparkle 应用内更新成功
- [ ] 签名错误版本被拒绝安装
- [ ] DMG 通过签名 + 公证 + Gatekeeper
- [ ] 干净 Mac 安装通过
- [ ] 没有把本地测试结果冒充线上发布结果

## 10. 后续版本

- v1.1：单工具自动更新、版本锁定、收藏导出、终端命令复制
- v1.5：项目级工具环境、`.tool-versions` / `.mise.toml` 集成
- v2.0：云账号、团队策略、私有目录、内容审核后台

## 11. 评审记录

| 日期 | 评审人 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-08-09 | Coordinator (Mavis) | 初稿 | 等待阶段 0 验收 |

## 12. 变更记录

| 日期 | 变更 | 作者 |
| --- | --- | --- |
| 2026-08-09 | 初版 | Coordinator |
