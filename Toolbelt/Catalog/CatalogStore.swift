import SwiftUI
import Observation

@Observable
@MainActor
final class CatalogStore {
    static let shared = CatalogStore()

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case needsVerification
    }

    enum Source: Hashable {
        case category(SiteCategory)
        case search(String)
    }

    private(set) var source: Source?
    private(set) var entries: [CatalogEntry] = []
    private(set) var total: Int?
    private(set) var phase: Phase = .idle
    private(set) var hasMore = false
    var sort: CatalogSort = .newest

    private var page = 0
    private var pageCount: Int?
    private var generation = 0
    private var details: [String: CatalogDetail] = [:]

    var isSearching: Bool {
        if case .search = source { return true }
        return false
    }

    func entry(id: String?) -> CatalogEntry? {
        guard let id else { return nil }
        return entries.first { $0.id == id }
    }

    /// Switches to a source; keeps already loaded results when it is the same one.
    func show(_ newSource: Source) async {
        if newSource == source, !entries.isEmpty, phase == .loaded { return }
        reset(to: newSource)
        await loadNext()
    }

    func reload() async {
        guard let source else { return }
        reset(to: source)
        await loadNext()
    }

    func loadNext() async {
        guard let source, phase != .loading else { return }
        if page > 0 && !hasMore { return }

        let currentGeneration = generation
        phase = .loading
        do {
            let next = page + 1
            let result = try await CatalogService.shared.fetchList(path: path(for: source, page: next))
            guard currentGeneration == generation else { return }

            let known = Set(entries.map(\.id))
            entries += result.entries.filter { !known.contains($0.id) }
            total = result.total ?? total
            pageCount = result.pageCount ?? pageCount
            page = next
            hasMore = !result.entries.isEmpty && (pageCount.map { next < $0 } ?? (result.entries.count >= 20))
            phase = .loaded
        } catch {
            guard currentGeneration == generation else { return }
            if (error as? CatalogError) == .verificationRequired {
                phase = .needsVerification
            } else {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func detail(for entry: CatalogEntry) async throws -> CatalogDetail {
        if let cached = details[entry.id] { return cached }
        let detail = try await CatalogService.shared.fetchDetail(path: entry.path)
        details[entry.id] = detail
        return detail
    }

    private func reset(to newSource: Source) {
        generation += 1
        source = newSource
        entries = []
        total = nil
        page = 0
        pageCount = nil
        hasMore = false
        phase = .idle
    }

    private func path(for source: Source, page: Int) -> String {
        switch source {
        case .category(let category):
            var path = "\(category.path)?page=\(page)"
            if sort == .name { path += "&sort=name" }
            return path
        case .search(let query):
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
            return "/ru/search?query=\(encoded)&page=\(page)"
        }
    }
}

enum CatalogImporter {
    /// Builds a shelf entry from a catalog card and, when loaded, its detail page.
    static func makeServer(entry: CatalogEntry, detail: CatalogDetail?, fallback: SiteCategory?) -> MCPServer {
        let site = entry.siteCategory ?? fallback ?? .other
        var tags = ["mcpservers.org"]
        if !entry.category.isEmpty { tags.append(entry.category.lowercased()) }
        if entry.official { tags.append("официальный") }

        let githubFromCard = entry.source.contains("github.com") ? entry.source : ""
        let websiteFromCard = entry.source.contains("github.com") ? "" : entry.source

        return MCPServer(
            name: entry.name,
            tagline: tagline(from: entry.summary),
            summary: entry.summary,
            category: site.mapped,
            pricing: .unknown,
            websiteURL: detail?.website ?? (websiteFromCard.isEmpty ? entry.pageURL.absoluteString : websiteFromCard),
            repoURL: detail?.github ?? githubFromCard,
            configJSON: detail?.config ?? "",
            setupSteps: (detail?.commands ?? []).map { "Выполни: `\($0)`" },
            tags: tags,
            createdAt: .now,
            catalogPath: entry.path
        )
    }

    /// First sentence of the description, kept short enough for a card.
    static func tagline(from summary: String) -> String {
        let text = summary.trimmed
        let enders = [". ", "! ", "? "]
        let cut = enders.compactMap { ender -> String.Index? in
            var start = text.startIndex
            while let range = text.range(of: ender, range: start..<text.endIndex) {
                if text.distance(from: text.startIndex, to: range.lowerBound) >= 24 { return range.lowerBound }
                start = range.upperBound
            }
            return nil
        }.min()
        var sentence = cut.map { String(text[..<$0]) } ?? text
        if sentence.count > 120 {
            let prefix = String(sentence.prefix(118))
            let atWord = prefix.range(of: " ", options: .backwards).map { String(prefix[..<$0.lowerBound]) } ?? prefix
            sentence = atWord.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) + "…"
        }
        return sentence
    }
}
