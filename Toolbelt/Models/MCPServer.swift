import Foundation
import SwiftData

@Model
final class MCPServer {
    @Attribute(.unique) var id: UUID
    var name: String
    var tagline: String
    var summary: String
    var symbol: String
    var categoryRaw: String
    var pricingRaw: String
    var pricingNote: String
    var websiteURL: String
    var repoURL: String
    var configJSON: String
    var setupSteps: [String]
    var capabilities: [String]
    var examplePrompts: [String]
    var tags: [String]
    var notes: String
    var rating: Int
    var isFavorite: Bool
    var isInstalled: Bool
    var createdAt: Date
    /// Path of the source page on mcpservers.org when the server was imported from the catalog.
    var catalogPath: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        tagline: String = "",
        summary: String = "",
        symbol: String = "",
        category: MCPCategory = .other,
        pricing: Pricing = .free,
        pricingNote: String = "",
        websiteURL: String = "",
        repoURL: String = "",
        configJSON: String = "",
        setupSteps: [String] = [],
        capabilities: [String] = [],
        examplePrompts: [String] = [],
        tags: [String] = [],
        notes: String = "",
        rating: Int = 0,
        isFavorite: Bool = false,
        isInstalled: Bool = false,
        createdAt: Date = .now,
        catalogPath: String = ""
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.summary = summary
        self.symbol = symbol.isEmpty ? category.symbol : symbol
        self.categoryRaw = category.rawValue
        self.pricingRaw = pricing.rawValue
        self.pricingNote = pricingNote
        self.websiteURL = websiteURL
        self.repoURL = repoURL
        self.configJSON = configJSON
        self.setupSteps = setupSteps
        self.capabilities = capabilities
        self.examplePrompts = examplePrompts
        self.tags = tags
        self.notes = notes
        self.rating = rating
        self.isFavorite = isFavorite
        self.isInstalled = isInstalled
        self.createdAt = createdAt
        self.catalogPath = catalogPath
    }
}

extension MCPServer {
    var category: MCPCategory {
        get { MCPCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var pricing: Pricing {
        get { Pricing(rawValue: pricingRaw) ?? .free }
        set { pricingRaw = newValue.rawValue }
    }

    var website: URL? { Self.url(from: websiteURL) }
    var repo: URL? { Self.url(from: repoURL) }
    var primaryURL: URL? { website ?? repo }
    var catalogURL: URL? { catalogPath.isEmpty ? nil : URL(string: "https://mcpservers.org" + catalogPath) }

    static func url(from string: String) -> URL? {
        let value = string.trimmed
        guard !value.isEmpty else { return nil }
        return URL(string: value.contains("://") ? value : "https://" + value)
    }

    /// Weighted relevance; 0 means "does not match". Every query token has to match somewhere.
    func relevance(for query: String) -> Int {
        let tokens = query.searchTokens
        guard !tokens.isEmpty else { return 1 }

        var score = 0
        for token in tokens {
            var tokenScore = 0
            if name.localizedStandardContains(token) { tokenScore += 10 }
            if tags.contains(where: { $0.localizedStandardContains(token) }) { tokenScore += 6 }
            if category.title.localizedStandardContains(token) { tokenScore += 5 }
            if tagline.localizedStandardContains(token) { tokenScore += 4 }
            if capabilities.contains(where: { $0.localizedStandardContains(token) }) { tokenScore += 3 }
            if summary.localizedStandardContains(token)
                || notes.localizedStandardContains(token)
                || examplePrompts.contains(where: { $0.localizedStandardContains(token) }) {
                tokenScore += 1
            }
            guard tokenScore > 0 else { return 0 }
            score += tokenScore
        }
        return score
    }

    var shareText: String {
        var parts = ["\(name). \(tagline)"]
        if !summary.isEmpty { parts.append(summary) }
        if let url = primaryURL { parts.append(url.absoluteString) }
        if !configJSON.isEmpty { parts.append(configJSON) }
        return parts.joined(separator: "\n\n")
    }
}

extension Sequence where Element == MCPServer {
    func ordered(by option: SortOption) -> [MCPServer] {
        switch option {
        case .recent:
            sorted { $0.createdAt > $1.createdAt }
        case .name:
            sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .rating:
            sorted { ($0.rating, $0.createdAt) > ($1.rating, $1.createdAt) }
        }
    }
}
