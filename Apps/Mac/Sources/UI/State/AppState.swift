import Foundation
import SwiftUI
import Combine
import Domain
import Content
import Installers

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

    // MARK: - Dependencies (可注入的最小闭包集)

    /// 拉取远端 Catalog 快照；返回 nil 表示未注入。
    public var catalogProvider: (() async throws -> CatalogSnapshot?)?
    /// 拉取内容
    public var contentLoader: ContentLoading?
    /// 收藏 / 加载接口（占位：阶段 2 接入后替换为 Store）
    public var favoriteProvider: ((String) async -> [String])?
    public var favoriteSaver: ((String, Bool) async -> Void)?
    /// 安装器注册表（AdapterRegistry）
    public var installerRegistry: AdapterRegistry = .defaultRegistry()
    /// 真实安装调用桥（默认走 AdapterRegistry）
    public var installer: ((Tool) async -> InstallResult?)?

    public init() {}

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

    // MARK: - Content

    public func loadContentIfNeeded() async {
        guard contentItems.isEmpty else { return }
        guard let loader = contentLoader else {
            return
        }
        do {
            contentItems = try await loader.loadAll()
        } catch {
            loadError = String(describing: error)
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
        } else {
            favorites.insert(toolID)
            Task { await favoriteSaver?(toolID, true) }
        }
    }

    public func loadFavorites() async {
        guard let provider = favoriteProvider else { return }
        let list = await provider("all")
        favorites = Set(list)
    }

    // MARK: - Recent

    public func markRecent(_ toolID: String) {
        recent.removeAll(where: { $0 == toolID })
        recent.insert(toolID, at: 0)
        if recent.count > 10 { recent = Array(recent.prefix(10)) }
    }

    public func recentTools() -> [Tool] {
        recent.compactMap { id in tools.first(where: { $0.id == id }) }
    }

    public func favoriteTools() -> [Tool] {
        tools.filter { favorites.contains($0.id) }
    }

    // MARK: - Install (真实接入 AdapterRegistry，缺依赖时 fallback 到占位输出)

    public func startInstall(_ tool: Tool) {
        installingTool = tool
        installLog = ""
        installState = .running
        Task { @MainActor in
            // 选择第一个 installOption 跑（v1.0.0 一工具一来源）
            guard let opt = tool.installOptions.first else {
                installLog += "==> \(tool.name) 暂未提供安装来源（仅展示）\n"
                installState = .completed
                return
            }
            installLog += "==> 准备安装 \(tool.name) [\(opt.type.rawValue)]\n"
            do {
                let descriptor = try opt.toInstallAction()
                let action = Self.descriptorToAction(descriptor)
                let progress: InstallProgressHandler = { [weak self] p in
                    Task { @MainActor in
                        self?.installLog += "[\(p.stage.rawValue)] \(p.message)\n"
                    }
                }
                let result = try await installerRegistry.execute(
                    toolID: tool.id,
                    action: action,
                    progress: progress
                )
                if result.exitCode == 0 {
                    installLog += "==> 安装完成 ✅\n"
                    installState = .completed
                } else {
                    installLog += "==> 安装失败，退出码 \(result.exitCode)\n"
                    installState = .failed
                }
            } catch {
                installLog += "==> 失败: \(error)\n"
                installState = .failed
            }
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
        installState = .cancelled
        installLog += "\n[用户取消]"
    }

    public func closeInstall() {
        installingTool = nil
        installLog = ""
        installState = .idle
    }
}

public enum InstallRunState: Equatable, Sendable {
    case idle
    case running
    case completed
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
