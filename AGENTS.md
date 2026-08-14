# Coding Tools · Agent 协作说明

> **给所有 AI / 自动化 Agent 看的入口。**
> 人类用户不会反复交代「推 GitHub / 我来升版」——参考智余项目的协作习惯。

详细发版流程见：[docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md)
多代理协作文档：[.multi-agent-collaboration/](./.multi-agent-collaboration/)

---

## 1. 项目身份

| 项 | 值 |
| --- | --- |
| 本地根目录 | `…/自研软件/Coding Tools` |
| 远程 | `https://github.com/yancyfeng999-star/coding-tools.git` |
| 默认分支 | `main` |
| Mac 工程 | `Apps/Mac/`（Tuist + Xcode，Scheme `CodingTools`） |
| 发版脚本 | `Apps/Mac/scripts/release.sh` |
| 版本权威源 | `Apps/Mac/Sources/App/Info.plist` 的 `CFBundleShortVersionString` |

---

## 2. 角色与多代理协作

Coding Tools 采用「主代理 + 3 个边界清晰的子代理」并行模式，详见开发计划 §13。

| 角色 | 负责 | 不可修改 |
| --- | --- | --- |
| 主代理 Coordinator | 边界、Domain、集成、收口 | — |
| 子代理 A：Catalog + Installer | Catalog / ManifestSecurity / Installers / ProcessExecution / Detection | 主 UI / Sparkle / 发布脚本 |
| 子代理 B：UI + Content + Localization | UI / Content / Localization / Theme | 安装执行器 / 签名 / Appcast |
| 子代理 C：Release + Update + Security | Updates / Scripts / .github/workflows / docs/RELEASE_WORKFLOW / docs/SECURITY_MODEL | 业务目录 / 主界面 / 安装逻辑 |

每个里程碑结束派独立只读 Reviewer + QA 子代理。

---

## 3. 默认行为（铁律）

| 场景 | Agent 必须做 | 不要做 |
| --- | --- | --- |
| 修 bug / 小功能完成 | `./scripts/release.sh` 走完整发版 | 问用户「要不要推？」 |
| 用户说「上传 / 整理好 / 推送」 | 走完整发版（升版 + 包 + tag + Release） | 只 commit 不发版 |
| 纯文档 / 纯 UI 调整 | commit + `git push origin main` | 不必为纯改动升版本号 |
| 用户明确说「不要发版 / 先别推」 | 遵守，本地改完停住 | — |
| 涉及远程 Shell / sudo | **禁止**；改用 Homebrew / mise / 官方包适配器 | 拼接任何 shell 字符串 |
| 涉及用户隐私 / 密钥 | 走既有密钥存储；日志脱敏 | 写入普通 JSON / commit / 截图 |

---

## 4. 仓库与路径

本机数据（排障用，**勿提交**）：

| 内容 | 路径 |
| --- | --- |
| 设置 | `~/Library/Application Support/CodingTools/settings.json` |
| 密钥 | `~/Library/Application Support/CodingTools/secrets.vault` |
| 日志 | `~/Library/Logs/CodingTools/app.log` |
| SQLite | `~/Library/Application Support/CodingTools/store.sqlite` |
| 目录缓存 | `~/Library/Caches/CodingTools/catalog/` |

---

## 5. 标准交付闭环

```text
查清问题 → 改代码 → 本地编译通过
    → git commit（清晰说明）
    → cd Apps/Mac && NOTES="一句话中文变更" ./scripts/release.sh
    → 回报：版本号 + Release 链接
```

`release.sh` 计划行为（阶段 7 接入 Sparkle 后实现）：

1. patch 升版
2. Tuist generate + Release 打包
3. 写 CHANGELOG 段 + 提交 `release: x.y.z (build n)`
4. `git push` + tag
5. `gh release create` 上传 DMG / ZIP / SHA256SUMS

---

## 6. 常用命令

```bash
# 仓库根
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"

# 生成 Xcode 工程
cd Apps/Mac
tuist install
tuist generate

# 编译检查
xcodebuild -scheme CodingTools -configuration Debug \
  -derivedDataPath ./build/DerivedData build

# 测试
./scripts/run-tests.sh

# 正式发版
NOTES="修复 xxx" ./scripts/release.sh

# 仅打包、不推远程
SKIP_PUBLISH=1 NOTES="试包" ./scripts/release.sh
```

需要 `gh` 已登录（`gh auth status`），且对 `yancyfeng999-star/coding-tools` 有写权限。

---

## 7. 架构速查

```text
Apps/Mac/Sources/
  Domain/                # 模型：Tool, InstallOption, Installation, ContentItem, OperationLog, CatalogSnapshot
  Catalog/               # 工具目录解析、搜索、分类
  ManifestSecurity/      # 目录签名验证、过期检测、撤销列表
  Installers/            # Homebrew / mise / 官方安装包 Adapter
  ProcessExecution/      # 受控进程执行（强类型参数、取消、超时、日志）
  Detection/             # 工具检测、版本检测、架构检测
  Launching/             # 工具启动（NSWorkspace / CLI / 浏览器）
  Content/               # 教程 / 视频元数据同步与缓存
  Persistence/           # SQLite 持久化
  Localization/          # 中英文 + 运行时切换
  Theme/                 # 浅色 / 深色 / 跟随系统
  Updates/               # Sparkle 集成
  App/                   # AppModel, CodingToolsApp, AppDelegate, MenuBarExtra
  UI/                    # SwiftUI 视图（首页 / 工具目录 / 详情 / 安装 / 教程）
```

- 入口：`CodingToolsApp` → `AppModel` → SwiftUI 主窗口 + MenuBarExtra
- 安装主链：`AppModel` → `Installers` → `ProcessExecution` → `OperationLog`
- 目录主链：`AppModel` → `Catalog` → `ManifestSecurity` → `Persistence`

---

## 8. 关键约束（红线）

- **禁止** 远程 Shell：目录 schema 中没有 `command` / `script` / `sudo` / `pipe` / `redirect` / `postInstall` 字段
- **禁止** 静默 sudo：所有需要授权的步骤必须显式
- **禁止** 自动修改 `.zshrc` / `PATH`
- **禁止** 下载视频、绕过付费内容
- **禁止** 把 API Key 放入客户端（YouTube Data API 走服务端）
- **必须** 区分「本地构建通过」「签名通过」「公证通过」「Release 发布」「应用内更新通过」五种证据状态
- **必须** 校验 Bundle ID、Team ID、SHA-256、签名
- **必须** 写 OperationLog（来源、版本、结果、退出码、redactedOutput）

---

## 9. 已知坑（占位）

> 本节将在开发过程中积累。当前项目尚未启动实现，暂无记录。

---

## 10. 改代码约定

- 少改无关文件
- 中文用户面向文案优先；代码注释中英都行
- Commit message：`feat:` / `fix:` / `chore:` / `docs:` + 一句说清楚
- 发版 NOTES 用**中文短句**，会出现在 CHANGELOG / Release notes
- 不要把 `build/`、DerivedData、密钥、临时截图提交进库
- 不在 `Sources/` 里写 `print`；使用结构化日志

---

## 11. 完成后怎么跟用户说

```text
已发版 0.x.y（build n）
Release: https://github.com/yancyfeng999-star/coding-tools/releases/tag/v0.x.y
应用内「检查更新」或装 DMG 即可。
```

**不要**再写：「请你本地升版 / 请你自己 push / 需要的话我可以帮你发版」。

---

## 12. 相关文档

| 文档 | 内容 |
| --- | --- |
| [docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md) | 发版详细步骤 |
| [docs/PRODUCT_SPEC.md](./docs/PRODUCT_SPEC.md) | 产品合同 |
| [docs/SECURITY_MODEL.md](./docs/SECURITY_MODEL.md) | 安全模型 |
| [docs/CATALOG_SCHEMA.md](./docs/CATALOG_SCHEMA.md) | 目录 Schema |
| [docs/RELEASE_WORKFLOW.md](./docs/RELEASE_WORKFLOW.md) | 发版流程 |
| [docs/QA_MATRIX.md](./docs/QA_MATRIX.md) | 测试矩阵 |
| [docs/STAGE0_TOOLS.md](./docs/STAGE0_TOOLS.md) | 8 个 Stage 0 工具 |
| [README.md](./README.md) | 项目入口 |
| [PRODUCT.md](./PRODUCT.md) | 产品定义 |
| [CHANGELOG.md](./CHANGELOG.md) | 版本历史 |
| [PROJECT_STATUS.md](./PROJECT_STATUS.md) | 阶段状态 |
