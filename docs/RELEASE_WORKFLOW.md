# Coding Tools · 发版流程

> v1.0.0 起每次发版必须按此流程执行。Agent 详细步骤见 [AGENT_RELEASE_WORKFLOW.md](./AGENT_RELEASE_WORKFLOW.md)。

## 1. 版本规则

- **语义版本**：`MAJOR.MINOR.PATCH`
- **MAJOR**：破坏性变更（产品方向变化、不兼容 API）
- **MINOR**：新功能（增加安装方式、新工具分类）
- **PATCH**：Bug 修复、内容更新
- **Build 号**：CI 自动递增

### 1.1 版本号权威源

```text
权威源：Apps/Mac/Sources/App/Info.plist 的 CFBundleShortVersionString
辅助：  Apps/Mac/Sources/App/Info.plist 的 CFBundleVersion
```

发版前由 `bump-version.sh` 自动更新；冲突时以 Info.plist 为准。

### 1.2 发布节点

| 版本 | 含义 | 内容要求 |
| --- | --- | --- |
| v0.1.0 | 工程原型 | Tuist 工程可启动 + 空窗口可显示 |
| v0.5.0 | 内部可用 | Stage 0 工具全通过 + 基础 UI |
| v0.9.0 | 内部 Beta | 完整 UI + 内容 + 中英文 + 浅深色 |
| v1.0.0 | 稳定发布 | 20–30 工具 + Sparkle 完整 + 公证通过 |

## 2. 发版流程

### 2.1 准备阶段

```bash
# 1. 确认主分支
git checkout main
git pull origin main

# 2. 确认 git 状态干净
git status --short

# 3. 跑测试
cd Apps/Mac && ./scripts/run-tests.sh

# 4. 跑构建
xcodebuild -scheme CodingTools -configuration Debug \
  -derivedDataPath ./build/DerivedData build
```

### 2.2 升版

```bash
# 默认 patch
cd Apps/Mac
./scripts/bump-version.sh patch

# 或 minor / major
./scripts/bump-version.sh minor
./scripts/bump-version.sh 1.2.3
```

`bump-version.sh` 自动：

1. 修改 `Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`
2. 在 `CHANGELOG.md` 顶部追加新版本段
3. 提交 `chore: bump version to x.y.z (build n)`

### 2.3 构建

```bash
cd Apps/Mac
tuist install
tuist generate
xcodebuild -scheme CodingTools -configuration Release \
  -derivedDataPath ./build/DerivedData build
```

### 2.4 签名

```bash
./scripts/sign-release.sh
```

`sign-release.sh` 自动：

1. 用 Developer ID 签名 .app
2. 启用 Hardened Runtime
3. 检查 entitlements

### 2.5 打包

```bash
./scripts/package-release.sh
```

产物：

```text
build/release/
├── CodingTools-1.0.0.dmg
├── CodingTools-1.0.0.zip
└── CodingTools-1.0.0.sha256
```

### 2.6 公证

```bash
./scripts/notarize-release.sh
```

1. 上传到 Apple Notary Service
2. 等待公证完成
3. Staple 公证票据到 DMG / .app
4. 验证 Gatekeeper 接受

### 2.7 生成 Appcast

```bash
./scripts/generate-appcast.sh
```

产物：

```text
build/release/
└── appcast.xml    # EdDSA 签名
```

### 2.8 发布

```bash
cd Apps/Mac
NOTES="一句话中文变更" ./scripts/release.sh
```

`release.sh` 自动：

1. 验证所有上游产物（DMG / ZIP / sha256 / appcast / signature）
2. 提交发版 commit
3. 打 tag `vX.Y.Z`
4. `git push origin main --tags`
5. `gh release create` 上传资产
6. 输出 Release 链接

### 2.9 应用内更新验证

```text
1. 准备一台装旧版本 CodingTools 的测试机
2. 启动 App → 设置 → 检查更新
3. 验证 Sparkle 检测到新版本
4. 验证后台下载
5. 验证安装替换
6. 验证重启后版本号
7. 验证设置 / 收藏 / 进度保留
```

## 3. 失败回滚

| 失败 | 回滚动作 |
| --- | --- |
| 本地测试失败 | 不发版；修复后重新升版 |
| 构建失败 | 不发版 |
| 签名失败 | 检查 Developer ID + keychain |
| 公证失败 | 查看 Apple 错误日志；不删 tag |
| Release 失败 | 修复后 `gh release upload` 重试 |
| 应用内更新失败 | 保留旧版本；远程撤销新版本（不删 tag） |
| Gatekeeper 拒绝 | 检查签名 + 公证 + Staple |

## 4. 发版后

1. 更新 [PROJECT_STATUS.md](../PROJECT_STATUS.md) 当前版本
2. 在 [CHANGELOG.md](../CHANGELOG.md) 添加发布日期
3. 在 [docs/STAGE0_TOOLS.md](./STAGE0_TOOLS.md) 记录实际测试结果
4. 通知内测群

## 5. 评审记录

| 日期 | 评审人 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-08-09 | Coordinator (Mavis) | 初稿 | 阶段 7 实施前由子代理 C 细化 |
