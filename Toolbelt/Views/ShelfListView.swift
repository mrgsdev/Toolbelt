import SwiftUI
import SwiftData

/// Middle column: the user's own servers for the selected sidebar filter.
struct ShelfListView: View {
    let filter: SidebarItem
    let query: String
    @Binding var selection: UUID?
    var onAdd: () -> Void
    var onDelete: (MCPServer) -> Void

    @Query(sort: \MCPServer.createdAt, order: .reverse) private var servers: [MCPServer]
    @AppStorage("shelf.sort") private var sort: SortOption = .recent
    @Environment(\.modelContext) private var context

    private struct Scored {
        let server: MCPServer
        let score: Int
    }

    private var base: [MCPServer] {
        switch filter {
        case .favorites: servers.filter(\.isFavorite)
        case .installed: servers.filter(\.isInstalled)
        case .category(let category): servers.filter { $0.category == category }
        default: servers
        }
    }

    private var items: [MCPServer] {
        let trimmedQuery = query.trimmed
        guard !trimmedQuery.isEmpty else { return base.ordered(by: sort) }
        let scored: [Scored] = base
            .map { Scored(server: $0, score: $0.relevance(for: trimmedQuery)) }
            .filter { $0.score > 0 }
        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.server.name.localizedStandardCompare(rhs.server.name) == .orderedAscending
            }
            .map(\.server)
    }

    private var title: String {
        switch filter {
        case .favorites: "Избранное"
        case .installed: "Подключённые"
        case .category(let category): category.title
        default: "Набор навыков"
        }
    }

    var body: some View {
        let list = items
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    header(count: list.count)
                        .padding(.bottom, 8)

                    ForEach(list) { server in
                        Button {
                            selection = server.id
                        } label: {
                            ServerRow(server: server, highlight: query, isSelected: selection == server.id)
                        }
                        .buttonStyle(PressableStyle())
                        .id(server.id)
                        .contextMenu {
                            ServerContextMenu(server: server) { onDelete(server) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .animation(.snappy, value: list.map(\.id))
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.downArrow) {
                move(by: 1, in: list, proxy: proxy)
                return .handled
            }
            .onKeyPress(.upArrow) {
                move(by: -1, in: list, proxy: proxy)
                return .handled
            }
        }
        .background(Theme.canvas)
        .overlay {
            if list.isEmpty { emptyState }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Сортировка", selection: $sort) {
                        ForEach(SortOption.allCases) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Button("Рекомендация разработчика", systemImage: "sparkles") {
                        UserDefaults.standard.set(false, forKey: DeveloperPicks.hiddenKey)
                        selection = nil
                    }
                } label: {
                    Label("Сортировка", systemImage: "arrow.up.arrow.down")
                }
                .help("Сортировка")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAdd) {
                    Label("Добавить", systemImage: "plus")
                }
                .help("Новый MCP-сервер (⌘N)")
            }
        }
    }

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 24, weight: .regular))
                .tracking(-0.4)
            Text(query.trimmed.isEmpty ? serversCount(count) : "Найдено: \(count)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.trimmed.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            switch filter {
            case .favorites:
                ContentUnavailableView("Пока без любимчиков", systemImage: "star",
                                       description: Text("Отмечай звёздочкой серверы, к которым возвращаешься чаще всего."))
            case .installed:
                ContentUnavailableView("Ничего не подключено", systemImage: "powerplug",
                                       description: Text("Отмечай серверы, которые уже подключил агенту, чтобы видеть рабочий набор."))
            default:
                ContentUnavailableView {
                    Label("Набор пуст", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("Добавьте сервер вручную, найдите его в каталоге mcpservers.org или начните с рекомендации разработчика на главной.")
                } actions: {
                    HStack(spacing: 8) {
                        PillButton(title: "Добавить MCP", symbol: "plus", style: .primary, action: onAdd)
                        PillButton(title: "Рекомендация", symbol: "sparkles") {
                            UserDefaults.standard.set(false, forKey: DeveloperPicks.hiddenKey)
                            selection = nil
                        }
                    }
                }
            }
        }
    }

    private func move(by offset: Int, in list: [MCPServer], proxy: ScrollViewProxy) {
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selection } ?? (offset > 0 ? -1 : list.count)
        let next = min(max(current + offset, 0), list.count - 1)
        selection = list[next].id
        withAnimation(.snappy) { proxy.scrollTo(list[next].id) }
    }
}
