
# Coding Tools Independent Review and Acceptance Plan

**Review target:** /Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools

**Review purpose:** 由没有参与实现的审核人，独立判断 Coding Tools 的用户体验、前后端接入、目录安全、安装执行、持久化、启动和发布证据是否形成闭环。审核结果必须能回答“代码写了什么、软件实际做了什么、用户是否真正用过”这三个不同问题。

**Review mode:** 只读优先；审核人可运行构建、测试、静态扫描和本地沙盒验证，但不擅自修改代码、目录数据、远程 Release、签名配置或用户环境。发现问题时先保留最小复现和证据，再由实现负责人处理。

## 1. 审核红线与判定原则

- 审核范围只包含 Coding Tools 目录，不访问或修改相邻的 智余、智额或其他项目。
- 审核前记录 branch、HEAD、tag、版本、dirty 状态和机器环境。
- 本地 Debug build 只能证明编译通过；不能代替 Release、签名、notarization、远程发布或用户安装。
- 单元测试只能证明被覆盖的逻辑；不能代替真实目录、真实安装、真实启动、真实网络和真实权限行为。
- 任何空签名、unknown key、过期数据、篡改内容、未授权下载脚本或不受控命令执行都按 P0 处理。
- UI 显示的状态必须能追溯到 Catalog、Detection、Installer、Launcher 或 Store 的事实；硬编码成功、低风险、已安装和 example.com 都不接受。
- “未运行”与“失败”不同，“未知”与“通过”不同；报告必须保留原始命令、exit code、时间、commit 和证据文件。
- 审核人不因为计划已勾选、代码已合并或旧文档声称完成而自动通过。

---

## 2. 证据状态模型

每一项用下列状态之一记录：

| 状态 | 含义 | 是否可以写入完成 |
|---|---|---|
| static_verified | 源码、配置或测试静态确认 | 只能作为静态层证据 |
| local_build_verified | 当前 commit 在本机成功构建 | 不能推断运行时或发布 |
| test_verified | 指定测试 target 实际运行并通过 | 只覆盖测试范围内行为 |
| runtime_verified | 在真实运行 App 中按步骤观察并记录 | 可证明该环境的实际行为 |
| package_verified | 产物存在且 checksum、签名或 notarization 已核验 | 需注明核验工具和账号环境 |
| not_run | 由于权限、凭据、设备或环境未执行 | 不能判定通过 |
| blocked | 存在明确阻塞项，无法安全继续 | 必须列出解除条件 |
| failed | 已运行且不符合预期 | 必须给出复现步骤 |

报告中禁止把多个状态压缩成一个“整体通过”。

---

## 3. 审核前基线

### Gate 0. 范围、版本和可复现性

**目标：** 确认审核对象没有被错误的版本、生成文件或 dirty worktree 混淆。

**执行命令：**

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"
git status --short --branch
git log -5 --oneline --decorate
git describe --tags --always
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Apps/Mac/Sources/App/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Apps/Mac/Sources/App/Info.plist
find Apps/Mac -name "*.xcscheme" -print | sort
rg -n "CodingTools|Testables|testAction" Apps/Mac/CodingTools.xcodeproj/xcshareddata/xcschemes Apps/Mac/Project.swift
~~~

**审核记录：**

- [ ] 记录绝对项目路径、branch、HEAD、tag、版本和 build。
- [ ] 记录初始 dirty 文件；不是本审核产生的文件不得修改。
- [ ] 对比 PROJECT_STATUS.md、CHANGELOG.md、Info.plist、Project.swift 和协作状态文件。
- [ ] 确认 CodingTools scheme 的 Testables 不是空集合。
- [ ] 若版本或 scheme 互相矛盾，先标记 P1；若导致测试无法执行，升级 P0 release gate。

**通过证据：** baseline.md、命令原始输出、当前 commit、版本对照表。

---

## 4. Catalog、Content 和安全审核

### Gate 1. 目录信任链

**目标：** 证明任何进入 UI、安装器或内容页面的数据都经过签名、schema、时间和撤销验证。

**静态检查：**

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"
rg -n -i -e "local-no-signature" -e "try\\?" -e "signature" -e "expiresAt" -e "keyID" Apps/Mac/Sources Apps/Mac/Tests
rg -n -i -e "manifest" -e "RemoteCatalogLoader" -e "RemoteContentLoader" -e "LocalCatalogLoader" Apps/Mac/Sources
find . -type f -name "*.json" -print | sort
~~~

**测试和行为矩阵：**

| Fixture | 预期 | 必须留存 |
|---|---|---|
| 有效签名、未过期、可信 key | verified，并可进入 decode | test output |
| signature 为空 | rejected，不得显示为本地成功 | test output + UI 状态 |
| keyID 不存在 | rejected，提示目录来源不可验证 | test output |
| key 已撤销 | rejected，旧缓存也不可绕过 | test output |
| payload 被篡改 | rejected，不返回部分工具 | test output |
| expiresAt 已过期 | rejected 或产品明确允许的 stale 状态 | policy + test output |
| schemaVersion 不支持 | rejected，不崩溃 | test output |
| 网络断开 | 只使用已验证且未过期的缓存，否则 unavailable | runtime log |
| 远程失败后 fallback | fallback 只能落到 verified 数据 | loader test |

**审核步骤：**

- [ ] 阅读 ManifestSecurity、ManifestCanonicalizer、Catalog loader 和 Content loader 的调用链。
- [ ] 确认验证发生在 decode 和业务使用之前。
- [ ] 确认 LocalCatalogLoader、RemoteCatalogLoader、RemoteContentLoader 使用同一套安全语义。
- [ ] 确认 CodingToolsApp 没有用 try? 把失败变成空目录或默认成功。
- [ ] 对所有工具 JSON 检查 toolID 唯一、source 完整、签名字段存在、过期时间可判定。
- [ ] 检查开发 key、生产 key、key rotation 和 revocation 处理，不把开发 fixture 当 Release 数据。
- [ ] 在 UI 上验证 rejected、expired、unavailable 的文案、重试和离线提示。

**P0 条件：**

- 空签名被当作 verified。
- 任意用户可控 URL 或本地内容无需签名进入安装器。
- 过期或篡改 payload 仍展示安装按钮。
- loader 静默吞错并继续使用不可信数据。

---

## 5. 前后端接入和安装审核

### Gate 2. 从 UI 意图到真实执行

**目标：** 证明 UI 选择的工具和 install option，经过 AppState、InstallerService、AdapterRegistry、Helper/ProcessExecutor 后仍保持相同的 action 参数，并将结果返回 UI。

**必须建立的 call-chain 表：**

| 层 | 审核问题 | 证据 |
|---|---|---|
| Catalog | option 的 adapter、packageName/toolName、URL、checksum 从哪里来 | fixture + source |
| View | 用户选择的 optionID 如何提交 | UI test/截图 |
| AppState | operationID、progress、cancel、retry 如何管理 | unit test/source |
| InstallerService | 是否把 option/action 原样传递 | mock adapter test |
| AdapterRegistry | 是否重新猜包名或丢 action | parameter-preservation test |
| Adapter | 是否使用正确的 package manager 和安全路径 | adapter test/log |
| Helper | 是否有白名单、权限和取消协议 | Helper wire test/runtime |
| Detection | 安装完成后是否重新检测 | detection test/runtime |
| Store | 是否记录安全的结果 | SQLite test/log |
| UI | 成功、失败、取消、重试如何显示 | UI test/runtime |

**安装参数矩阵：**

| 场景 | 必核验参数 | 不接受的证据 |
|---|---|---|
| Claude Code / npm | action.packageName、版本约束、registry | 只看到 tool.id |
| Codex CLI / npm | action.packageName、版本约束、registry | 只看到页面按钮 |
| Docker / Homebrew | formula/cask 类型和 packageName | 只看到 brew 命令样例 |
| Node / Mise | action.toolName 和版本策略 | 从产品名猜测 |
| Python / Mise | action.toolName 和版本策略 | 只看安装成功 toast |
| Rust / Mise | action.toolName 和版本策略 | 只测同名 fixture |
| 官方 Artifact | downloadURL、archiveType、checksum、destination | 只测 mock 下载 |
| 不支持选项 | blocked/unsupported 错误和解释 | 触发任意 shell |

**审核步骤：**

- [ ] 阅读 InstallOption、InstallAction、InstallPlan、AdapterRegistry 和所有 Adapter。
- [ ] 使用内部 toolID 与上游包名不同的 fixture，验证 action 没有被覆盖。
- [ ] 记录 NpmGlobalAdapter 是否存在 curl URL pipe bash；若存在且可达，P0。
- [ ] 验证 OfficialArtifact 的 URL、archive type、checksum 和安装目录都经过白名单/策略校验。
- [ ] 验证 HelperClient 在生产启动路径确实被构造并调用，而不是只有协议和测试代码。
- [ ] 观察 progress 是否单调、是否有阶段名称、是否能显示当前动作。
- [ ] 点击取消，确认 UI 先进入 cancelling，底层进程退出，最终为 cancelled；不能只把按钮状态改掉。
- [ ] 触发失败，确认只有 retryable 错误显示重试；重试产生新的 operationID。
- [ ] 安装结束后确认 Detection 使用真实命令/路径，UI 状态来自检测结果。
- [ ] 确认 stdout/stderr、命令行和错误日志不含 token、密码、完整 signed URL 或用户私有路径。

**P0 条件：**

- UI 显示安装成功但没有真实 process/detection 证据。
- AdapterRegistry 丢失 action，导致安装错误包或错误工具。
- 用户可控内容构成任意命令执行。
- 取消只改变 UI，不停止真实进程。
- Helper 只存在源码声明，没有生产调用链，且产品把安装写成已接通。

---

## 6. 状态、持久化和隐私审核

### Gate 3. 用户状态的真实保存

**目标：** 证明收藏、最近使用和操作历史不是一次启动内的临时假象，并且记录内容可安全保留。

**审核步骤：**

- [ ] 阅读 Persistence.swift、SQLiteStore、StoreMigrations、AppState 注入路径。
- [ ] 确认生产路径不是默认 InMemoryStore；测试可使用临时数据库。
- [ ] 验证收藏新增、取消、最近去重排序和操作历史上限。
- [ ] 关闭并重新启动 App，验证上述状态仍然存在。
- [ ] 用损坏或旧版本数据库测试迁移、备份和可解释错误。
- [ ] 检查数据库和日志是否出现 token、credential、signed URL、完整命令参数或绝对私有路径。
- [ ] 确认清理操作历史有明确范围；清理不会误删 Catalog 或安装文件。
- [ ] 对 AIConfigDiscovery 运行实际扫描，确认 UI 能区分“未配置”“已配置”“扫描失败”，而不是把缺少依赖伪装成无配置。

**最小重启验收：**

~~~text
1. 启动 App，收藏工具 A，打开工具 B，记录一次成功或失败操作。
2. 退出 App，确认进程结束，记录数据库路径和 hash。
3. 再启动 App，验证工具 A 仍收藏，工具 B 在最近列表，操作历史状态一致。
4. 清理历史，确认只清理历史表，收藏和 Catalog 不受影响。
~~~

**P1 条件：**

- 收藏或最近使用仅保存在内存，重启丢失。
- 迁移失败没有恢复说明或会覆盖原数据库。
- 日志暴露供应商凭据、完整下载 URL 或私有路径。
- UI 的配置扫描依赖缺失时直接显示“未配置”。

---

## 7. 用户体验和运行时审核

### Gate 4. 首次启动到完成任务的可用性

**目标：** 让用户在正常、失败、取消、离线和权限拒绝路径中都知道发生了什么、下一步是什么。

**运行环境：**

- macOS 版本、架构、Xcode 版本、当前 commit；
- 使用独立测试用户或可清理的测试目录；
- 每个流程记录开始时间、结束时间、请求/operation ID、截图和日志；
- 不使用生产账户、真实私钥或未授权供应商账单。

**场景表：**

| 场景 | 观察点 | 通过标准 |
|---|---|---|
| 首次启动 | 目录 loading、空状态、错误状态 | 不把 loading 误报为空目录 |
| 目录成功 | 卡片、搜索、详情 | 每个状态来自真实 Catalog |
| 目录过期/拒绝 | reason、retry、offline 文案 | 不显示不可信安装按钮 |
| 详情页 | option、风险、来源、版本 | 不写死 Homebrew 或低风险 |
| 安装中 | 阶段、进度、禁用重复操作 | 用户知道当前动作 |
| 取消 | cancelling、停止、结果 | 最终明确 cancelled |
| 安装失败 | 错误原因、retryable | 只在可重试时展示重试 |
| 安装成功 | 检测、版本、launch | 由 Detection 事实驱动 |
| 启动失败 | capability、路径、修复建议 | 不打开 example.com |
| 收藏/最近 | 立即反馈、重启恢复 | Store 与 UI 一致 |
| 菜单栏 | 最近工具、真实状态、入口 | 不使用假链接 |
| 中文/英文 | 文案、截断、动态尺寸 | 无关键硬编码英文或乱码 |
| 可访问性 | keyboard、VoiceOver、Reduce Motion | 主流程不依赖鼠标和动画 |

**审核步骤：**

- [ ] 以真实运行 App 走一遍目录 -> 详情 -> 安装 -> 检测 -> 启动。
- [ ] 断网、无权限、签名失败、安装失败、取消各走一遍。
- [ ] 检查 ToolDetailView、InstallSheet、HomeToolCard 是否直接写死 status、risk、option 或 command。
- [ ] 检查所有按钮是否有 disabled/loading 防重复提交。
- [ ] 检查错误文案是否说明原因、影响和下一步，而不是只显示“失败”。
- [ ] 检查内容加载错误是否可重试，重试是否清除旧状态。
- [ ] 检查启动 CLI 和 GUI 两类 LaunchCapability 的路径/URL 白名单。
- [ ] 记录至少一组中文和英文截图；标注 runtime_verified 还是 preview-only。

**P0 条件：**

- 用户点击安装后 UI 成功，但没有真实执行或检测。
- 失败/取消导致 UI 永久 loading 或错误地显示成功。
- 私有内容、未经验证内容或任意 URL 可直接进入用户流程。
- 启动入口打开占位网站或未校验的用户可控 URL。

---

## 8. 测试、构建和发布证据审核

### Gate 5. 工程门禁

**执行顺序：**

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
./scripts/run-tests.sh
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -configuration Debug -destination "platform=macOS" build
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -configuration Release -destination "platform=macOS" build
~~~

**审核记录：**

- [ ] 记录每条命令的完整输出、exit code、开始结束时间和产物路径。
- [ ] 确认测试 target 实际执行，而不是仅显示 build succeeded。
- [ ] 确认 Release 使用的版本、架构、entitlements 和资源正确。
- [ ] 对 App、Helper、归档和 appcast 产物计算 SHA-256。
- [ ] 运行静态检查，确认没有 example.com、危险 shell fallback、空签名成功路径和吞错式 try?。
- [ ] 如有代码签名，使用 codesign --verify --deep --strict --verbose 验证并记录 Team ID、证书类型和时间。
- [ ] 如有 notarization，保存 notarization request ID、最终状态和 stapler 验证输出。
- [ ] 如有远程 Release，记录 asset URL、checksum、Release commit 和发布人；未执行写 not_run。
- [ ] 如有 Sparkle，验证 appcast 签名、版本排序、下载 URL、旧版本升级和失败回滚。
- [ ] 如有干净机器安装，记录安装前后版本、启动、卸载和更新；没有干净机器就不能写 clean_machine_install passed。

**Release 状态分栏：**

| 层级 | 证据 | 通过条件 |
|---|---|---|
| source | commit、diff、dirty 状态 | 范围清楚且无意外变更 |
| build | Debug/Release 输出 | 当前 commit 可复现 |
| test | 实际 test output | 指定 target 通过 |
| package | zip/dmg/app checksum | 产物可定位 |
| signing | codesign 结果 | 签名链与团队信息正确 |
| notarization | notarytool/stapler 结果 | Apple 返回成功 |
| remote release | Release 页面和 asset | 用户可访问且 hash 一致 |
| in-app update | Sparkle 运行日志 | 更新、失败和回滚可观察 |
| user install | 干净环境记录 | 用户实际安装并启动 |

任何层级缺失都保留为 unknown/not_run，不向上层自动升级。

---

## 9. 缺陷分级和最终决策

### P0：阻塞，不得交付

- 安全验证绕过、空签名或篡改目录被当作可信。
- 任意命令、脚本、下载 URL 或路径可被用户/远程内容注入。
- UI 成功状态与真实安装/检测不一致，可能造成用户误判。
- 取消无法停止真实进程且可能继续修改用户环境。
- 生产安装路径或 Helper 没有实际接通，却对外宣称完成。
- 测试入口失效，关键门禁无法复现，且没有替代证据。
- 凭据、私有内容或供应商内部信息进入浏览器 DTO、日志或用户可见界面。

### P1：条件通过，必须有负责人和期限

- 收藏/最近重启丢失但不影响安全。
- 某个受支持工具缺少检测或错误文案。
- Release、notarization、Sparkle 或干净机器安装还未执行，但明确标记 not_run 且当前交付只限本地。
- 可访问性、国际化或网络重试存在明显缺口但有明确修复任务。
- 版本文档不一致但不影响实际构建；必须在下一个交付点前统一。

### P2：可接受的后续优化

- 布局、动画、间距、图标、非关键文案和性能微调。
- 不影响核心路径的日志可读性、测试 fixture 重构和报告排版。

### 最终决策规则

- 存在任意 P0：BLOCKED。
- 无 P0，但存在未豁免 P1：CONDITIONAL，禁止称为完整交付。
- 无 P0，P1 已有负责人、截止时间和风险接受记录：PASS WITH RISKS。
- P0 清零、P1 清零或正式豁免，且证据状态与范围一致：PASS。
- 远程 Release、更新或用户安装未做，即使本地 PASS，也只能写 LOCAL PASS，不能写 RELEASED 或 USER ACCEPTED。

---

## 10. 独立审核报告模板

审核人复制本模板生成报告，文件名建议为：

docs/evidence/2026-08-12-coding-tools/coding-tools-independent-review.md

~~~markdown
# Coding Tools Independent Review

- Review date:
- Reviewer:
- Project path:
- Branch:
- Commit:
- Tag:
- macOS:
- Architecture:
- Xcode:
- Initial git status:
- Final git status:

## Executive Decision

- Decision: BLOCKED / CONDITIONAL / PASS WITH RISKS / PASS / LOCAL PASS
- P0 count:
- P1 count:
- P2 count:
- Release state: NOT RUN / LOCAL ONLY / SIGNED / NOTARIZED / RELEASED
- User acceptance state: UNKNOWN / NOT RUN / VERIFIED

## Evidence Index

| ID | Layer | Command or scenario | Status | Artifact |
|---|---|---|---|---|
| E-001 | baseline | git/version/scheme |  |  |
| E-002 | test | full test command |  |  |
| E-003 | build | Debug build |  |  |
| E-004 | build | Release build |  |  |
| E-005 | catalog | signature/expiry matrix |  |  |
| E-006 | installer | parameter matrix |  |  |
| E-007 | runtime | install/cancel/retry |  |  |
| E-008 | persistence | restart verification |  |  |
| E-009 | launch | CLI/GUI launch |  |  |
| E-010 | package | checksum/signing |  |  |
| E-011 | release | remote asset/appcast |  |  |
| E-012 | user | clean machine install |  |  |

## Findings

### P0

| ID | Reproduction | Impact | Evidence | Owner | Blocking condition |
|---|---|---|---|---|---|

### P1

| ID | Reproduction | Impact | Evidence | Owner | Due date | Risk acceptance |
|---|---|---|---|---|---|---|

### P2

| ID | Reproduction | Impact | Evidence | Suggested follow-up |
|---|---|---|---|---|

## UX Review

- First launch:
- Catalog loading:
- Catalog failure:
- Detail and install option:
- Progress:
- Cancel:
- Failure and retry:
- Post-install detection:
- Launch:
- Favorites and recents:
- Menu bar:
- Localization:
- Accessibility:

## Frontend / Backend Integration

- Catalog to View:
- View to AppState:
- AppState to InstallerService:
- InstallerService to AdapterRegistry:
- AdapterRegistry to Adapter:
- Adapter to Helper/ProcessExecutor:
- Detection back to AppState:
- AppState to Store:
- Store back to UI:
- Unverified or missing links:

## Release Boundary

- Local build:
- Local tests:
- Runtime:
- Package:
- Signing:
- Notarization:
- Remote Release:
- In-app update:
- Clean machine install:
- Explicitly not run:

## Reviewer Conclusion

用事实描述当前可以交付的范围、不能交付的范围、P0/P1 解除条件和下一次复核入口。不得使用“基本完成”“应该没问题”作为结论。
~~~

---

## 11. 审核交接要求

实现负责人交接给审核人时必须提供：

- 当前 commit、版本和初始 dirty 状态。
- 本计划每个 Task 的 commit、测试命令和未解决风险。
- Catalog fixture、安装参数矩阵、错误码和测试环境说明。
- Debug/Release/test/runtime/package 的原始输出路径。
- 任何签名、notarization、远程 Release、Sparkle 或用户安装的 not_run 原因。
- 不得要求审核人使用未记录的本地修改、隐藏凭据或口头“已验证”结论。

审核人完成后必须回传：

- 独立报告；
- P0/P1/P2 清单；
- 证据索引；
- 可复现命令；
- 明确的最终决策；
- 若为 CONDITIONAL 或 LOCAL PASS，写明不能对外宣称的内容。

**审核计划结束。**
