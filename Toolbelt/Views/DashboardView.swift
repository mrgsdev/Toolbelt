import SwiftUI
import SwiftData
import AppKit

/// Detail placeholder for the skill set: title, developer picks, metrics, favorites, clients and categories.
struct DashboardView: View {
    var onSelect: (MCPServer) -> Void
    var onSelectCategory: (MCPCategory) -> Void
    var onOpenCatalog: () -> Void
    var onAdd: () -> Void

    @Query(sort: \MCPServer.createdAt, order: .reverse) private var servers: [MCPServer]
    @Environment(ClientRegistry.self) private var registry
    @Environment(\.modelContext) private var context
    @AppStorage(DeveloperPicks.hiddenKey) private var picksHidden = false
    @State private var toast: ToastMessage?

    private var favorites: [MCPServer] { servers.filter(\.isFavorite) }
    private var categories: [MCPCategory] {
        MCPCategory.allCases.filter { category in servers.contains { $0.category == category } }
    }
    private var picks: [ServerTemplate] { DeveloperPicks.missing(from: servers) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Набор навыков")
                            .font(.system(size: 34, weight: .regular))
                            .tracking(-0.6)
                        Text(servers.isEmpty ? "Пока пустой" : serversCount(servers.count))
                            .font(.system(size: 34, weight: .regular))
                            .tracking(-0.6)
                            .foregroundStyle(Theme.tertiary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        PillButton(title: "Каталог", symbol: "globe", action: onOpenCatalog)
                        PillButton(title: "Добавить", symbol: "plus", style: .primary, action: onAdd)
                    }
                }

                if !picksHidden && !picks.isEmpty {
                    recommendations
                } else if servers.isEmpty {
                    Panel {
                        HStack(spacing: 14) {
                            IconTile(symbol: "square.stack.3d.up", size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("В наборе пока ничего нет")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Добавьте свой сервер (⌘N) или найдите готовый в каталоге mcpservers.org (⌘4).")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            if picksHidden {
                                PillButton(title: "Рекомендация разработчика", symbol: "sparkles") { picksHidden = false }
                            }
                        }
                    }
                }

                MetricRow {
                    MetricCard(value: "\(servers.count)", title: "В наборе",
                               note: "\(servers.filter { !$0.catalogPath.isEmpty }.count) из каталога", dark: true)
                    MetricCard(value: "\(servers.filter(\.isInstalled).count)", title: "Подключено",
                               note: "стоят в клиентах")
                    MetricCard(value: "\(favorites.count)", title: "Любимых", note: nil)
                    MetricCard(value: "\(registry.available.count)", title: "Клиентов на Mac",
                               note: registry.available.map(\.client.title).prefix(3).joined(separator: ", "))
                }

                if !favorites.isEmpty {
                    section("Любимые") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                            ForEach(favorites) { server in
                                Button { onSelect(server) } label: { FeaturedCard(server: server) }
                                    .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    section("Клиенты") {
                        Panel {
                            VStack(spacing: 0) {
                                let available = registry.available
                                if available.isEmpty {
                                    Text("MCP-клиенты не найдены.").foregroundStyle(Theme.secondary)
                                }
                                ForEach(Array(available.enumerated()), id: \.element.id) { index, status in
                                    ClientSummaryRow(status: status, shelfNames: shelfNames)
                                    if index < available.count - 1 {
                                        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46)
                                    }
                                }
                            }
                        }
                    }
                    if !categories.isEmpty {
                        section("Категории") {
                            VStack(spacing: 8) {
                                ForEach(categories) { category in
                                    Button { onSelectCategory(category) } label: {
                                        CategoryTile(title: category.title, symbol: category.symbol,
                                                     subtitle: serversCount(servers.filter { $0.category == category }.count))
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                        .frame(width: 300)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 26)
            .padding(.bottom, 40)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .task { await registry.refresh() }
        .toast($toast)
    }

    /// «Рекомендация разработчика»: the starter set, one card per server that is not in the set yet.
    private var recommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Рекомендация разработчика")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                    Text("Серверы, с которых я бы начал. Добавляйте по одному или все сразу, блок можно скрыть.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                PillButton(title: "Добавить все (\(picks.count))", symbol: "plus", style: .primary) {
                    let added = DeveloperPicks.add(picks, to: context)
                    toast = ToastMessage(text: "В набор добавлено: \(serversCount(added))", symbol: "plus")
                }
                Button {
                    withAnimation(.snappy) { picksHidden = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 30, height: 30)
                        .overlay { Circle().strokeBorder(Theme.hairlineStrong) }
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help("Скрыть рекомендацию. Вернуть её можно в Настройках.")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(picks) { template in
                    PickCard(template: template) {
                        DeveloperPicks.add([template], to: context)
                        toast = ToastMessage(text: "«\(template.name)» в наборе", symbol: "plus")
                    }
                }
            }
        }
        .animation(.snappy, value: picks.map(\.id))
    }

    /// Config names of every shelf server, to count how many of them each client has.
    private var shelfNames: Set<String> {
        Set(servers.flatMap { ConfigInstaller.serverNames(for: $0) })
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondary)
            content()
        }
    }
}

private struct ClientSummaryRow: View {
    let status: ClientStatus
    let shelfNames: Set<String>

    var body: some View {
        let fromShelf = status.names.intersection(shelfNames).count
        HStack(spacing: 12) {
            IconTile(symbol: status.client.symbol, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.client.title)
                    .font(.system(size: 13, weight: .medium))
                Text(status.client.displayPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(serversCount(status.names.count))
                    .font(.system(size: 12, weight: .medium))
                if fromShelf > 0 {
                    LiveBadge(text: "\(fromShelf) из набора")
                } else {
                    Text("из набора нет").font(.system(size: 10.5)).foregroundStyle(Theme.tertiary)
                }
            }
            Button {
                let url = status.client.configURL
                if FileManager.default.fileExists(atPath: url.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else {
                    NSWorkspace.shared.open(url.deletingLastPathComponent())
                }
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Показать файл в Finder")
        }
        .padding(.vertical, 9)
    }
}

/// Detail placeholder for a catalog section.
struct CatalogWelcomeView: View {
    let site: SiteCategory
    @Environment(CatalogStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            IconTile(symbol: site.symbol, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.isSearching ? "Результаты поиска" : site.title)
                    .font(.system(size: 34, weight: .regular))
                    .tracking(-0.6)
                Text(store.total.map { serversCount($0) + " в каталоге" } ?? "mcpservers.org")
                    .font(.system(size: 34, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.tertiary)
            }
            Text("Выберите сервер в списке: здесь появятся README, команды и конфиг, а сервер можно будет добавить в набор и поставить в клиент.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: 440, alignment: .leading)
            Link(destination: site.webURL) {
                HStack(spacing: 6) {
                    Text("Открыть на mcpservers.org").font(.system(size: 12.5, weight: .medium))
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .overlay { Capsule().strokeBorder(Theme.hairlineStrong) }
            }
            .buttonStyle(.plain)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.canvas)
    }
}

/// One recommended server on the home screen.
private struct PickCard: View {
    let template: ServerTemplate
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(symbol: template.symbol, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    Text(template.tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(template.comment)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Capsule().fill(Theme.lime).frame(width: 3)
                }
            Spacer(minLength: 0)
            HStack {
                TagPill(text: template.category.title)
                if template.pricing != .unknown { TagPill(text: template.pricing.shortTitle) }
                Spacer()
                PillButton(title: "Добавить", symbol: "plus", action: onAdd)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(RowBackground())
    }
}
