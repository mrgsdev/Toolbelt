import Foundation
import Observation

/// Actions the «Сервер» menu sends to the server shown in the detail column.
enum ServerAction: Equatable {
    case edit, favorite, install, copyConfig, openSite, delete
}

struct ServerRequest: Equatable {
    let id = UUID()
    let action: ServerAction
}

/// Navigation state shared by the window and the menu bar commands.
@MainActor
@Observable
final class Router {
    static let shared = Router()

    var sidebar: SidebarItem? = .all
    var selectedServer: UUID?
    var selectedEntry: String?
    var searchText = ""
    var isAdding = false
    /// The tour of the app: once at first launch, then from Help.
    var showsOnboarding = false

    /// Bumped by ⌘F so the search field takes focus.
    private(set) var searchRequests = 0
    /// The last «Сервер» menu action; the detail view performs it.
    private(set) var serverRequest: ServerRequest?

    var catalogSection: SiteCategory? {
        if case .catalog(let site)? = sidebar { return site }
        return nil
    }

    /// A shelf server is open in the detail column.
    var hasServerSelection: Bool { catalogSection == nil && selectedServer != nil }

    func focusSearch() {
        searchRequests += 1
    }

    func perform(_ action: ServerAction) {
        serverRequest = ServerRequest(action: action)
    }

    func show(_ item: SidebarItem) {
        searchText = ""
        sidebar = item
    }
}
