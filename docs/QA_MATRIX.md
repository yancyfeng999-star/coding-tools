# Coding Tools · 测试矩阵

> v1.0.0 发布前必须通过全部测试。分四层：单元测试、集成测试、真实 macOS 测试、更新测试。

## 1. 单元测试

| 模块 | 覆盖 |
| --- | --- |
| Domain | Tool、InstallOption、Installation、ContentItem、OperationLog、CatalogSnapshot 模型 |
| Catalog | 解析、搜索、分类、过滤 |
| ManifestSecurity | 签名验证、过期检测、撤销列表 |
| Installers | enum 解析、参数校验、风险等级 |
| ProcessExecution | 命令构造、参数化、超时、取消、退出码、脱敏 |
| Detection | 路径检测、版本检测、架构检测 |
| Launching | 启动参数构造 |
| Persistence | SQLite 迁移、CRUD |
| Localization | 字符串查找、回退链 |
| Theme | 浅/深/系统切换 |

每个测试必须有：

- 测试名（描述行为）
- Arrange / Act / Assert
- 至少一个失败用例

### Agent 环境检查（确定性）

| Case | Expected |
| --- | --- |
| `/usr/bin/true` × 100 | no hang |
| 32 concurrent exits | all complete |
| version command exceeds 8s | timedOut terminal state |
| `~/.local/bin/claude` | installed + absolute path execution |
| `.grok/bin` and `.local/bin` same realpath | one installation, no conflict |
| standalone Codex + ChatGPT embedded Codex | two installations, preferred PATH marked |
| npm 200 / malformed / 500 / timeout | loaded / invalidResponse / httpStatus / timedOut |
| Hermes local 0.20.0 vs PyPI 0.19.0 | localAhead, no downgrade action |
| one tool fails | remaining cards complete |
| refresh with cache | stale value remains visible |
| bulk update with second item failing | sequential; first/third outcomes preserved |

Evidence layers: `local_tests` = `DomainTests InstallerTests LatestVersionTests AgentEnvironmentTests`. `local_build` is CI compile only. `runtime_verified`, `remote_release`, `update_verified`, `user_installed` stay `not_run` until those gates actually run.

## 2. 集成测试

| 场景 | 验证点 |
| --- | --- |
| Homebrew 模拟执行 | 解析 brew 输出、状态映射 |
| mise 模拟执行 | 解析 mise 输出 |
| 安装进程退出码 | 0 / 非 0 / 超时区分 |
| 安装中取消 | 子进程被 kill；UI 状态正确 |
| 下载失败 | 重试 / 失败提示 |
| 哈希不一致 | 拒绝安装 + 提示 |
| Bundle ID 不一致 | 拒绝安装 + 提示 |
| Team ID 不一致 | 拒绝安装 + 提示 |
| 数据库损坏 | 自动备份 + 恢复 |
| 断网恢复 | 重试机制 |
| App 重启恢复队列 | 队列持久化 |

## 3. 真实 macOS 测试

### 3.1 系统矩阵

| 系统 | 架构 | 状态 |
| --- | --- | --- |
| macOS 14 Sonoma | Apple Silicon | ⬜ |
| macOS 14 Sonoma | Intel | ⬜ |
| macOS 15 Sequoia | Apple Silicon | ⬜ |
| macOS 15 Sequoia | Intel | ⬜ |
| macOS 26 (latest) | Apple Silicon | ⬜ |

### 3.2 环境矩阵

| 环境 | 状态 |
| --- | --- |
| 未装 Homebrew | ⬜ |
| 已装 Homebrew | ⬜ |
| 已装 mise | ⬜ |
| 未装 mise | ⬜ |
| /Applications 不可写 | ⬜ |
| 用户自定义安装目录 | ⬜ |
| 只读 /Applications | ⬜ |
| 低权限用户（无 admin） | ⬜ |
| 网络断开 | ⬜ |
| Gatekeeper 严格模式 | ⬜ |
| App Translocation | ⬜ |
| 全新用户账户 | ⬜ |

### 3.3 工具测试（Stage 0）

详见 [STAGE0_TOOLS.md](./STAGE0_TOOLS.md) 验收清单。

## 4. 更新测试矩阵

| 场景 | 预期 | 验证 |
| --- | --- | --- |
| 新版本正常 | 后台下载并安装 | ⬜ |
| 签名错误 | 拒绝安装 | ⬜ |
| Appcast 被篡改 | 拒绝加载 | ⬜ |
| 下载中断 | 可恢复 / 重新下载 | ⬜ |
| 磁盘空间不足 | 保留旧版本 + 提示 | ⬜ |
| 应用目录不可写 | 提示用户授权 | ⬜ |
| 用户正在使用工具 | 不强制退出 | ⬜ |
| 更新后首次启动失败 | 保留诊断信息 | ⬜ |
| 用户关闭自动更新 | 不后台安装 | ⬜ |
| 无网络 | 使用当前版本正常运行 | ⬜ |
| 旧版本可检测新版本 | 通知用户 | ⬜ |
| 用户手动触发 | 立即检查 + 下载 + 提示 | ⬜ |
| 增量更新 | 应用 delta patch | ⬜ |

## 5. 多语言测试

| 语言 | UI 字符串 | 工具名称 | 教程标题 | 状态 |
| --- | --- | --- | --- | --- |
| 简体中文 | 100% | 100% | 100% | ⬜ |
| English | 100% | 100% | 100% | ⬜ |
| 缺失翻译回退 | en → zh-Hans | — | — | ⬜ |

## 6. 主题测试

| 主题 | 浅色截图 | 深色截图 | 菜单栏图标 | 状态 |
| --- | --- | --- | --- | --- |
| 浅色 | ⬜ | — | ⬜ | ⬜ |
| 深色 | — | ⬜ | ⬜ | ⬜ |
| 跟随系统 | ⬜ | ⬜ | ⬜ | ⬜ |
| 高对比度 | ⬜ | ⬜ | ⬜ | ⬜ |

## 7. 辅助功能测试

| 项 | 状态 |
| --- | --- |
| VoiceOver 标签完整 | ⬜ |
| 动态字体支持 | ⬜ |
| 键盘导航 | ⬜ |
| 颜色对比 ≥ WCAG AA | ⬜ |

## 8. 性能基线

| 指标 | 目标 | 验证 |
| --- | --- | --- |
| 冷启动 < 2s | ⬜ | ⬜ |
| 目录加载 < 1s | ⬜ | ⬜ |
| 工具列表滚动 60fps | ⬜ | ⬜ |
| 内存 < 200MB（空闲） | ⬜ | ⬜ |
| 内存 < 500MB（安装中） | ⬜ | ⬜ |

## 9. 安全审计

| 项 | 状态 |
| --- | --- |
| 无任意远程 Shell | ⬜ |
| 日志脱敏覆盖所有路径 | ⬜ |
| 目录签名验证 | ⬜ |
| 安装包 SHA-256 校验 | ⬜ |
| Bundle ID / Team ID 校验 | ⬜ |
| 密钥不入库 | ⬜ |
| App 沙盒开启 | ⬜ |
| 公证通过 | ⬜ |

## 10. 证据状态（必须区分）

```text
local_build_passed        本地 Debug / Release 构建通过
local_tests_passed        本地单元 + 集成测试通过
signed_artifact_created   Developer ID 签名通过
notarization_passed       Apple 公证通过 + Staple
release_asset_published   GitHub Release 资产已上传
in_app_update_passed      Sparkle 应用内更新成功
clean_machine_install_passed  干净 Mac 首次安装成功
```

**本地构建通过 ≠ 公证通过 ≠ 发布成功 ≠ 应用内更新成功**。每项必须独立报告。

## 11. 评审记录

| 日期 | 评审人 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-08-09 | Coordinator (Mavis) | 初稿 | 阶段 1 起 Reviewer/QA 子代理按此矩阵验收 |
