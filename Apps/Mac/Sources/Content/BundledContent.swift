import Foundation

// MARK: - BundledContent
//
// 内置默认教程 / 视频 / 文档元数据。**离线 fallback**，App 首次启动、
// ContentLoading 注入前、远端 manifest 拉取失败时用。
//
// 不下载不重写原文：只保存元数据 + 公开链接，点击 NSWorkspace.open(URL)。
//
// 数据挑选标准：每个 tool 1-2 个权威链接（官方文档 / 官方仓库 / 官方教程）。
// 后续 v1.x 路线：远端 manifest (RemoteContentLoader) 走 GitHub Pages。
public enum BundledContent {
    public static let items: [ContentItem] = [
        // MARK: - AI CLI (7)
        ContentItem(
            id: "claude-code-docs",
            toolID: "claude-code",
            type: .docs,
            title: "Claude Code 官方文档",
            author: "Anthropic",
            sourceURL: URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")!,
            language: "en"
        ),
        ContentItem(
            id: "claude-code-quickstart",
            toolID: "claude-code",
            type: .article,
            title: "Claude Code Quickstart",
            author: "Anthropic",
            sourceURL: URL(string: "https://www.anthropic.com/engineering/claude-code-best-practices")!,
            language: "en",
            tags: ["best-practices", "tutorial"]
        ),
        ContentItem(
            id: "codex-cli",
            toolID: "codex",
            type: .docs,
            title: "OpenAI Codex CLI",
            author: "OpenAI",
            sourceURL: URL(string: "https://github.com/openai/codex")!,
            language: "en",
            tags: ["cli", "open-source"]
        ),
        ContentItem(
            id: "gemini-cli-docs",
            toolID: "gemini-cli",
            type: .docs,
            title: "Gemini CLI 官方文档",
            author: "Google",
            sourceURL: URL(string: "https://github.com/google-gemini/gemini-cli")!,
            language: "en",
            tags: ["google", "cli"]
        ),
        ContentItem(
            id: "grok-cli",
            toolID: "grok-build",
            type: .article,
            title: "Grok CLI 安装指南",
            author: "xAI",
            sourceURL: URL(string: "https://docs.x.ai/docs")!,
            language: "en",
            tags: ["xai", "grok"]
        ),
        ContentItem(
            id: "opencode-docs",
            toolID: "opencode",
            type: .docs,
            title: "OpenCode 官方文档",
            author: "opencode-ai",
            sourceURL: URL(string: "https://opencode.ai/docs")!,
            language: "en",
            tags: ["open-source", "ai-coding"]
        ),
        ContentItem(
            id: "hermes-docs",
            toolID: "hermes",
            type: .docs,
            title: "Hermes Agent 仓库",
            author: "Nous Research",
            sourceURL: URL(string: "https://github.com/NousResearch/hermes-agent")!,
            language: "en",
            tags: ["open-source", "agent"]
        ),

        // MARK: - 传统 CLI (3)
        ContentItem(
            id: "git-pro-book",
            toolID: "git",
            type: .article,
            title: "Pro Git Book (免费)",
            author: "Scott Chacon & Ben Straub",
            sourceURL: URL(string: "https://git-scm.com/book/zh/v2")!,
            language: "zh-Hans",
            tags: ["book", "official"]
        ),
        ContentItem(
            id: "nodejs-docs",
            toolID: "nodejs",
            type: .docs,
            title: "Node.js 官方文档",
            author: "OpenJS Foundation",
            sourceURL: URL(string: "https://nodejs.org/zh-cn/docs")!,
            language: "zh-Hans"
        ),
        ContentItem(
            id: "python-tutorial",
            toolID: "python",
            type: .article,
            title: "Python 官方教程（中文）",
            author: "Python Software Foundation",
            sourceURL: URL(string: "https://docs.python.org/zh-cn/3/tutorial/")!,
            language: "zh-Hans",
            tags: ["official", "tutorial"]
        ),

        // MARK: - 通用开发（无 tool 关联）
        ContentItem(
            id: "sparkle-docs",
            type: .docs,
            title: "Sparkle 自动更新框架",
            author: "Sparkle Project",
            sourceURL: URL(string: "https://sparkle-project.org/documentation/")!,
            language: "en",
            tags: ["macos", "update"]
        ),
        ContentItem(
            id: "swiftui-docs",
            type: .docs,
            title: "SwiftUI 官方文档",
            author: "Apple",
            sourceURL: URL(string: "https://developer.apple.com/documentation/swiftui")!,
            language: "en",
            tags: ["apple", "swiftui"]
        ),
    ]
}
