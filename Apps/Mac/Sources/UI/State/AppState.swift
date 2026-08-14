import Foundation
import SwiftUI
import Combine
import Domain
import Content
import Installers
import Detection
import LatestVersion
import AIConfigDiscovery
import Updates
import Persistence
import ProcessExecution
import Launching
import AppKit

/// UI 全局状态中枢。**所有 UI 状态都通过 AppState 暴露**，
/// AppModel 只保留 selectedTab / searchText（高冲突，由 Coordinator 拥有）。
///
/// 阶段 4 由子代理 B 实现。
@MainActor
public final class AppState: ObservableObject {

    // MARK: - Published state

    /// 当前选中的工具（用于详情页）
    @Published public var selectedTool: Tool?
    /// 是否展示安装弹窗
    @Published public var installingTool: Tool?
    /// 安装过程输出（脱敏后）
    @Published public var installLog: String = ""
    @Published public var installState: InstallRunState = .idle

    /// 收藏的 tool id 集合
    @Published public var favorites: Set<String> = []
    /// 最近使用（最多 10 个）
    @Published public var recent: [String] = []
    /// 当前 Catalog snapshot
    @Published public var catalogSnapshot: CatalogSnapshot?
    /// 当前 content
    @Published public var contentItems: [ContentItem] = []
    /// 加载错误信息
    @Published public var loadError: String?
    /// 每个 tool 的安装探测结果（key: toolID）。空 = 还没探测或还没跑。
    @Published public var probes: [String: InstallationProbe] = [:]
    @Published public var failedProbeIDs: Set<String> = []
    @Published public var probingToolIDs: Set<String> = []
    /// 每个 tool 的 latest version（key: toolID）。来自 Brew/Npm provider + cache。
    @Published public var latestVersions: [String: String] = [:]
    @Published public var latestQueriedIDs: Set<String> = []
    /// 启动时在用户 home 扫到的 AI CLI 配置文件
    @Published public var discoveredConfigs: [AIConfig] = []
    /// Last Open/launch resolution. Views and the menu bar share `launch(_:)`.
    public private(set) var lastLaunchResult: Result<LaunchTarget, ToolLaunchFailure>?
    /// Invalidated when the user closes the install sheet so a late task cannot revive it.
    public private(set) var installGeneration: UInt64 = 0
    public var toolLauncher: any Launching = MacLauncher()

    // MARK: - Updates（订阅 Sparkle userDriver 状态机）

    /// 更新流程状态（Mirror of `UpdateFlowModel.state`）
    @Published public var updateState: UpdateState = .idle
    /// 本地版本（Mirror of Bundle.main CFBundleShortVersionString）
    @Published public var localVersion: String = ""
    @Published public var localBuild: Int = 0

    /// HomeView "可更新"区显示用的远端版本（从 updateState 提取）
    public var remoteVersionFromAvailable: String? {
        if case .available(let v, _, _) = updateState { return v }
        if case .readyToInstall(let v) = updateState { return v }
        return nil
    }

    // MARK: - Dependencies (可注入的最小闭包集)

    /// 拉取远端 Catalog 快照；返回 nil 表示未注入。
    public var catalogProvider: (() async throws -> CatalogSnapshot?)?
    /// 拉取内容
    public var contentLoader: ContentLoading?
    /// 收藏 / 加载接口（占位：阶段 2 接入后替换为 Store）
    public var favoriteProvider: ((String) async -> [String])?
    public var favoriteSaver: ((String, Bool) async -> Void)?
    /// 持久化存储（P0-G3-1 修复）：默认 nil，AppDelegate / CodingToolsApp 启动时注入
    /// FileJSONStore。启动后 favorites / recents 走 loadFavorites / loadRecents。
    public var persistStore: (any Store)?
    /// 安装器注册表（AdapterRegistry）
    public var installerRegistry: AdapterRegistry = .defaultRegistry()
    /// 真实安装调用桥（默认走 AdapterRegistry）
    public var installer: ((Tool) async -> InstallResult)?
    /// P0-G2-5 修复：HelperClient 在 CodingToolsApp 启动时注入；
    /// 不为 nil 时 install 优先走 XPC，失败回退到 in-process。
    public var helperClient: HelperClient?
    /// 安装探测器（默认 `InstallationDetector()`，可注入 mock）
    public var detector: InstallationDetecting = InstallationDetector()
    /// Latest version provider（默认 brew + npm + cache；可注入 mock）
    public var latestVersionProvider: LatestVersionProvider =
        CachedLatestVersionProvider(
            inner: CompositeLatestVersionProvider(providers: [
                BrewLatestVersionProvider(),
                NpmLatestVersionProvider(),
            ])
        )
    /// 启动时扫用户 home 找 AI CLI 配置（默认 FilesystemAIConfigDiscovery）
    public var configDiscoverer: AIConfigDiscovering = FilesystemAIConfigDiscovery()
    /// 更新流状态机（从 AppDelegate 注入）。如果 nil，UI 用 NoOpUpdateFlowModel。
    public var updateFlowModel: UpdateFlowModel?
    /// AppUpdating 门面闭包（外部注入，避免 AppState 依赖 AppModel —— 跨 framework）。
    /// 默认 nil；CodingToolsApp 启动时设上。
    public var appUpdatingProvider: (() -> AppUpdating?)?
    /// ToastCenter 引用（CodingToolsApp 启动时设上）
    public weak var toastCenter: ToastCenter?

    public init() {}

    // MARK: - Persistence factory (P0-G3-1)

    /// 默认存储位置：~/Library/Application Support/CodingTools/store.json
    public static func makeDefaultStore() -> any Store {
        FileJSONStore()
    }

    // MARK: - Catalog

    public func loadCatalogIfNeeded() async {
        guard catalogSnapshot == nil else { return }
        guard let provider = catalogProvider else {
            // 占位：阶段 2 没接入时显示一个空状态
            loadError = "Catalog 尚未接入"
            return
        }
        do {
            if let snapshot = try await provider() {
                catalogSnapshot = snapshot
                loadError = nil
            }
        } catch {
            loadError = String(describing: error)
            toastCenter?.show(Toast(kind: .error, messageKey: "toast.networkError",
                                     messageArg: error.localizedDescription,
                                     retry: { [weak self] in
                Task { @MainActor in
                    self?.catalogSnapshot = nil
                    await self?.loadCatalogIfNeeded()
                }
            }))
        }
    }

    public func refreshCatalog() async {
        guard let provider = catalogProvider else { return }
        do {
            if let snapshot = try await provider() {
                catalogSnapshot = snapshot
                loadError = nil
            }
        } catch {
            loadError = String(describing: error)
        }
    }

    public var tools: [Tool] {
        catalogSnapshot?.tools ?? Tool.placeholderTools
    }

    // MARK: - Detection

    /// 探测所有当前 tools 的安装状态。结果存到 `probes`。
    /// 触发时机：catalog 加载完成后 + 用户手动刷新。
    public func refreshProbes() async {
        let tools = self.tools
        probingToolIDs = Set(tools.map(\.id))
        let results = await detector.probeAll(tools: tools)
        var dict: [String: InstallationProbe] = [:]
        for probe in results { dict[probe.toolID] = probe }
        probes = dict
        probingToolIDs = []
        failedProbeIDs = []
    }

    /// 探测单个 tool（详情页用）
    public func refreshProbe(toolID: String) async {
        guard let tool = tools.first(where: { $0.id == toolID }) else { return }
        probingToolIDs.insert(toolID)
        let probe = await detector.probe(tool: tool)
        probes[toolID] = probe
        failedProbeIDs.remove(toolID)
        probingToolIDs.remove(toolID)
    }

    public func markProbeFailed(toolID: String) {
        failedProbeIDs.insert(toolID)
        probes[toolID] = nil
    }

    // MARK: - Latest version

    /// 拉所有 tool 的 latest version。结果存到 `latestVersions`。
    /// 触发时机：catalog 加载完成后 + 探测完成后（installed version 已知）。
    public func refreshLatestVersions() async {
        let tools = self.tools
        // 并行拉（cached provider 内部串行）
        await withTaskGroup(of: (String, String?).self) { group in
            for tool in tools {
                let toolID = tool.id
                let installed = probes[toolID]?.installedVersion
                group.addTask { [latestVersionProvider] in
                    let v = await latestVersionProvider.latestVersion(
                        toolID: toolID,
                        installedVersion: installed
                    )
                    return (toolID, v)
                }
            }
            for await (toolID, v) in group {
                latestQueriedIDs.insert(toolID)
                if let v {
                    latestVersions[toolID] = v
                } else {
                    latestVersions[toolID] = nil
                }
            }
        }
    }

    public func latestFact(for tool: Tool) -> LatestVersionFact {
        if !TrustedInstallOption.canQueryLatest(tool.installOptions) {
            return .unavailable
        }
        if let value = latestVersions[tool.id] {
            return .known(value)
        }
        if latestQueriedIDs.contains(tool.id) {
            return .unavailable
        }
        return .notQueried
    }

    public func probeOutcome(for toolID: String) -> ToolProbeOutcome {
        if probingToolIDs.contains(toolID) { return .checking }
        if failedProbeIDs.contains(toolID) { return .failed }
        if let probe = probes[toolID] { return .result(probe) }
        return .missing
    }

    public func operationFact(for toolID: String) -> ToolOperationFact {
        guard installingTool?.id == toolID else { return .idle }
        switch installState {
        case .running, .cancelling: return .running
        case .failed: return .failed
        case .completedPendingConfirmation: return .completedPendingConfirmation
        default: return .idle
        }
    }

    public func presentation(for tool: Tool) -> ToolPresentation {
        ToolPresentationMapper.map(
            options: tool.installOptions,
            probe: probeOutcome(for: tool.id),
            latest: latestFact(for: tool),
            operation: operationFact(for: tool.id)
        )
    }

    /// 取 tool 的 latest version（UI 端用）
    public func latestVersion(for toolID: String) -> String? {
        latestVersions[toolID]
    }

    // MARK: - Config discovery

    /// 扫 home 目录找 AI CLI 配置。触发时机：app 启动。
    public func discoverAIConfigs() async {
        let results = await configDiscoverer.discover()
        discoveredConfigs = results
    }

    /// 把某个 discovered config 的 toolID 加入 favorites（用户点「收藏」时调）
    public func adoptDiscoveredConfig(_ config: AIConfig) {
        favorites.insert(config.toolID)
    }

    /// 比较 installed vs latest 是否真的需要升级。缺少 latest 时不得当作已是最新。
    public func isOutdated(toolID: String) -> Bool {
        guard let tool = tools.first(where: { $0.id == toolID }) else { return false }
        return presentation(for: tool).showsUpdateAction
    }

    /// 取某个 tool 的探测结果（UI 端常用）
    public func probe(for toolID: String) -> InstallationProbe? {
        probes[toolID]
    }

    // MARK: - Content

    public func loadContentIfNeeded() async {
        guard contentItems.isEmpty else { return }
        // 1) 内置默认数据：保证 Content tab 永远有内容可看（offline / loader 失败都 OK）
        if contentItems.isEmpty {
            contentItems = BundledContent.items
        }
        // 2) 远端 loader（可选）：拿更新后的内容
        guard let loader = contentLoader else { return }
        do {
            let remote = try await loader.loadAll()
            if !remote.isEmpty {
                contentItems = remote
            }
        } catch {
            // 失败保持 BundledContent，但 emit 提示
            _ = error
            toastCenter?.show(Toast(kind: .warning, messageKey: "toast.networkError",
                                     messageArg: error.localizedDescription))
        }
    }

    public func contentFor(toolID: String) -> [ContentItem] {
        contentItems.filter { $0.toolID == toolID }
    }

    // MARK: - Favorites

    public func isFavorite(_ toolID: String) -> Bool {
        favorites.contains(toolID)
    }

    public func toggleFavorite(_ toolID: String) {
        if favorites.contains(toolID) {
            favorites.remove(toolID)
            Task { await favoriteSaver?(toolID, false) }
            if let store = persistStore {
                Task { try? await store.removeFavorite(toolID: toolID) }
            }
        } else {
            favorites.insert(toolID)
            Task { await favoriteSaver?(toolID, true) }
            if let store = persistStore {
                Task { try? await store.saveFavorite(toolID: toolID) }
            }
        }
    }

    public func loadFavorites() async {
        // 优先用 Store（P0-G3-1 修复）
        if let store = persistStore {
            if let list = try? await store.loadFavorites() {
                favorites = Set(list)
                return
            }
        }
        // 兜底：旧闭包接口
        guard let provider = favoriteProvider else { return }
        let list = await provider("all")
        favorites = Set(list)
    }

    // MARK: - Recent

    public func markRecent(_ toolID: String) {
        recent.removeAll(where: { $0 == toolID })
        recent.insert(toolID, at: 0)
        if recent.count > 10 { recent = Array(recent.prefix(10)) }
        if let store = persistStore {
            Task { try? await store.saveRecent(toolID: toolID, maxItems: 10) }
        }
    }

    /// 重启时从 Store 恢复最近列表。
    public func loadRecents() async {
        guard let store = persistStore,
              let list = try? await store.loadRecents() else { return }
        recent = list
    }

    public func recentTools() -> [Tool] {
        recent.compactMap { id in tools.first(where: { $0.id == id }) }
    }

    public func favoriteTools() -> [Tool] {
        tools.filter { favorites.contains($0.id) }
    }

    // MARK: - Install (真实接入 AdapterRegistry，缺依赖时 fallback 到占位输出)

    /// 当前正在跑的 install Task 句柄 — 取消时调用 cancel()（P0-G2-6 / G4-7）
    private var installTask: Task<Void, Never>?

    public func startInstall(_ tool: Tool) {
        startInstall(tool, option: nil)
    }

    /// 接收具体 InstallOption 的版本。缺少可信 option 时拒绝启动。
    public func startInstall(_ tool: Tool, option: InstallOption?) {
        if installState == .running || installState == .cancelling { return }
        guard let resolved = InstallConfirmation.resolvedOption(tool: tool, preferred: option) else {
            installingTool = nil
            installLog = ""
            installState = .idle
            return
        }
        installingTool = tool
        installLog = ""
        installState = .running
        installGeneration += 1
        let generation = installGeneration
        let toolRef = tool
        let optRef = resolved
        installTask = Task { @MainActor [weak self] in
            await self?.runInstall(tool: toolRef, option: optRef, generation: generation)
        }
    }

    @MainActor
    private func runInstall(tool: Tool, option: InstallOption?, generation: UInt64) async {
        guard let opt = option, TrustedInstallOption.isTrusted(opt) else {
            finishInstallIfCurrent(generation: generation, .failed)
            return
        }
        installLog += "==> 准备安装 \(tool.name) [\(opt.type.rawValue)]\n"
        do {
            let descriptor = try opt.toInstallAction()
            let action = Self.descriptorToAction(descriptor)
            let progress: InstallProgressHandler = { [weak self] p in
                // P0-G3-2：进度消息脱敏后再写入 installLog
                let safe = OutputRedactor.redact(p.message)
                Task { @MainActor in
                    self?.installLog += "[\(p.stage.rawValue)] \(safe)\n"
                }
            }
            // 阶段 9 修复（P0-G2-5）：走 HelperClient（Helper 不可用回退 in-process）
            let result = try await executeWithHelperFallback(
                toolID: tool.id,
                action: action,
                progress: progress
            )
            if result.exitCode == 0 {
                await refreshProbe(toolID: tool.id)
                let probe = probes[tool.id]
                let probeLooksInstalled = probe?.healthStatus == .installed || probe?.healthStatus == .outdated
                if probeLooksInstalled {
                    installLog += "==> 安装完成\n"
                    finishInstallIfCurrent(generation: generation, .completed)
                    if let store = persistStore, let probe {
                        try? await store.saveInstallation(probe)
                    }
                } else {
                    installLog += "==> 安装完成，状态待确认\n"
                    finishInstallIfCurrent(generation: generation, .completedPendingConfirmation)
                }
            } else {
                installLog += "==> 安装失败，退出码 \(result.exitCode)\n"
                finishInstallIfCurrent(generation: generation, .failed)
            }
        } catch is CancellationError {
            installLog += "\n[用户取消] 已停止底层进程\n"
            finishInstallIfCurrent(generation: generation, .cancelled)
        } catch {
            installLog += "==> 失败: \(error)\n"
            finishInstallIfCurrent(generation: generation, .failed)
        }
    }

    /// Late outcomes after the user closed the sheet must not change `installState`.
    public func finishInstallIfCurrent(generation: UInt64, _ newState: InstallRunState) {
        guard generation == installGeneration else { return }
        installState = newState
        installTask = nil
    }

    /// Shared Open/启动 entry used by the menu bar, catalog cards, and tool detail.
    public func launch(_ tool: Tool) {
        markRecent(tool.id)
        let result = ToolLaunchPlanner.makeTarget(for: tool)
        lastLaunchResult = result
        switch result {
        case .success(let target):
            let launcher = toolLauncher
            Task {
                try? await launcher.launch(target)
            }
        case .failure(let failure):
            let arg: String
            switch failure {
            case .noCapability: arg = "no launch capability"
            case .binaryNotFound(let name): arg = "binary not found: \(name)"
            case .appNotFound(let name): arg = "app not found: \(name)"
            case .noURL: arg = "no url"
            case .urlBlocked(let host): arg = host
            }
            let key: LocalizedStringKey = {
                if case .urlBlocked = failure { return "content.url_blocked" }
                return "menubar.launch_error"
            }()
            toastCenter?.show(Toast(kind: .warning, messageKey: key, messageArg: arg))
        }
    }

    /// P0-G2-5：先尝试 HelperClient，失败回退到 in-process AdapterRegistry。
    private func executeWithHelperFallback(
        toolID: String,
        action: InstallAction,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        // 阶段 9 接入后，HelperClient.install(...) 是首选。
        // 当前 HelperClient 是 stub 接口；暂时走 AdapterRegistry，并标记日志。
        // P1-G2-1 / P0-G2-1 修复：使用 executeWithAction 替代 execute(plan)
        if let helper = helperClient {
            do {
                let plan = try await adapterRegistry(for: action).plan(toolID: toolID, action: action)
                let response = try await helper.install(plan: plan, action: action)
                return InstallResult(
                    planID: plan.id,
                    exitCode: response.exitCode,
                    resolvedVersion: response.resolvedVersion
                )
            } catch {
                installLog += "[helper 不可用，回退到 in-process executor] \(error)\n"
            }
        }
        return try await installerRegistry.executeWithAction(
            toolID: toolID,
            action: action,
            progress: progress
        )
    }

    private func adapterRegistry(for action: InstallAction) -> InstallAdapter {
        switch action {
        case .homebrewFormula: return installerRegistry.adapter(for: .homebrewFormula)!
        case .homebrewCask:    return installerRegistry.adapter(for: .homebrewCask)!
        case .miseTool:        return installerRegistry.adapter(for: .miseTool)!
        case .officialArtifact: return installerRegistry.adapter(for: .officialArtifact)!
        case .npmGlobal:       return installerRegistry.adapter(for: .npmGlobal)!
        }
    }

    /// InstallActionDescriptor → Installers.InstallAction 桥接
    private static func descriptorToAction(_ d: InstallActionDescriptor) -> InstallAction {
        switch d {
        case .formula(let name): return .homebrewFormula(name: name)
        case .cask(let name): return .homebrewCask(name: name)
        case .mise(let name, let v): return .miseTool(name: name, version: v)
        case .artifact(let url, let sha, let bid, let tid):
            return .officialArtifact(url: url, sha256: sha, bundleID: bid, teamID: tid)
        case .npm(let pkg, let url, let rule):
            return .npmGlobal(packageName: pkg, scriptURL: url, versionRule: rule)
        }
    }

    public func cancelInstall() {
        // P0-G2-6 / G4-7：取消时真正停掉底层 Task + 调用 adapter.cancel
        if installState == .running {
            installState = .cancelling
        }
        if let task = installTask {
            task.cancel()
        }
        if let tool = installingTool,
           let opt = InstallConfirmation.resolvedOption(tool: tool) ?? tool.installOptions.first,
           let action = try? opt.toInstallAction() {
            let actionType: InstallActionType = {
                switch action {
                case .formula: return .homebrewFormula
                case .cask:    return .homebrewCask
                case .mise:    return .miseTool
                case .artifact: return .officialArtifact
                case .npm:     return .npmGlobal
                }
            }()
            Task { [installerRegistry] in
                await installerRegistry.adapter(for: actionType)?.cancel(planID: "")
            }
        }
        installLog += "\n[用户取消]"
    }

    public func closeInstall() {
        if installState == .running || installState == .cancelling {
            cancelInstall()
        }
        installGeneration += 1
        installingTool = nil
        installLog = ""
        installState = .idle
        installTask = nil
    }

    /// 清除操作历史（仅 installations 表；不影响 favorites / catalog）。
    public func clearOperationHistory() async {
        if let store = persistStore {
            try? await store.clearOperationHistory()
        }
        probes = [:]
    }

    // MARK: - Updates (Sparkle)

    /// 绑定到 UpdateFlowModel：订阅它的状态 emit。
    /// AppDelegate 在 applicationDidFinishLaunching 里调用一次。
    public func bindUpdates(_ model: UpdateFlowModel) {
        self.updateFlowModel = model
        model.addObserver(self)
    }

    /// 触发 Sparkle 检查更新（拉 appcast + 验签 + emit 状态到 UI）
    public func checkForUpdates() {
        guard AppUpdateCheckGuard.canStartCheck(updateState) else { return }
        appUpdatingProvider?()?.checkForUpdates()
    }

    /// 确认安装（从 .readyToInstall 状态继续；用户点「立即重启」）
    public func confirmInstallUpdate() {
        updateFlowModel?.fulfillDecision(.install)
    }

    /// 取消安装
    public func cancelUpdate() {
        updateFlowModel?.fulfillDecision(.dismiss)
    }
}

// MARK: - UpdateObserver

extension AppState: UpdateObserver {
    public func updateStateChanged(_ state: UpdateState) {
        self.updateState = state
    }

    public func updateMetadata(localVersion: String, localBuild: Int) {
        self.localVersion = localVersion
        self.localBuild = localBuild
    }
}

public enum InstallRunState: Equatable, Sendable {
    case idle
    case running
    case cancelling      // P0-G2-6：取消请求已发出，等待底层 Task 退出
    case completed
    case completedPendingConfirmation
    case failed
    case cancelled
}

// MARK: - Placeholder data

public extension Tool {
    /// v1.0.0 占位数据：7 个 AI CLI + 3 个传统 CLI = 10 个工具。
    /// 真实 Catalog 接通后，placeholderTools 会被 catalogSnapshot.tools 替代。
    static let placeholderTools: [Tool] = [
        // 7 个 AI CLI（v1.0.0 主推）
        Tool(id: "claude-code", slug: "claude-code", name: "Claude Code",
             category: .aiCoding, installOptions: [
            InstallOption(type: .npmGlobal, packageName: "@anthropic-ai/claude-code",
                          versionRule: nil, riskLevel: .low)
        ]),
        Tool(id: "codex", slug: "codex", name: "Codex",
             category: .aiCoding, installOptions: [
            InstallOption(type: .npmGlobal, packageName: "@openai/codex",
                          versionRule: nil, riskLevel: .low)
        ]),
        Tool(id: "gemini-cli", slug: "gemini-cli", name: "Gemini CLI",
             category: .aiCoding, installOptions: [
            InstallOption(type: .npmGlobal, packageName: "@google/gemini-cli",
                          versionRule: nil, riskLevel: .low)
        ]),
        Tool(id: "grok-build", slug: "grok-build", name: "Grok Build",
             category: .aiCoding, installOptions: [
            InstallOption(type: .npmGlobal, packageName: nil,
                          url: URL(string: "https://x.ai/cli/install.sh"),
                          riskLevel: .low)
        ]),
        Tool(id: "opencode", slug: "opencode", name: "OpenCode",
             category: .aiCoding, installOptions: [
            InstallOption(type: .npmGlobal, packageName: "opencode-ai@latest",
                          riskLevel: .low)
        ]),
        Tool(id: "openclaw", slug: "openclaw", name: "OpenClaw",
             category: .aiCoding, installOptions: [
            InstallOption(type: .npmGlobal, packageName: "openclaw@latest",
                          riskLevel: .low)
        ]),
        Tool(id: "hermes", slug: "hermes", name: "Hermes",
             category: .aiCoding, installOptions: [
            InstallOption(type: .npmGlobal, packageName: nil,
                          url: URL(string: "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"),
                          riskLevel: .low)
        ]),
        // 3 个传统 CLI（保留）
        Tool(id: "git", slug: "git", name: "Git", category: .gitCollaboration),
        Tool(id: "nodejs", slug: "nodejs", name: "Node.js", category: .languageRuntime),
        Tool(id: "python", slug: "python", name: "Python", category: .languageRuntime),
    ]
}
