# Coding Tools macOS：完整开发计划

## 一、项目结论

建议把产品定位为：

> 一个“可信安装源 + 教程知识库 + 工具启动器 + 环境检测 + 自动更新”的 macOS 开发者工具中心。

暂定名称：Coding Tools。

第一版不追求“所有工具都支持”，而是先建立安全、可扩展的工具目录系统：

- 首发平台：macOS
- 支持架构：Apple Silicon 与 Intel Universal Binary
- 建议最低系统：macOS 14 Sonoma+
- 首发语言：简体中文、英文
- 主题：浅色、深色、跟随系统
- 应用更新：Sparkle 2 + GitHub Releases
- 工具安装：Homebrew、mise、官方安装包
- 内容：官方文档、文章、博客、视频
- 第一版工具数量：20–30 个
- 第一版目标：可安全安装、可启动、可查看教程、可自动更新
- 暂不支持：任意远程脚本、静默 sudo、自动执行未知 Shell、视频下载、破解付费内容

当前 Coding Tools 目录是空的，本轮只输出方案，不修改代码、不初始化工程、不发布版本。

---

## 二、类似项目调研

目前市场上有很多单点工具，但没有发现一个同时覆盖工具安装、版本检测、教程、视频、启动和应用更新的完整 macOS 产品。这个判断是基于以下项目能力差异得出的产品推断。

| 项目 | 擅长能力 | 不足 |
|---|---|---|
| Homebrew | 命令行包管理、Formula、Cask | 没有教程知识库和统一图形化工作流 |
| Applite | Homebrew 图形化安装、卸载、更新 | 主要是 GUI 包管理器 |
| Cork | Homebrew 图形化管理 | 不负责内容、课程、工作流 |
| mise | Node、Python、Go 等工具版本管理 | 不是完整桌面工具目录 |
| asdf | 多运行时、多版本管理 | 学习内容和桌面应用启动能力弱 |
| JetBrains Toolbox | JetBrains 产品安装、更新、启动 | 仅覆盖 JetBrains 生态 |
| DevDocs | 文档搜索和离线文档 | 不负责工具安装 |
| Dash | API 文档和代码片段 | 不负责工具安装和环境检测 |
| DevPod / Dev Containers | 开发环境容器化 | 复杂度更高，不适合作为第一版入口 |

参考资料：

- [Homebrew Manpage](https://docs.brew.sh/Manpage)
- [Homebrew Adding Software](https://docs.brew.sh/Adding-Software)
- [mise 官方文档](https://mise.jdx.dev/)
- [DevDocs About](https://devdocs.io/about)
- [Dash](https://kapeli.com/dash)
- [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/)
- [Applite](https://github.com/milanvarady/applite)
- [Cork](https://corkmac.app/)

产品差异化应是：

1. 用户能知道工具是什么、怎么用。
2. 用户能看到推荐学习路径。
3. 用户能确认安装来源和权限。
4. 安装后可以直接启动或检测。
5. 工具、教程、版本、状态统一管理。

---

## 三、参考“智余”和“智额”的结论

已经对两个项目进行了只读审计。

### 可以复用

来自 [智余](</Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余>)：

- SwiftUI + AppKit 混合架构
- MenuBarExtra 菜单栏入口
- 语言枚举和运行时语言切换
- 浅色、深色、跟随系统
- NSApp.appearance 与 SwiftUI 外观同步
- 菜单栏图标主题切换处理
- Tuist 工程组织方式

来自 [智额](</Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智额>)：

- AppVersion 与版本比较逻辑
- GitHub Release 版本过滤
- 可注入网络客户端的测试结构
- 测试目录和 CI 组织方式
- 语言回退机制
- RTL 语言预留方式

### 不建议复用

两个项目中都存在自定义的静默 PKG 替换安装逻辑：

- 解包 PKG
- 删除旧 App
- 移动新 App
- ditto 覆盖
- 移除 quarantine
- 重新打开 App

相关文件：

- [智余 UpdateChecker.swift](</Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余/Apps/Mac/Sources/Infrastructure/UpdateChecker.swift>)
- [智余 PackageSilentInstaller.swift](</Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余/Apps/Mac/Sources/Infrastructure/PackageSilentInstaller.swift>)
- [智额 GitHubReleaseChecker.swift](</Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智额/Apps/Mac/Sources/Infrastructure/Update/GitHubReleaseChecker.swift>)
- [智额 SilentPkgInstaller.swift](</Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智额/Apps/Mac/Sources/Infrastructure/Update/SilentPkgInstaller.swift>)

主要风险：

- 没有完整验证应用签名
- 没有可靠的 Team ID、Bundle ID 校验
- 没有真正的原子回滚
- 依赖安装目录可写
- 可能破坏用户当前版本
- 通过移除 quarantine 绕过系统安全提示
- 不能代表正式发行级的静默更新

新产品不继续使用这条路径。

---

## 四、核心技术路线

### 4.1 应用自动更新

推荐：

> Sparkle 2 + HTTPS Appcast + GitHub Releases

Sparkle 支持应用签名、EdDSA 更新签名、版本检测、后台下载、安装和更新提醒。[Sparkle 官方文档](https://sparkle-project.github.io/documentation/)

发布结构：

~~~text
GitHub Release
├── CodingTools-1.0.0.dmg       # 首次安装和手动下载
├── CodingTools-1.0.0.zip       # Sparkle 应用内更新
├── CodingTools-1.0.0.sha256    # 校验信息
└── appcast.xml                 # Sparkle 更新清单
~~~

应用更新流程：

1. 应用后台检查 Appcast。
2. 下载新版本。
3. 校验 HTTPS、EdDSA 和 Apple 代码签名。
4. 用户继续使用当前版本。
5. 在合适时机完成安装。
6. 正常退出后替换应用。
7. 自动重新打开。
8. 保留配置、收藏、学习进度和本地数据库。

“静默更新”不能承诺在所有情况下绝对无感。若应用安装在不可写目录、系统需要授权、签名校验失败或用户关闭自动更新，必须显示明确提示。普通 App Bundle 更新适合后台更新；PKG 更新通常需要用户授权，不适合作为静默升级方案。[Sparkle Package Updates](https://sparkle-project.github.io/documentation/package-updates/)

默认策略：

~~~text
后台检查：开启
后台下载：开启
后台安装：开启
强制退出用户程序：禁止
需要权限：显示授权提示
签名校验失败：禁止安装
更新失败：保留旧版本
~~~

### 4.2 工具安装

工具安装分为四层。

第一层：已安装工具检测：

- Homebrew Formula
- Homebrew Cask
- mise
- asdf
- /Applications
- 常见 CLI 路径
- 自定义路径
- 当前版本
- CPU 架构
- 可执行文件路径
- Bundle ID
- Team ID

第二层：Homebrew，适合 Git、Node、Python、Go、Rust、jq、ripgrep、fd、bat、gh、pnpm、uv、iTerm2、Visual Studio Code、Docker Desktop、Postman 等。

第三层：mise，适合 Node.js、Python、Go、Rust、Java、Bun、Deno、Ruby、PHP 等运行时。mise 主要负责工具版本和开发环境，不应被当作传统桌面应用包管理器。[mise Dev Tools](https://mise.jdx.dev/dev-tools/)

第四层：官方 DMG、ZIP 或 PKG。必须记录官方 HTTPS 地址、SHA-256、Bundle ID、Team ID、版本规则、支持架构、安装类型和授权要求。

应用不直接拼接 Shell 字符串，而使用强类型参数：

~~~swift
enum InstallAction {
    case homebrewFormula(name: String)
    case homebrewCask(name: String)
    case miseTool(name: String, version: String?)
    case officialArtifact(url: URL, sha256: String, bundleID: String?)
}
~~~

远程目录禁止出现以下字段：

~~~text
command
shell
script
sudo
pipe
redirect
postInstall
environment
workingDirectory
~~~

---

## 五、产品功能规划

### 5.1 首页

首页展示：

- 最近使用工具
- 推荐工具
- 待安装工具
- 可更新工具
- 最近阅读教程
- 最近观看视频
- 环境异常
- 应用版本状态

核心目标：

~~~text
发现工具 → 查看介绍 → 安装 → 启动 → 学习
~~~

### 5.2 工具目录

每个工具包含：

- 名称、Logo、简介
- 工具类别和标签
- 适合人群
- 安装方式
- 当前版本和推荐版本
- 已安装状态
- 支持架构
- 官方网站和官方文档
- 相关教程和视频
- 启动按钮
- 检测按钮
- 卸载入口
- 风险说明

分类建议：

- 编辑器
- 终端
- Git 与协作
- Node / Python / Go / Rust
- 数据库
- API 调试
- Docker 与容器
- AI 编程
- 前端开发
- 后端开发
- 运维和云服务
- 命令行效率工具

### 5.3 安装流程

安装前显示预览：

~~~text
工具：Node.js
版本：22.x
来源：Homebrew Formula
操作：brew install node
权限：当前用户权限
下载：官方 Homebrew 源
预计变化：安装 CLI 和运行时
~~~

用户确认后：

1. 检测前置条件。
2. 确认安装源。
3. 显示安装队列。
4. 执行受控进程。
5. 实时显示输出。
6. 支持取消。
7. 安装完成后重新检测。
8. 验证版本、路径和架构。
9. 写入结构化日志。
10. 提供启动或打开教程按钮。

不能做：

- 默认执行 sudo
- 自动修改 .zshrc
- 自动覆盖用户 PATH
- 自动添加未知 Homebrew tap
- 自动修改 SSH、Git、Docker 配置
- 自动执行 post-install 脚本
- 自动升级所有工具

### 5.4 工具启动

- CLI 工具：打开内置终端命令提示或复制命令
- App 工具：通过 NSWorkspace 启动
- 项目工具：打开项目目录
- 浏览器工具：打开官方 URL
- 服务型工具：第一版只展示说明，不自动启停后台服务

菜单栏快速入口：

- 最近使用
- 收藏工具
- 一键打开终端
- 一键打开编辑器
- 检查更新
- 打开主窗口

### 5.5 教程和知识库

内容来源：

#### 官方文档

- 官方文档
- 官方博客
- 官方发布说明
- 官方 GitHub README
- 官方 RSS / Atom

#### 精选文章

记录：

- 标题
- 作者
- 原文地址
- 来源网站
- 发布日期
- 适用版本
- 摘要
- 标签
- 难度
- 是否推荐

#### 视频

第一版只保存元数据：

- YouTube 视频 ID
- 标题
- 作者
- 缩略图
- 原始链接
- 标签
- 简介
- 更新时间

使用官方嵌入或外部浏览器打开，不下载、不重新托管、不绕过付费内容。[YouTube Player Parameters](https://developers.google.com/youtube/player_parameters)

YouTube Data API 未来由服务端统一调用，不能把 API Key 放入 macOS 客户端。[YouTube Search API](https://developers.google.com/youtube/v3/docs/search/list)

### 5.6 离线能力

离线可以：

- 查看已经缓存的工具目录
- 查看收藏工具
- 查看最近教程
- 查看本地学习进度
- 查看已经安装工具
- 启动已经安装的 App
- 查看上次同步时间

离线禁止：

- 安装新工具
- 下载未缓存内容
- 接受过期或被撤销的安装清单
- 使用无法验证的远程安装包

---

## 六、总体架构

~~~mermaid
flowchart LR
    UI["SwiftUI 主窗口<br/>MenuBarExtra"] --> APP["Application Services"]

    APP --> CATALOG["签名工具目录"]
    APP --> INSTALL["安装编排器"]
    APP --> PROBE["检测与健康检查"]
    APP --> LAUNCH["工具启动器"]
    APP --> CONTENT["内容同步"]
    APP --> UPDATE["Sparkle 应用更新"]

    INSTALL --> BREW["Homebrew Adapter"]
    INSTALL --> MISE["mise Adapter"]
    INSTALL --> ARTIFACT["官方安装包 Adapter"]

    CATALOG --> DB["SQLite + URLCache"]
    CONTENT --> DB

    UPDATE --> APPCAST["HTTPS Appcast"]
    APPCAST --> RELEASE["GitHub Releases / CDN"]
~~~

建议模块：

~~~text
Domain
Application
Catalog
ManifestSecurity
InstallerAdapters
ProcessExecution
Detection
Launching
Content
Persistence
Localization
Theme
Updates
Diagnostics
UI
~~~

---

## 七、建议项目目录

以下是进入开发后拟创建的结构：

~~~text
Coding Tools/
├── Apps/
│   └── Mac/
│       ├── Project.swift
│       ├── Tuist/
│       │   └── Package.swift
│       ├── Sources/
│       │   ├── App/
│       │   │   ├── CodingToolsApp.swift
│       │   │   ├── AppDelegate.swift
│       │   │   └── AppModel.swift
│       │   ├── Domain/
│       │   ├── Catalog/
│       │   ├── ManifestSecurity/
│       │   ├── Installers/
│       │   ├── ProcessExecution/
│       │   ├── Detection/
│       │   ├── Launching/
│       │   ├── Content/
│       │   ├── Persistence/
│       │   ├── Localization/
│       │   ├── Theme/
│       │   ├── Updates/
│       │   └── UI/
│       ├── Resources/
│       └── Tests/
├── Catalog/
│   ├── tools/
│   ├── content/
│   ├── schemas/
│   └── revocations/
├── Scripts/
│   ├── build.sh
│   ├── test.sh
│   ├── package-release.sh
│   ├── sign-release.sh
│   ├── notarize-release.sh
│   └── generate-appcast.sh
├── docs/
│   ├── PRODUCT_SPEC.md
│   ├── SECURITY_MODEL.md
│   ├── CATALOG_SCHEMA.md
│   ├── RELEASE_WORKFLOW.md
│   └── QA_MATRIX.md
└── .github/
    └── workflows/
~~~

---

## 八、核心数据模型

### Tool

~~~text
id
slug
name
localizedName
description
category
tags
homepageURL
documentationURL
installOptions
launchCapability
supportedArchitectures
minimumMacOS
status
~~~

### InstallOption

~~~text
type
source
packageName
versionRule
downloadURL
sha256
bundleID
teamID
requiresAuthorization
riskLevel
~~~

### Installation

~~~text
toolID
installedVersion
detectedPath
architecture
bundleID
teamID
lastCheckedAt
healthStatus
~~~

### ContentItem

~~~text
id
toolID
type
title
localizedTitle
summary
author
sourceURL
thumbnailURL
publishedAt
duration
license
tags
~~~

### OperationLog

~~~text
id
operationType
toolID
source
requestedVersion
resolvedVersion
startedAt
finishedAt
result
exitCode
redactedOutput
~~~

### CatalogSnapshot

~~~text
schemaVersion
catalogVersion
createdAt
expiresAt
keyID
signature
sha256
revokedItems
~~~

---

## 九、远程目录和安全设计

正式版不应把所有工具信息写死在 App 内。

建议流程：

~~~text
App 内置目录
        ↓
远程签名目录
        ↓
本地验证
        ↓
SQLite 缓存
~~~

目录必须包含：

- Schema 版本
- 目录版本
- 生成时间
- 过期时间
- 签名
- Key ID
- 工具来源
- 下载地址
- 哈希
- Bundle ID
- Team ID
- 撤销列表

安全规则：

1. 目录只允许 HTTPS。
2. 目录必须使用 Ed25519 签名。
3. 签名失败不更新目录。
4. 过期目录只能浏览，不能发起安装。
5. 工具下载包必须校验 SHA-256。
6. App 必须校验代码签名。
7. 必须校验 Bundle ID 和 Team ID。
8. 不自动删除 quarantine。
9. 不把远程 JSON 当作 Shell 代码执行。
10. 日志必须过滤 Token、Cookie、环境变量和隐私路径。
11. 支持密钥轮换和撤销。
12. 目录更新和 App 更新分开处理。

---

## 十、首批工具范围

第一阶段选 20–30 个工具，而不是一次支持几百个。

### Stage 0 验证工具

先验证 8 个具有不同安装类型的工具：

- Git
- Node.js
- Python
- Go
- Rust
- Visual Studio Code
- Docker Desktop
- iTerm2

覆盖：

- Homebrew Formula
- Homebrew Cask
- mise Runtime
- GUI App
- CLI 工具
- 多架构工具
- 已安装检测
- 启动能力

### MVP 工具目录

后续可以加入：

- GitHub CLI
- jq
- ripgrep
- fd
- bat
- uv
- pnpm
- Bun
- Deno
- Java
- Postman
- OrbStack
- JetBrains Toolbox
- Cursor
- TablePlus
- DBeaver
- Xcode Command Line Tools
- Android Studio
- Kubernetes CLI
- Terraform

每增加一种安装来源，都必须增加对应测试和安全审查。

---

## 十一、自动更新设计

### 11.1 Coding Tools 自身更新

使用 Sparkle：

- 检查频率可配置
- 后台下载
- 用户空闲或正常退出时安装
- 支持测试版频道
- 支持安全更新
- 支持手动检查
- 支持暂停更新
- 支持失败重试
- 支持保留旧版本

发布必须经过：

1. Universal Build
2. Developer ID 签名
3. Hardened Runtime
4. DMG / ZIP 打包
5. Apple Notarization
6. Staple 公证票据
7. Appcast 签名
8. 干净机器安装
9. 应用内升级测试
10. 发布 GitHub Release

Apple 官方要求 macOS 分发软件进行签名和公证：

- [Apple Developer ID](https://developer.apple.com/developer-id/)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

### 11.2 工具自身更新

工具更新和应用更新必须分开。

第一版默认：

~~~text
工具发现更新：自动检查
工具下载：用户确认
工具安装：用户点击
批量升级：暂不默认开启
全局 brew upgrade：禁止自动执行
全局 mise upgrade：禁止自动执行
~~~

以后可增加：

- 单个工具自动更新
- 用户指定工具自动更新
- 夜间更新
- 失败自动恢复
- 更新前快照
- 版本锁定

---

## 十二、多语言和主题

### 多语言

第一版正式支持：

- 简体中文
- English

架构预留：

- 日语
- 韩语
- 法语
- 德语
- 西班牙语
- 葡萄牙语
- 俄语
- 阿拉伯语 RTL

不能把未经过人工验收的机器翻译标记为正式支持语言。

实现要求：

- 所有 UI 字符串进入 String Catalog
- 工具名称和教程标题允许独立翻译
- 用户可在 App 内切换语言
- 不依赖系统语言重启 App
- 缺失翻译回退英文，再回退中文
- 支持长文本、复数和日期格式
- RTL 语言不能只做字符串替换

### 主题

支持：

- 浅色
- 深色
- 跟随系统

要求：

- SwiftUI 内容与 AppKit 窗口同步
- 菜单栏图标同步切换
- Web 内容区域同步主题
- 不使用固定黑白颜色
- 所有颜色使用语义 Token
- 截图验证浅色和深色
- 适配系统高对比度模式

---

## 十三、子代理并行开发方案

本轮已经用 3 个子代理并行完成项目审计、更新机制研究和产品架构研究。进入实际开发后，继续采用以下分工。

### 主代理：Coordinator / Integrator

负责：

- 产品边界
- Domain 模型
- 模块接口
- 代码集成
- 冲突解决
- 最终验收
- 不作为唯一 Reviewer

### 子代理 A：Catalog + Installer

负责目录和安装核心：

~~~text
Catalog/
ManifestSecurity/
Installers/
ProcessExecution/
Detection/
~~~

交付：

- 工具模型
- 目录 Schema
- Homebrew Adapter
- mise Adapter
- 官方安装包 Adapter
- 安装预览
- 安装日志
- 工具检测
- 单元测试和集成测试

不修改：

- 主 UI
- Sparkle
- 发布脚本

### 子代理 B：UI + Content + Localization

负责：

~~~text
UI/
Content/
Localization/
Theme/
~~~

交付：

- 首页
- 工具列表
- 工具详情
- 安装进度
- 教程页面
- 视频页面
- 收藏
- 搜索
- 中英文
- 浅色深色
- 菜单栏入口

不修改：

- 安装执行器
- 代码签名
- Appcast

### 子代理 C：Release + Update + Security

负责：

~~~text
Updates/
Scripts/
.github/workflows/
docs/RELEASE_WORKFLOW.md
docs/SECURITY_MODEL.md
~~~

交付：

- Sparkle 接入
- Appcast 生成
- EdDSA 签名
- Developer ID 签名脚本
- Notarization 脚本
- DMG / ZIP 构建
- GitHub Release 流程
- 更新失败测试
- 发布验收清单

不修改：

- 工具业务目录
- 主界面布局
- 工具安装逻辑

### Reviewer / QA

每个里程碑结束后，再派一个新的只读 Reviewer + QA 子代理：

- 检查模块边界
- 检查是否执行任意 Shell
- 检查测试缺口
- 检查 UI 截图
- 检查签名和公证
- 检查是否把本地通过误报成发布通过

---

## 十四、开发阶段和时间表

### 阶段 0：产品和安全契约

预计：3–5 个工作日。

交付：

- PRODUCT_SPEC.md
- 工具清单
- 安装源优先级
- 目录 JSON Schema
- 安全威胁模型
- 更新策略
- 内容版权规则
- 8 个 Stage 0 工具验证表

验收：

- 任何远程目录都不能构造任意 Shell。
- 每个工具都有明确来源。
- 每个安装方式都有失败处理方案。
- 明确哪些功能第一版不做。

### 阶段 1：工程骨架

预计：3–5 个工作日。

交付：

- Tuist 工程
- SwiftUI 主窗口
- MenuBarExtra
- Settings
- SQLite 初始化
- CI 测试
- 基础日志
- 中英文框架
- 浅色深色框架

验收：

- Debug 可以启动。
- Release 可以构建。
- Apple Silicon 构建通过。
- Intel 构建通过。
- 空目录和空数据库可以正常启动。

### 阶段 2：目录和安全目录

预计：1–2 周。

交付：

- 工具模型
- 目录解析
- Schema 校验
- 远程目录下载
- 签名验证
- 本地缓存
- 过期检测
- 撤销列表
- 工具搜索和分类

验收：

- 篡改目录不能载入。
- 过期目录不能发起安装。
- 离线可以查看上次成功目录。
- 目录缺字段时有明确错误。
- 缺少翻译时正确回退。

### 阶段 3：安装、检测和启动

预计：2–3 周。

交付：

- Homebrew Formula 安装
- Homebrew Cask 安装
- mise 安装
- 官方 DMG / ZIP 安装
- 安装队列
- 取消操作
- 失败重试
- 版本检测
- 架构检测
- App 启动
- CLI 状态检测

验收：

- 8 个 Stage 0 工具真实测试。
- 安装前显示来源、版本和风险。
- 安装后能正确检测版本。
- 失败不会留下半安装状态。
- 不修改用户 Shell 配置。
- 不使用静默 sudo。
- 不执行远程 Shell。

### 阶段 4：主界面

预计：1.5–2 周，可与阶段 3 并行。

交付：

- 首页
- 工具目录
- 工具详情
- 安装弹窗
- 安装队列
- 详情页启动按钮
- 收藏
- 最近使用
- 搜索
- 菜单栏快速入口

验收：

- 新用户无需阅读说明即可安装第一个工具。
- 安装状态与真实系统状态一致。
- App 重启后状态不丢失。
- 长文本和窗口缩放正常。
- 深浅色界面都通过截图验收。

### 阶段 5：内容中心

预计：1–1.5 周。

交付：

- 官方文档列表
- RSS / Atom 同步
- 文章详情
- 视频卡片
- 教程标签
- 阅读进度
- 收藏
- 原文跳转
- 内容缓存

验收：

- 所有内容都有原始 URL。
- 文章和视频来源可追溯。
- 视频不下载、不重新托管。
- 断网时能打开已缓存内容。
- 内容失败不影响工具安装。

### 阶段 6：多语言、主题和辅助功能

预计：3–5 个工作日。

交付：

- 中文
- 英文
- 系统语言选择
- 浅色
- 深色
- 跟随系统
- 菜单栏图标适配
- VoiceOver 标签
- 动态字体
- RTL 结构预留

验收：

- 语言切换不需要重启。
- 中英文没有硬编码遗漏。
- 窗口缩放和动态字体正常。
- 浅色、深色、系统模式分别截图验证。

### 阶段 7：应用自动更新和正式发布

预计：1–2 周。

交付：

- Sparkle 2
- Appcast
- EdDSA 签名
- GitHub Release
- DMG
- ZIP
- Developer ID 签名
- Notarization
- Staple
- 自动更新设置
- 手动检查更新
- 更新失败提示

验收：

- 旧版本可以检测新版本。
- 后台可以下载。
- 签名错误版本不会安装。
- 网络中断后可以恢复。
- 安装目录不可写时显示明确提示。
- 更新完成后数据和设置保留。
- 干净 Mac 可以安装。
- Gatekeeper 不出现异常警告。

### 阶段 8：内部 Beta 和稳定版

预计：1.5–2 周。

交付：

- QA 报告
- 崩溃日志
- 性能报告
- 安全审查报告
- 工具安装成功率
- 失败案例处理
- 用户反馈入口
- 发布说明
- 回滚预案

建议发布节点：

~~~text
v0.1.0  工程原型
v0.5.0  内部可用版
v0.9.0  内部 Beta
v1.0.0  第一版稳定发布
~~~

整体周期：

- 单人串行开发：约 9–12 周
- 主代理 + 3 个边界清晰的子代理并行：内部 Beta 约 6–8 周
- 稳定公开版：约 9–12 周

---

## 十五、测试计划

### 单元测试

覆盖：

- 版本比较
- 目录 Schema
- 目录签名
- 目录过期
- 撤销条目
- 安装动作解析
- 参数拼接
- 路径检测
- 版本检测
- 架构检测
- 语言回退
- 主题切换
- 数据库迁移
- 内容缓存

### 集成测试

覆盖：

- Homebrew 模拟执行
- mise 模拟执行
- 安装进程退出码
- 安装中取消
- 下载失败
- 哈希不一致
- Bundle ID 不一致
- Team ID 不一致
- 数据库损坏
- 断网恢复
- App 重启恢复队列

### 真实 macOS 测试

至少验证：

- macOS 14 Apple Silicon
- macOS 14 Intel
- 当前最新 macOS Apple Silicon
- 未安装 Homebrew
- 已安装 Homebrew
- /Applications 安装
- 用户自定义目录安装
- 只读目录
- 网络断开
- 低权限用户
- Gatekeeper
- App Translocation
- 全新用户账户

### 更新测试矩阵

| 场景 | 预期 |
|---|---|
| 新版本正常 | 后台下载并安装 |
| 签名错误 | 拒绝安装 |
| Appcast 被篡改 | 拒绝加载 |
| 下载中断 | 可恢复或重新下载 |
| 磁盘空间不足 | 保留旧版本并提示 |
| 应用目录不可写 | 提示用户授权 |
| 用户正在使用工具 | 不强制退出 |
| 更新后首次启动失败 | 保留诊断信息 |
| 用户关闭自动更新 | 不后台安装 |
| 无网络 | 使用当前版本正常运行 |

必须区分以下证据状态：

~~~text
local_build_passed
local_tests_passed
signed_artifact_created
notarization_passed
release_asset_published
in_app_update_passed
clean_machine_install_passed
~~~

本地构建通过，不等于已经完成公证、发布或应用内更新验收。

---

## 十六、主要风险和处理方式

### 1. 工具安装源不稳定

- 目录记录多个安装方案
- Homebrew 优先
- 官方安装包作为备用
- 每个工具设置最低可用版本
- 失败时允许用户打开官方页面手动安装

### 2. Homebrew 未安装

第一版不自动执行 Homebrew 官方远程安装脚本。

应用可以：

- 检测 Homebrew
- 显示官方安装说明
- 打开官方文档
- 复制经过确认的命令

以后如果实现自动引导，需要单独做安全设计。

### 3. macOS 权限和静默更新

- 普通 App 更新使用 Sparkle
- 需要授权时明确提示
- 不使用隐藏 sudo
- 不强制杀死用户进程
- 不承诺绝对静默

### 4. 内容版权和来源

- 只保存元数据和链接
- 默认打开原文
- 视频使用官方播放器或外部浏览器
- 不下载视频
- 不抓取付费墙内容
- 保留作者、来源、许可和更新时间

### 5. 目录被篡改

- HTTPS
- Ed25519
- SHA-256
- Bundle ID
- Team ID
- 过期时间
- 撤销列表
- 密钥轮换

### 6. 工具状态误判

- 安装后再次探测
- 同时记录版本、路径、架构
- CLI 和 GUI 分别检测
- 支持用户手动刷新
- 错误状态不能直接显示为“已安装”

### 7. 文档和工具版本漂移

- 记录适用版本
- 内容显示最后同步时间
- 官方发布说明优先
- 目录可撤销
- 过期内容标识提示

---

## 十七、第一版验收标准

达到以下条件才建议发布 v1.0.0：

- 支持 20–30 个经过审核的工具。
- 至少支持 Homebrew Formula、Cask、mise 三类安装方式。
- 8 个 Stage 0 工具安装和检测通过。
- 不存在任意远程 Shell 执行能力。
- 所有安装日志包含来源、版本、结果。
- 所有安装包使用 HTTPS。
- 官方安装包支持哈希和签名校验。
- 中英文完整可用。
- 浅色、深色、系统主题完整可用。
- 教程内容都有来源 URL。
- 离线可以浏览缓存目录。
- Sparkle 应用内更新成功。
- 更新签名错误时能够拒绝安装。
- DMG 通过签名、公证和 Gatekeeper。
- 干净 Mac 安装通过。
- 没有把本地测试结果冒充线上发布结果。

---

## 十八、后续版本规划

### v1.1

- 更多工具
- 单个工具自动更新
- 工具版本锁定
- 更好的搜索
- 收藏同步导出
- 终端命令复制
- 安装失败诊断

### v1.5

- 项目级工具环境
- mise 项目配置
- asdf 支持
- .tool-versions
- .mise.toml
- 项目目录检测
- 开发环境配置模板

### v2.0

- 云端账号
- 团队工具清单
- 企业软件源
- 私有目录
- 团队安装策略
- 内容管理后台
- 视频和文章审核流程
- 管理员撤销工具版本

---

## 最终建议

第一版不要做成“万能安装器”，而要先做成：

> 可信的开发工具目录 + 安全安装器 + 学习入口 + 启动器。

最关键的技术决策：

1. 采用 SwiftUI + AppKit + Tuist。
2. 使用 Homebrew、mise 和官方安装包适配器。
3. 禁止远程任意脚本执行。
4. 使用签名目录和安装包校验。
5. 使用 Sparkle 2 处理应用自动更新。
6. 使用 DMG 首次安装、ZIP 应用内更新。
7. 工具更新和 App 更新分开。
8. 首发中英文、浅色深色。
9. 先做 20–30 个工具，再逐步扩大目录。
10. 采用主代理 + 3 个边界清晰的子代理并行开发。

下一步是确认这份方案，然后在 Coding Tools 目录中创建产品设计基线、初始化工程结构，并按上述子代理波次开始实现。

