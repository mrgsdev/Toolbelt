import Foundation

/// One card from a mcpservers.org listing page.
struct CatalogEntry: Identifiable, Hashable, Decodable {
    let path: String
    let name: String
    let category: String
    let summary: String
    let source: String
    let official: Bool
    let sponsored: Bool

    var id: String { path }

    var pageURL: URL { URL(string: "https://mcpservers.org" + path)! }

    var sourceURL: URL? { source.isEmpty ? nil : URL(string: source) }

    var logoURL: URL? {
        guard !source.isEmpty else { return nil }
        var components = URLComponents(string: "https://mcpservers.org/api/logo")!
        components.queryItems = [
            URLQueryItem(name: "url", value: source),
            URLQueryItem(name: "size", value: "128"),
            URLQueryItem(name: "v", value: "2"),
            URLQueryItem(name: "fallback", value: "error")
        ]
        return components.url
    }

    var siteCategory: SiteCategory? { SiteCategory.matching(siteLabel: category) }
}

struct CatalogListResponse: Decodable {
    let challenge: Bool
    let entries: [CatalogEntry]
    let total: Int?
    let pageCount: Int?
}

/// Parsed detail page: links, README blocks and code snippets.
struct CatalogDetail: Decodable, Hashable {
    struct Block: Decodable, Hashable {
        enum Kind: String, Decodable {
            case heading, text, item, code
        }

        let kind: Kind
        let text: String
    }

    let challenge: Bool
    let title: String?
    let github: String?
    let website: String?
    let stars: String?
    let codes: [String]?
    let blocks: [Block]?

    var githubURL: URL? { github.flatMap(URL.init(string:)) }
    var websiteURL: URL? { website.flatMap(URL.init(string:)) }

    /// First snippet that looks like a ready MCP client config.
    var config: String? {
        codes?.first { $0.contains("mcpServers") || $0.contains("\"servers\"") }
    }

    /// One-line shell commands that install or launch the server.
    var commands: [String] {
        let prefixes = ["npx ", "uvx ", "pip ", "pipx ", "brew ", "npm ", "pnpm ", "bunx ", "docker ", "curl ",
                        "go install", "cargo install", "dnx ", "uv ", "claude mcp add", "codex mcp add", "gemini mcp add"]
        var seen = Set<String>()
        return (codes ?? [])
            .map(\.trimmed)
            .filter { !$0.contains("\n") && $0.count < 220 }
            .filter { code in prefixes.contains { code.hasPrefix($0) } }
            .filter { seen.insert($0).inserted }
            .prefix(4)
            .map { $0 }
    }
}

enum CatalogError: LocalizedError, Equatable {
    case verificationRequired
    case badResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .verificationRequired: "mcpservers.org просит пройти проверку браузера."
        case .badResponse: "Не удалось разобрать ответ mcpservers.org."
        case .network(let message): message
        }
    }
}
