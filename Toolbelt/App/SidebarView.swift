import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case all
    case favorites
    case installed
    case category(MCPCategory)
    case catalog(SiteCategory)
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Query private var servers: [MCPServer]
    /// Sidebar uses outline glyphs only.
    private func outline(_ symbol: String) -> String {
        symbol.replacingOccurrences(of: ".fill", with: "")
    }

    private func count(_ category: MCPCategory) -> Int {
        servers.filter { $0.category == category }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section("Набор навыков") {
                Label("Все навыки", systemImage: "square.stack.3d.up")
                    .badge(servers.count)
                    .tag(SidebarItem.all)
                Label("Избранное", systemImage: "star")
                    .badge(servers.filter(\.isFavorite).count)
                    .tag(SidebarItem.favorites)
                Label("Подключённые", systemImage: "checkmark.circle")
                    .badge(servers.filter(\.isInstalled).count)
                    .tag(SidebarItem.installed)
            }

            Section("Категории") {
                ForEach(MCPCategory.allCases.filter { count($0) > 0 }) { category in
                    Label(category.title, systemImage: outline(category.symbol))
                        .badge(count(category))
                        .tag(SidebarItem.category(category))
                }
            }

            Section("mcpservers.org") {
                ForEach(SiteCategory.primary) { site in
                    Label(site.title, systemImage: outline(site.symbol))
                        .tag(SidebarItem.catalog(site))
                }
                DisclosureGroup("Темы") {
                    ForEach(SiteCategory.topics) { site in
                        Label(site.title, systemImage: outline(site.symbol))
                            .tag(SidebarItem.catalog(site))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .symbolVariant(.none)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Text("Тема")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                ThemeSwitcher()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}
