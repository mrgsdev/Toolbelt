import SwiftUI
import SwiftData

/// Middle column: a live page of mcpservers.org.
struct CatalogListView: View {
    let site: SiteCategory
    @Binding var selection: String?

    @Environment(CatalogStore.self) private var store
    @Query private var servers: [MCPServer]
    @State private var isVerifying = false

    private var shelfPaths: Set<String> { Set(servers.map(\.catalogPath).filter { !$0.isEmpty }) }
    private var shelfNames: Set<String> { Set(servers.map { $0.name.lowercased() }) }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                header
                    .padding(.bottom, 8)

                if store.entries.isEmpty && (store.phase == .loading || store.phase == .idle) {
                    ForEach(0..<6, id: \.self) { _ in SkeletonRow() }
                }

                ForEach(store.entries) { entry in
                    Button {
                        selection = entry.id
                    } label: {
                        CatalogRow(entry: entry,
                                   isSelected: selection == entry.id,
                                   isOnShelf: shelfPaths.contains(entry.path) || shelfNames.contains(entry.name.lowercased()))
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Link(destination: entry.pageURL) {
                            Label("Открыть на mcpservers.org", systemImage: "safari")
                        }
                        if let url = entry.sourceURL {
                            Link(destination: url) {
                                Label("Открыть источник", systemImage: "arrow.up.right.square")
                            }
                        }
                    }
                    .onAppear {
                        if entry.id == store.entries.last?.id {
                            Task { await store.loadNext() }
                        }
                    }
                }

                footer
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .background(Theme.canvas)
        .navigationTitle(site.title)
        .task(id: site) {
            await store.show(.category(site))
        }
        .onChange(of: store.sort) { _, _ in
            selection = nil
            Task { await store.reload() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Сортировка", selection: $store.sort) {
                    ForEach(CatalogSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(store.isSearching)
                .help("Порядок как на сайте")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.reload() }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .help("Загрузить заново")
            }
        }
        .sheet(isPresented: $isVerifying) {
            VerificationSheet(url: site.webURL) {
                CatalogService.shared.invalidate()
                Task { await store.reload() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(headerTitle)
                .font(.system(size: 24, weight: .regular))
                .tracking(-0.4)
                .lineLimit(1)
            Text(headerSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var headerTitle: String {
        if case .search(let query)? = store.source { return "«\(query)»" }
        return site.title
    }

    private var headerSubtitle: String {
        let prefix = store.isSearching ? "Поиск по всему каталогу" : "mcpservers.org"
        guard let total = store.total else { return prefix }
        return "\(prefix) · \(serversCount(total))"
    }

    @ViewBuilder
    private var footer: some View {
        switch store.phase {
        case .loading where !store.entries.isEmpty:
            HStack {
                Spacer()
                ProgressView().controlSize(.small)
                Text("Загружаю ещё…").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                Spacer()
            }
            .padding(.vertical, 12)
        case .failed(let message):
            StatusCard(symbol: "wifi.exclamationmark",
                       title: "Не получилось загрузить", message: message,
                       actionTitle: "Повторить") {
                Task { await store.reload() }
            }
        case .needsVerification:
            StatusCard(symbol: "checkmark.shield",
                       title: "Нужна проверка браузера",
                       message: "mcpservers.org защищён Cloudflare. Откройте страницу, дождитесь загрузки или нажмите галочку, дальше всё заработает само.",
                       actionTitle: "Пройти проверку") {
                isVerifying = true
            }
        case .loaded where store.entries.isEmpty:
            ContentUnavailableView.search
                .padding(.top, 40)
        case .loaded where !store.hasMore:
            Text("Это всё: \(serversCount(store.entries.count))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        default:
            EmptyView()
        }
    }
}

private struct StatusCard: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Panel {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PillButton(title: actionTitle, style: .primary, action: action)
        }
    }
}

struct VerificationSheet: View {
    let url: URL
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Проверка mcpservers.org")
                        .font(.headline)
                    Text("Если появится галочка Cloudflare, нажмите её. Когда откроется каталог, нажмите «Готово».")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Готово") {
                    onDone()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.fill)
            }
            .padding(16)
            Divider()
            VerificationWebView(url: url)
        }
        .frame(width: 820, height: 620)
    }
}
