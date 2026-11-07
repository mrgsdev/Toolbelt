import Foundation

/// MCP clients whose config the app can edit.
enum MCPClient: String, CaseIterable, Identifiable {
    case claudeCode
    case claudeDesktop
    case cursor
    case vscode
    case windsurf
    case gemini
    case codex
    case lmStudio

    enum Format {
        /// JSON file with servers under a key (`mcpServers` or `servers`).
        case json(key: String)
        /// Codex `config.toml`, `[mcp_servers.<name>]` tables.
        case codexTOML
        /// Claude Code: written through `claude mcp add-json -s user`, read from `~/.claude.json`.
        case claudeCLI
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .claudeDesktop: "Claude Desktop"
        case .cursor: "Cursor"
        case .vscode: "VS Code"
        case .windsurf: "Windsurf"
        case .gemini: "Gemini CLI"
        case .codex: "Codex"
        case .lmStudio: "LM Studio"
        }
    }

    var symbol: String {
        switch self {
        case .claudeCode: "terminal"
        case .claudeDesktop: "macwindow"
        case .cursor: "cursorarrow"
        case .vscode: "chevron.left.forwardslash.chevron.right"
        case .windsurf: "wind"
        case .gemini: "sparkle"
        case .codex: "curlybraces"
        case .lmStudio: "cpu"
        }
    }

    var format: Format {
        switch self {
        case .claudeCode: .claudeCLI
        case .vscode: .json(key: "servers")
        case .codex: .codexTOML
        default: .json(key: "mcpServers")
        }
    }

    /// Home folder; `TOOLBELT_HOME` points it elsewhere for tests.
    static var home: URL {
        if let override = ProcessInfo.processInfo.environment["TOOLBELT_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    var configURL: URL {
        let home = Self.home
        return switch self {
        case .claudeCode: home.appending(path: ".claude.json")
        case .claudeDesktop: home.appending(path: "Library/Application Support/Claude/claude_desktop_config.json")
        case .cursor: home.appending(path: ".cursor/mcp.json")
        case .vscode: home.appending(path: "Library/Application Support/Code/User/mcp.json")
        case .windsurf: home.appending(path: ".codeium/windsurf/mcp_config.json")
        case .gemini: home.appending(path: ".gemini/settings.json")
        case .codex: home.appending(path: ".codex/config.toml")
        case .lmStudio: home.appending(path: ".lmstudio/mcp.json")
        }
    }

    /// A folder whose presence means the client is installed.
    private var markerURL: URL {
        switch self {
        case .claudeCode: Self.home.appending(path: ".claude")
        default: configURL.deletingLastPathComponent()
        }
    }

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: markerURL.path) || FileManager.default.fileExists(atPath: configURL.path)
    }

    var displayPath: String {
        configURL.path.replacingOccurrences(of: Self.home.path, with: "~")
    }

    /// Whether the client needs a restart to see new servers.
    var restartHint: String? {
        switch self {
        case .claudeDesktop: "Перезапусти Claude Desktop, чтобы он подхватил сервер."
        case .claudeCode, .gemini, .codex: "Новые сессии увидят сервер сразу."
        case .vscode: "VS Code подхватит сервер из mcp.json автоматически."
        default: nil
        }
    }
}

struct ClientStatus: Identifiable {
    let client: MCPClient
    let isAvailable: Bool
    /// Server names already present in the client's config.
    let names: Set<String>
    let readError: String?

    var id: String { client.id }
}
