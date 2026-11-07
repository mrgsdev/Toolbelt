import SwiftUI
import SwiftData
import AppKit

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Query private var servers: [MCPServer]

    @Bindable private var router = Router.shared
    @State private var catalog = CatalogStore.shared
    @State private var registry = ClientRegistry.shared
    @FocusState private var isSearchFocused: Bool
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .light
    @AppStorage("onboardingSeen") private var onboardingSeen = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $router.sidebar)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } content: {
            content
                .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 560)
        } detail: {
            detail
        }
        .searchable(text: $router.searchText, placement: .toolbar, prompt: searchPrompt)
        .searchFocused($isSearchFocused)
        .onSubmit(of: .search) { submitSearch() }
        .onChange(of: router.searchRequests) { isSearchFocused = true }
        .onChange(of: router.searchText) { _, newValue in
            if newValue.trimmed.isEmpty, let site = router.catalogSection, catalog.isSearching {
                Task { await catalog.show(.category(site)) }
            }
        }
        .onChange(of: router.sidebar) { _, _ in
            router.selectedEntry = nil
        }
        .sheet(isPresented: $router.isAdding) {
            ServerEditorView(server: nil) { created in
                router.show(.all)
                router.selectedServer = created.id
            }
        }
        .background {
            Color.clear.sheet(isPresented: $router.showsOnboarding) {
                OnboardingView()
            }
        }
        .environment(catalog)
        .environment(registry)
        .task {
            await registry.refresh()
            if !onboardingSeen { router.showsOnboarding = true }
            await offerUpdate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await registry.refresh()
                await offerUpdate()
            }
        }
        .onChange(of: appearance) { _, value in value.apply() }
        .background {
            CatalogWebHost()
                .frame(width: 2, height: 2)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Columns

    @ViewBuilder
    private var content: some View {
        if let site = router.catalogSection {
            CatalogListView(site: site, selection: $router.selectedEntry)
        } else {
            ShelfListView(
                filter: router.sidebar ?? .all,
                query: router.searchText,
                selection: $router.selectedServer,
                onAdd: { router.isAdding = true },
                onDelete: delete
            )
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let site = router.catalogSection {
            if let entry = catalog.entry(id: router.selectedEntry) {
                CatalogDetailView(entry: entry, fallback: site, onOpen: open)
                    .id(entry.id)
            } else {
                CatalogWelcomeView(site: site)
            }
        } else if let id = router.selectedServer, let server = servers.first(where: { $0.id == id }) {
            ServerDetailView(server: server, onDelete: { delete(server) })
                .id(server.id)
        } else {
            DashboardView(
                onSelect: { router.selectedServer = $0.id },
                onSelectCategory: { router.show(.category($0)) },
                onOpenCatalog: { router.show(.catalog(.development)) },
                onAdd: { router.isAdding = true }
            )
        }
    }

    // MARK: Actions

    private var searchPrompt: String {
        router.catalogSection == nil ? "Поиск по набору" : "Поиск по mcpservers.org, Enter"
    }

    private func submitSearch() {
        let query = router.searchText.trimmed
        guard router.catalogSection != nil, !query.isEmpty else { return }
        router.selectedEntry = nil
        Task { await catalog.show(.search(query)) }
    }

    private func open(_ server: MCPServer) {
        router.show(.all)
        router.selectedServer = server.id
    }

    private func delete(_ server: MCPServer) {
        if router.selectedServer == server.id { router.selectedServer = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.snappy) { context.delete(server) }
            try? context.save()
        }
    }

    /// Looks for a new release at launch and then at most twice a day; the window opens only when there is one.
    private func offerUpdate() async {
        if await Updater.shared.checkInBackground() {
            openWindow(id: "update")
        }
    }
}

@MainActor
enum PreviewStore {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: MCPServer.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        DeveloperPicks.all.forEach { container.mainContext.insert($0.makeServer()) }
        return container
    }()
}

#Preview {
    RootView()
        .modelContainer(PreviewStore.container)
        .frame(width: 1300, height: 820)
}
