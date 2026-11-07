import SwiftUI

enum MCPCategory: String, CaseIterable, Identifiable {
    case development
    case design3D
    case productivity
    case web
    case codeSearch
    case data
    case integrations
    case uiComponents
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .development: "Разработка"
        case .design3D: "Дизайн и 3D"
        case .productivity: "Задачи"
        case .web: "Веб"
        case .codeSearch: "Поиск по коду"
        case .data: "Данные"
        case .integrations: "Интеграции"
        case .uiComponents: "UI-компоненты"
        case .other: "Другое"
        }
    }

    var symbol: String {
        switch self {
        case .development: "hammer.fill"
        case .design3D: "cube.transparent.fill"
        case .productivity: "checklist"
        case .web: "cursorarrow.click.2"
        case .codeSearch: "chevron.left.forwardslash.chevron.right"
        case .data: "cylinder.split.1x2.fill"
        case .integrations: "point.3.connected.trianglepath.dotted"
        case .uiComponents: "square.grid.2x2.fill"
        case .other: "puzzlepiece.extension.fill"
        }
    }
}

enum Pricing: String, CaseIterable, Identifiable {
    case free
    case freemium
    case paid
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown: "Цена не указана"
        case .free: "Бесплатно"
        case .freemium: "Есть free-тариф"
        case .paid: "Платно"
        }
    }

    var shortTitle: String {
        switch self {
        case .free: "Free"
        case .freemium: "Freemium"
        case .paid: "Paid"
        case .unknown: "?"
        }
    }

    var symbol: String {
        switch self {
        case .free: "gift.fill"
        case .freemium: "sparkles"
        case .paid: "creditcard.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case recent
    case name
    case rating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "Сначала новые"
        case .name: "По названию"
        case .rating: "По оценке"
        }
    }

    var symbol: String {
        switch self {
        case .recent: "clock"
        case .name: "textformat"
        case .rating: "star"
        }
    }
}
