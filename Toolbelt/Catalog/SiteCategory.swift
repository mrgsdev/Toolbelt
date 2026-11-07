import SwiftUI

/// Sections of the mcpservers.org catalog.
enum SiteCategory: String, CaseIterable, Identifiable, Hashable {
    case development
    case official
    case all
    case productivity
    case database
    case search
    case webScraping = "web-scraping"
    case fileSystem = "file-system"
    case versionControl = "version-control"
    case communication
    case cloudService = "cloud-service"
    case cloudStorage = "cloud-storage"
    case marketing
    case finance
    case design
    case memory
    case other

    var id: String { rawValue }

    static let primary: [SiteCategory] = [.development, .official, .all]
    static var topics: [SiteCategory] { allCases.filter { !primary.contains($0) } }

    var path: String {
        switch self {
        case .official: "/ru/official"
        case .all: "/ru/all"
        default: "/ru/category/\(rawValue)"
        }
    }

    var webURL: URL { URL(string: "https://mcpservers.org" + path)! }

    var title: String {
        switch self {
        case .development: "Разработка"
        case .official: "Официальные"
        case .all: "Весь каталог"
        case .productivity: "Продуктивность"
        case .database: "Базы данных"
        case .search: "Поиск"
        case .webScraping: "Веб-скрейпинг"
        case .fileSystem: "Файловая система"
        case .versionControl: "Контроль версий"
        case .communication: "Коммуникации"
        case .cloudService: "Облачные сервисы"
        case .cloudStorage: "Облачное хранилище"
        case .marketing: "Маркетинг"
        case .finance: "Финансы"
        case .design: "Дизайн"
        case .memory: "Память"
        case .other: "Другое"
        }
    }

    /// The label the site prints on its cards.
    var siteLabel: String {
        switch self {
        case .development: "Разработка"
        case .official: "Официальный"
        case .all: "Все"
        case .productivity: "Продуктивность"
        case .database: "База данных"
        case .search: "Поиск"
        case .webScraping: "Веб-скрейпинг"
        case .fileSystem: "Файловая система"
        case .versionControl: "Контроль версий"
        case .communication: "Коммуникация"
        case .cloudService: "Облачный сервис"
        case .cloudStorage: "Облачное хранилище"
        case .marketing: "Маркетинг"
        case .finance: "Финансы"
        case .design: "Дизайн"
        case .memory: "Память"
        case .other: "Другое"
        }
    }

    var symbol: String {
        switch self {
        case .development: "hammer.fill"
        case .official: "checkmark.seal.fill"
        case .all: "square.grid.3x3.fill"
        case .productivity: "checklist"
        case .database: "cylinder.split.1x2.fill"
        case .search: "magnifyingglass"
        case .webScraping: "globe"
        case .fileSystem: "folder.fill"
        case .versionControl: "arrow.triangle.branch"
        case .communication: "bubble.left.and.bubble.right.fill"
        case .cloudService: "cloud.fill"
        case .cloudStorage: "icloud.fill"
        case .marketing: "megaphone.fill"
        case .finance: "chart.line.uptrend.xyaxis"
        case .design: "paintpalette.fill"
        case .memory: "brain.head.profile"
        case .other: "puzzlepiece.extension.fill"
        }
    }

    /// Closest shelf category for servers imported from this section.
    var mapped: MCPCategory {
        switch self {
        case .development, .versionControl, .official, .all: .development
        case .productivity: .productivity
        case .database, .fileSystem, .cloudStorage, .memory: .data
        case .search, .webScraping: .web
        case .communication, .marketing, .finance, .cloudService: .integrations
        case .design: .design3D
        case .other: .other
        }
    }

    static func matching(siteLabel label: String) -> SiteCategory? {
        let value = label.trimmed.lowercased()
        return topics.first { $0.siteLabel.lowercased() == value } ?? (value == "разработка" ? .development : nil)
    }
}

enum CatalogSort: String, CaseIterable, Identifiable {
    case newest
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Новые"
        case .name: "А–Я"
        }
    }
}
