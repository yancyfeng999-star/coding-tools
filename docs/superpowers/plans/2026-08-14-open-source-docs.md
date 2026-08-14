# Apache-2.0 开源文档与 GitHub 协作规范 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Coding Tools 的第一方代码、脚本和文档切换到 Apache License 2.0，并补齐公开协作所需的许可证、行为、安全、支持、贡献、第三方声明和 GitHub 模板。

**Architecture:** 保持现有 Swift、安装器、目录验签、更新器和发布脚本不变，只在仓库根目录、`docs/` 和 `.github/` 增加或更新公开协作入口。根目录 `LICENSE` 承担 Apache-2.0 法律文本，`NOTICE` 承担第一方归属，`THIRD_PARTY_NOTICES.md` 承担 Sparkle 与外部内容边界，README 负责导航，其余文档各自承担单一职责。

**Tech Stack:** Markdown、GitHub Issue Forms YAML、Git；验证使用 `git diff --check`、Ruby YAML 解析、仓库内相对链接检查和敏感/生成物扫描；不运行 Xcode、Tuist、App 或发布脚本。

## Global Constraints

- 第一方许可证必须是 Apache License 2.0，版权声明保留 `YancyFeng`，年份为 2026。
- Apache-2.0 不扩展 Sparkle、Homebrew、mise、工具供应商、Catalog 元数据或第三方商标的权利。
- `NOTICE` 记录第一方版权与必要归属；第三方许可证不复制或改写上游法律文本。
- 安全问题使用 GitHub Private Vulnerability Reporting，不引导用户公开提交漏洞细节。
- 不新增遥测、账号系统、远程服务或社区平台；不提交 Token、私钥、Cookie、用户配置、绝对路径、原始日志或本地数据。
- 不生成、打开、注册或提交 `.app`；不运行 `xcodebuild`、`tuist build`、`tuist generate`、`release.sh` 或任何打包/发布命令。
- 保留现有代码和 CI 行为；纯文档变更不升版本号、不创建 Release。
- 所有修改必须位于 `/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/`，保留无关工作区变更。

---

### Task 1: Apache-2.0 法律文件与第三方边界

**Files:**
- Modify: `LICENSE`
- Create: `NOTICE`
- Create: `THIRD_PARTY_NOTICES.md`

**Interfaces:**
- Produces: 根目录 Apache-2.0 许可证入口、第一方归属入口、Sparkle 与 Catalog 的第三方权利说明，供 README、CONTRIBUTING 和发布维护者引用。

- [ ] **Step 1: Replace the first-party license text**

将 `LICENSE` 替换为 Apache License 2.0 官方完整文本，开头保留：

```text
Copyright 2026 YancyFeng
```

正文必须包含 Apache-2.0 的版权、专利、商标、免责声明和责任限制条款，不得保留 MIT 的标题、授权段落或 MIT 专属免责声明。

- [ ] **Step 2: Add first-party attribution**

创建 `NOTICE`，内容只声明 Coding Tools 第一方代码、脚本和文档的版权归属，并明确第三方依赖与 Catalog 外部品牌不由本文件重新授权：

```text
Coding Tools
Copyright 2026 YancyFeng

This product includes first-party source code, scripts, and documentation
licensed under the Apache License, Version 2.0.

Third-party dependencies, catalog metadata, names, logos, installers, and
other external content remain subject to their respective owners' terms.
See THIRD_PARTY_NOTICES.md for project-maintained attribution notes.
```

- [ ] **Step 3: Record dependency and catalog rights**

创建 `THIRD_PARTY_NOTICES.md`，记录 Sparkle 来源为 `Apps/Mac/Tuist/Package.swift`，解析版本 `2.9.5`，revision `79bc9e872948e47877e76f194cb0c8e0412b0b90`，上游入口为 `https://github.com/sparkle-project/Sparkle`。同时记录 Sparkle 的源代码、二进制、许可证、NOTICE 和商标属于上游权利人；分发时以 Sparkle 随发行物提供的上游许可证/NOTICE 为准。

该文件还必须说明 `Catalog/` 中的工具名称、Logo、官方 URL、教程链接、发行包和商标属于相应供应商或作者；目录签名只证明完整性和发布者身份；Homebrew、mise、官方安装包、外部教程、视频和服务按各自条款使用；仓库不上传供应商安装包、付费内容、私有内容或未经授权的 Logo。后续新增依赖必须记录来源、解析版本、上游许可入口和分发注意事项。不得复制第三方完整许可证文本。

- [ ] **Step 4: Verify legal-file content**

Run:

```bash
rg -n "Apache License|Version 2.0|Copyright 2026 YancyFeng|MIT License|Sparkle|THIRD_PARTY_NOTICES" LICENSE NOTICE THIRD_PARTY_NOTICES.md
git diff --check
```

Expected: `LICENSE` 和 `NOTICE` 包含 Apache-2.0/第一方归属，第三方声明包含 Sparkle 来源；`LICENSE` 不包含 `MIT License`，命令退出码为 0。

- [ ] **Step 5: Commit the license boundary**

```bash
git add LICENSE NOTICE THIRD_PARTY_NOTICES.md
git commit -m "docs: adopt Apache-2.0 license"
```

### Task 2: 社区贡献、安全与支持文档

**Files:**
- Create: `CONTRIBUTING.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `SECURITY.md`
- Create: `SUPPORT.md`

**Interfaces:**
- Consumes: `LICENSE`、`NOTICE`、`THIRD_PARTY_NOTICES.md` 的权利边界和现有 `AGENTS.md` 的安全/发布约束。
- Produces: 新用户、贡献者、安全研究者和支持请求的公开分流入口，供 README 与 GitHub 模板链接。

- [ ] **Step 1: Write contribution workflow**

创建 `CONTRIBUTING.md`，明确从 `main` 创建分支、一个 PR 只处理一个主题、提交信息使用 `feat:`/`fix:`/`docs:`/`chore:`；代码改动遵守禁止任意 Shell、禁止静默 sudo、不修改 `.zshrc`/`PATH`、不把 API Key 放入客户端等约束；Catalog 改动说明来源、版本、官方 URL、许可/商标来源和签名影响，并禁止 `command`、`script`、`sudo`、`pipe`、`redirect`、`postInstall` 字段。

文档改动至少运行 `git diff --check`；代码改动由 CI 执行既有测试；纯文档变更不要求本地构建或打开 App。`.app`、`build/`、DerivedData、私钥、用户配置、日志和临时截图不得提交。贡献者必须拥有提交内容的权利，并同意新增第一方内容按 Apache-2.0 发布，第三方内容保留原权利。

- [ ] **Step 2: Write community conduct policy**

创建 `CODE_OF_CONDUCT.md`，定义尊重、包容、专业讨论、禁止骚扰/歧视/恶意披露等行为；说明维护者可删除不当内容、暂停参与权限，并要求行为投诉不要通过公开 Issue 发送敏感信息。不得虚构个人邮箱；使用仓库安全入口或维护者 GitHub 私密渠道。

- [ ] **Step 3: Write security disclosure policy**

创建 `SECURITY.md`，使用私密报告入口：

```text
https://github.com/yancyfeng999-star/coding-tools/security/advisories/new
```

文档需说明支持范围为当前 `v1.5.x` 与 `main`，旧版本按最佳努力处理；安全问题不得公开提交 Issue、Token、私钥、Cookie、用户数据或完整利用细节。报告应包含受影响版本、影响范围、最小复现、临时缓解和联系方式；维护者确认后再决定修复版本、公告和披露时间，不承诺未经验证的 SLA。

- [ ] **Step 4: Write support routing policy**

创建 `SUPPORT.md`，将请求分为文档疑问、可复现 Bug、功能建议、安全问题和目录内容/许可问题；要求先查 README/现有文档，提供版本、macOS、架构和最小复现，并在日志中删除 Token、路径、用户名、Cookie、私钥和用户数据。安全问题必须转 `SECURITY.md`，许可/商标问题必须说明来源，不通过支持文档代替法律意见。

- [ ] **Step 5: Verify community docs**

Run:

```bash
for file in CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md SUPPORT.md; do test -s "$file"; done
rg -n "Apache-2.0|SECURITY.md|不.*公开|Token|私钥|\.app|build/|git diff --check" CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md SUPPORT.md
git diff --check
```

Expected: 四个入口文件均存在且非空，包含必要的 Apache-2.0、私密安全披露、敏感信息和无 App 构建约束。

- [ ] **Step 6: Commit community documents**

```bash
git add CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md SUPPORT.md
git commit -m "docs: add open-source contribution policies"
```

### Task 3: GitHub Issue 与 Pull Request 模板

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`

**Interfaces:**
- Consumes: `SECURITY.md` 的私密报告入口和 `SUPPORT.md` 的问题分流。
- Produces: 可被 GitHub 解析的 Bug/功能表单、关闭空白 Issue 的联系入口和 PR 审查清单。

- [ ] **Step 1: Add the bug form**

创建 `.github/ISSUE_TEMPLATE/bug_report.yml`，使用唯一的 `id`，至少收集 `version`、`macos_version`、`architecture`、`steps`、`expected`、`actual`、`logs_redacted`；开头 Markdown 必须提示安全漏洞不要公开提交，并链接 `SECURITY.md`。

- [ ] **Step 2: Add the feature form**

创建 `.github/ISSUE_TEMPLATE/feature_request.yml`，至少收集 `use_case`、`proposed_change`、`alternatives`、`privacy_impact`、`third_party_content`；要求说明权限、隐私、许可和商标影响，不把功能请求当作安全报告。

- [ ] **Step 3: Add issue routing config**

创建 `.github/ISSUE_TEMPLATE/config.yml`：

```yaml
blank_issues_enabled: false
contact_links:
  - name: Security vulnerability
    url: https://github.com/yancyfeng999-star/coding-tools/security/advisories/new
    about: Please report security vulnerabilities privately.
  - name: User support
    url: https://github.com/yancyfeng999-star/coding-tools/blob/main/SUPPORT.md
    about: Read the support and troubleshooting routes first.
```

- [ ] **Step 4: Add the pull request checklist**

创建 `.github/PULL_REQUEST_TEMPLATE.md`，要求作者勾选：范围明确、`git diff --check` 通过、测试/文档验证已说明、没有 `.app`/`build/`/DerivedData/密钥/用户数据、Catalog 来源与签名影响已说明、许可证/NOTICE/第三方归属已确认、没有把 App 构建误报为 Release。

- [ ] **Step 5: Validate GitHub YAML**

Run:

```bash
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path); puts "OK #{path}" }' .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/feature_request.yml .github/ISSUE_TEMPLATE/config.yml
git diff --check
```

Expected: 三个 YAML 文件均输出 `OK`，无解析错误；Issue 表单的所有 `id` 唯一且安全入口为私密 URL。

- [ ] **Step 6: Commit GitHub templates**

```bash
git add .github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE.md
git commit -m "docs: add GitHub contribution templates"
```

### Task 4: README 与维护者开源指南

**Files:**
- Modify: `README.md`
- Create: `docs/OPEN_SOURCE_GUIDE.md`

**Interfaces:**
- Consumes: Task 1-3 的文件路径、Apache-2.0 边界、支持/安全入口和 GitHub 模板。
- Produces: 单一可导航的用户入口和维护者日常操作指南。

- [ ] **Step 1: Update README navigation**

在 README 的核心文档表中加入 `CONTRIBUTING.md`、`CODE_OF_CONDUCT.md`、`SECURITY.md`、`SUPPORT.md`、`THIRD_PARTY_NOTICES.md` 和 `docs/OPEN_SOURCE_GUIDE.md`；将许可证章节改为 Apache-2.0，链接 `LICENSE` 与 `NOTICE`，说明第一方内容、第三方依赖和 Catalog 外部品牌的边界。

- [ ] **Step 2: Add release and no-build wording**

在 README 快速开始或开发说明附近补充：纯文档贡献不需要本地构建 App；本地构建、签名、公证、GitHub Release 和应用内更新是不同证据状态；不提交 `.app`、`build/` 或 DerivedData。

- [ ] **Step 3: Write open-source maintenance guide**

创建 `docs/OPEN_SOURCE_GUIDE.md`，覆盖维护者审阅代码/Catalog 元数据/目录签名/第三方许可的流程；Apache-2.0、NOTICE、第三方声明和贡献者权利边界；设置、缓存、日志和安装状态留在用户本机，不提交目录签名私钥、用户配置和原始日志；当前文档不承诺不存在未来遥测，任何新增诊断/遥测必须单独审查并公开说明；文档变更、代码测试、App 构建、签名、公证、Release 和应用内更新分别记录证据；纯文档变更不升版本、不运行 `release.sh`，只提交并推送 `main`。

- [ ] **Step 4: Validate README links and wording**

Run:

```bash
for file in LICENSE NOTICE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md SUPPORT.md THIRD_PARTY_NOTICES.md docs/OPEN_SOURCE_GUIDE.md; do test -s "$file"; done
rg -n "Apache-2.0|NOTICE|CONTRIBUTING|SECURITY|SUPPORT|第三方|\.app|build/" README.md docs/OPEN_SOURCE_GUIDE.md
git diff --check
```

Expected: README 与指南均能导航到已创建文件，许可证表述只把 Apache-2.0 施加到第一方内容。

- [ ] **Step 5: Commit user-facing navigation**

```bash
git add README.md docs/OPEN_SOURCE_GUIDE.md
git commit -m "docs: document open-source project usage"
```

### Task 5: 全量文档门禁与 GitHub 推送

**Files:**
- Verify: `LICENSE`, `NOTICE`, `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `THIRD_PARTY_NOTICES.md`, `docs/OPEN_SOURCE_GUIDE.md`, `.github/ISSUE_TEMPLATE/*`, `.github/PULL_REQUEST_TEMPLATE.md`

**Interfaces:**
- Consumes: Task 1-4 的全部公开协作文件。
- Produces: 可审计的纯文档提交、验证记录和 GitHub `main` 分支同步；不产生 App/Release 产物。

- [ ] **Step 1: Check repository-local links**

运行只读链接检查器，提取 Markdown 中以 `./` 开始或没有 URL scheme 的链接，去除锚点后按源文件目录检查目标存在；忽略 `https://`、`mailto:`、Issue 引用和运行时生成路径。

- [ ] **Step 2: Check YAML structure and duplicate IDs**

Run:

```bash
ruby -e 'require "yaml"; ARGV.each { |path| data = YAML.load_file(path); abort "missing body: #{path}" if path.end_with?("bug_report.yml", "feature_request.yml") && !data["body"].is_a?(Array); puts "OK #{path}" }' .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/feature_request.yml .github/ISSUE_TEMPLATE/config.yml
```

然后检查两个 Issue 表单的每个 `id:`，确认同一文件内没有重复 ID。

- [ ] **Step 3: Scan for generated artifacts and secrets**

Run:

```bash
git status --short
find . -type d \( -name build -o -name DerivedData \) -prune -print
find . -name '*.app' -print
rg -n --hidden -g '!/.git/**' -g '!Apps/Mac/Sources/ManifestSecurity/PublicKeys/**' '(BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|PRIVATE_KEY=)' . || true
git diff --check
```

Expected: 没有本轮新增的 `.app`、`build/`、DerivedData 或秘密材料；任何预先存在的无关变更都保留且不被暂存。

- [ ] **Step 4: Review final diff and status**

Run:

```bash
git diff HEAD~4..HEAD --stat
git status --short
git log --oneline -5
```

Expected: 只有本任务的许可证/文档/模板提交，工作树干净，没有版本升级或 Release tag。

- [ ] **Step 5: Push documentation-only commits**

完成最终检查后运行：

```bash
git push origin main
```

不得运行 `Apps/Mac/scripts/release.sh`，不得创建 tag 或 GitHub Release，不得构建或打开 App。

- [ ] **Step 6: Report evidence separately**

报告 GitHub commit、公开文档入口、验证命令及结果、工作树状态，并明确没有产生 App 构建、签名、公证、Release 或应用内更新证据。
