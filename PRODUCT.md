# Coding Tools · 产品定义

> 一句话：把开发工具的「发现 → 验证 → 安装 → 启动 → 学习 → 更新」装进一个签名化、零任意 Shell 的 macOS 工具中心。

## 目标

帮助 macOS 开发者：

1. **可信任地发现** Git、Node、Python、Go、Rust、IDE、数据库等开发工具。
2. **看清楚来源** 每个工具的安装包哈希、Bundle ID、Team ID、官方地址。
3. **不踩坑地安装** 仅支持 Homebrew / mise / 官方 DMG/PKG；安装前显示预览。
4. **直接启动** 已安装工具一键打开。
5. **持续学习** 官方文档 + 精选文章 + 视频元数据。
6. **不自己更新** Coding Tools 自身用 Sparkle 2 自动安全更新；工具更新分开。

## 不是

- 不是万能安装器（不接管未审核工具）
- 不是 IDE（不写代码）
- 不是 Homebrew 替代品（不重新发明 CLI）
- 不是内容站点（不抓取、不二次分发视频和文章）
- 不是后台服务（不静默启停用户的数据库、Docker）

## 用户类型

| 用户 | 痛点 | Coding Tools 怎么解决 |
| --- | --- | --- |
| 新 macOS 开发者 | 不知道该装哪些工具、装错来源 | 推荐清单 + 来源校验 |
| 全栈工程师 | 同时维护 Node/Python/Go 版本混乱 | mise 适配器 + 项目级指引 |
| 团队 Lead | 新人环境配置不一致 | 统一目录 + 统一来源 |
| 老用户 | 工具更新散落各处 | 应用内更新检测 + 启动器 |

## 核心用户动作

```text
发现工具 → 查看介绍 → 安装 → 启动 → 学习
```

每个动作都有强类型参数；任何一步都不允许「执行任意 Shell」。

## 范围（v1.0.0）

**支持**：

- macOS 14 Sonoma 及以上
- Apple Silicon + Intel Universal Binary
- 简体中文 + English
- 浅色 / 深色 / 跟随系统
- 20–30 个审核过的工具
- Homebrew Formula + Cask + mise + 官方 DMG/ZIP
- Sparkle 2 应用内自动更新
- 教程知识库（只存元数据 + 原文链接）

**不支持**（v1.0.0）：

- 任意远程 Shell / sudo 自动执行
- 视频下载 / 二次分发
- 付费内容抓取
- 全局 `brew upgrade` / `mise upgrade` 自动执行
- Windows / Linux
- 云账号 / 团队策略

详见 [docs/PRODUCT_SPEC.md](./docs/PRODUCT_SPEC.md)。

## 风险与边界

| 风险 | 缓解 |
| --- | --- |
| 目录被篡改 | HTTPS + Ed25519 + SHA-256 + 过期 + 撤销列表 |
| Homebrew 未安装 | 不自动执行安装脚本；显示官方说明、复制命令 |
| 工具版本漂移 | 记录适用版本、过期内容标识 |
| 用户隐私 | 本机数据库；日志脱敏；不收集遥测 |
| 公证失败 | 区分本地 / 签名 / 公证 / 发布证据 |

## 未来版本

- v1.1：单工具自动更新、版本锁定、失败诊断
- v1.5：项目级工具环境（`.tool-versions` / `.mise.toml`）
- v2.0：云账号、团队策略、私有目录

## 参考

- [开发计划](./CODING_TOOLS_MACOS_DEVELOPMENT_PLAN.md)
- [产品合同](./docs/PRODUCT_SPEC.md)
- [安全模型](./docs/SECURITY_MODEL.md)
