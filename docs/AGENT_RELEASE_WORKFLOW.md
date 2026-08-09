# Coding Tools · Agent 发版详细步骤

> 适用对象：所有能跑 `bash` 工具的 Agent。
> 完整流程参考 [RELEASE_WORKFLOW.md](./RELEASE_WORKFLOW.md)；本文档是 Agent 操作清单。

## 0. 前置检查

```bash
# 必须
- [ ] gh auth status                   # 已登录
- [ ] git status --short                # 工作区干净
- [ ] git branch --show-current         # 在 main
- [ ] tuist --version                   # >= 4.0
- [ ] xcodebuild -version               # Xcode 16+
- [ ] codesign -dv <identity>           # Developer ID 存在

# 禁止
- 不要在 feature 分支发版
- 不要跳过测试
- 不要本地没验就 `gh release create`
```

## 1. 一句话发版

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
NOTES="修复 xxx" ./scripts/release.sh
```

完整流程脚本内部自动完成。

## 2. 分步发版

### 2.1 准备

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"

# 拉取最新
git fetch origin
git checkout main
git pull --rebase origin main

# 确认工作区干净
test -z "$(git status --porcelain)" || {
  echo "工作区有未提交改动" >&2
  exit 1
}

# 跑测试
cd Apps/Mac && ./scripts/run-tests.sh || {
  echo "测试失败，不发版" >&2
  exit 1
}
```

### 2.2 升版

```bash
cd Apps/Mac
./scripts/bump-version.sh patch
# 或 minor / major / 指定版本
```

### 2.3 构建 + 签名 + 打包 + 公证

```bash
cd Apps/Mac

# Debug 构建验证编译
xcodebuild -scheme CodingTools -configuration Debug \
  -derivedDataPath ./build/DerivedData build

# Release 构建
xcodebuild -scheme CodingTools -configuration Release \
  -derivedDataPath ./build/DerivedData build

# 签名
./scripts/sign-release.sh

# 打包 DMG / ZIP
./scripts/package-release.sh

# 公证
./scripts/notarize-release.sh

# 生成 Appcast
./scripts/generate-appcast.sh
```

### 2.4 验证产物

```bash
build/release/
├── CodingTools-1.0.0.dmg
├── CodingTools-1.0.0.zip
├── CodingTools-1.0.0.sha256
└── appcast.xml

# 验证 SHA-256
shasum -a 256 -c build/release/CodingTools-1.0.0.sha256

# 验证公证
spctl --assess --verbose build/release/CodingTools.app

# 验证 Appcast 签名
./scripts/verify-appcast.sh build/release/appcast.xml
```

### 2.5 提交 + tag + 发布

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"

git add Apps/Mac/Sources/App/Info.plist CHANGELOG.md
git commit -m "release: v1.0.0 (build 100)"
git push origin main

git tag -s v1.0.0 -m "v1.0.0"
git push origin v1.0.0

gh release create v1.0.0 \
  Apps/Mac/build/release/CodingTools-1.0.0.dmg \
  Apps/Mac/build/release/CodingTools-1.0.0.zip \
  Apps/Mac/build/release/CodingTools-1.0.0.sha256 \
  Apps/Mac/build/release/appcast.xml \
  --title "v1.0.0" \
  --notes "$NOTES"
```

### 2.6 应用内更新验证

```bash
# 准备测试机：装旧版本 CodingTools
# 启动 → 设置 → 检查更新
# 验证流程：
#   1. 检测到新版本
#   2. 后台下载
#   3. 提示安装
#   4. 用户同意 → 重启 → 替换
#   5. 启动后版本号为新版本
#   6. 设置 / 收藏 / 进度保留
```

## 3. 失败处理

| 失败 | 检测 | 处理 |
| --- | --- | --- |
| 测试失败 | run-tests.sh 退出码非 0 | 不发版；修复后重试 |
| 构建失败 | xcodebuild 报错 | 看错误；修复后重试 |
| 签名失败 | sign-release.sh 报错 | 检查 Developer ID + keychain |
| 公证失败 | notarytool 错误码 | 查看 `xcrun notarytool history`；修复后重试 |
| Appcast 签名失败 | generate-appcast.sh 报错 | 检查 Sparkle 私钥 |
| Release 失败 | gh release create 报错 | 网络/权限；重试 |
| 应用内更新失败 | 手动测试 | 撤销新版本（不删 tag）；修复后发补丁 |

## 4. 不允许

- 不要在没有通过本地测试的情况下发版
- 不要在 feature 分支发版
- 不要把 `build/`、`DerivedData`、密钥、临时截图提交
- 不要用 `-` 临时签名代替 Developer ID
- 不要伪造公证通过
- 不要把未签名 / 未公证的资产上传
- 不要把「本地构建通过」说成「发版成功」

## 5. 与开发计划的对应

- 阶段 7（Sparkle 接入）完成前，发布脚本是占位
- 阶段 8（内部 Beta）期间使用 `SKIP_PUBLISH=1` 仅本地打包
- v0.9.0 起必须全流程；v1.0.0 强制

## 6. 评审记录

| 日期 | 评审人 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-08-09 | Coordinator (Mavis) | 初稿 | 子代理 C 在阶段 7 完善 |
