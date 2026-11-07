import SwiftUI
import SwiftData

/// Detail column for a mcpservers.org entry: description, install info, README and import.
struct CatalogDetailView: View {
    enum Tab: String, CaseIterable {
        case overview, install, readme

        var title: String {
            switch self {
            case .overview: "Обзор"
            case .install: "Установка"
            case .readme: "README"
            }
        }
    }

    let entry: CatalogEntry
    let fallback: SiteCategory
    var onOpen: (MCPServer) -> Void

    @Environment(CatalogStore.self) private var store
    @Environment(ClientRegistry.self) private var registry
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query private var servers: [MCPServer]

    @State private var tab: Tab = .overview
    @State private var detail: CatalogDetail?
    @State private var loadError: String?
    @State private var showFullReadme = false
    @State private var installer = InstallController()

    private var existing: MCPServer? {
        servers.first { $0.catalogPath == entry.path }
            ?? servers.first { $0.name.lowercased() == entry.name.lowercased() }
    }

    var body: some View {
        @Bindable var installer = installer
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                PillTabs(values: Tab.allCases, selection: $tab) { $0.title }
                switch tab {
                case .overview: overview
                case .install: installTab
                case .readme: readmeTab
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 22)
            .padding(.bottom, 40)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .task { await loadDetail() }
        .toast($installer.toast)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: entry.pageURL) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                }
            }
        }
        .modifier(PlaceholderAlert(server: existing, installer: installer, registry: registry) {
            if let existing { onOpen(existing) }
        })
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                CatalogLogo(entry: entry, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.name)
                            .font(.system(size: 28, weight: .regular))
                            .tracking(-0.4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if entry.official {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 15))
                                .help("Официальный сервер")
                        }
                    }
                    Text(CatalogImporter.tagline(from: entry.summary))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if let existing {
                    PillButton(title: "Открыть в наборе", symbol: "tray.full", style: .primary) { onOpen(existing) }
                } else {
                    PillButton(title: "Добавить в набор", symbol: "plus", style: .primary) { addToShelf() }
                }
                PillButton(title: "mcpservers.org", symbol: "arrow.up.right") { openURL(entry.pageURL) }
                PillButton(title: "GitHub", symbol: "arrow.up.right") {
                    if let url = detail?.githubURL ?? entry.sourceURL { openURL(url) }
                }
                .disabled(detail?.githubURL == nil && entry.sourceURL == nil)
                if let config = detail?.config {
                    PillButton(title: "Конфиг", symbol: "doc.on.doc") {
                        Clipboard.copy(config)
                        installer.toast = ToastMessage(text: "Конфиг скопирован")
                    }
                }
            }
        }
    }

    // MARK: Tabs

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            MetricRow {
                MetricCard(value: detail?.stars ?? "0", title: "Звёзды на GitHub",
                           note: detail == nil ? "загружаю…" : (detail?.stars == nil ? "нет данных" : nil), dark: true)
                MetricCard(value: "\(detail?.commands.count ?? 0)", title: "Команды установки",
                           note: detail?.config == nil ? "конфиг не найден" : "есть готовый конфиг")
                MetricCard(value: "\(detail?.blocks?.count ?? 0)", title: "Блоков в README", note: nil)
            }
            HStack(alignment: .top, spacing: 16) {
                Panel(title: "Информация") {
                    VStack(spacing: 6) {
                        InfoRow(label: "Категория") { Text(entry.category.isEmpty ? "не указана" : entry.category) }
                        InfoRow(label: "Категория в наборе") { Text((entry.siteCategory ?? fallback).mapped.title) }
                        InfoRow(label: "Официальный") { Text(entry.official ? "да" : "нет") }
                        if let url = detail?.githubURL {
                            InfoRow(label: "GitHub") {
                                Link(url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/")), destination: url)
                            }
                        }
                        if let url = detail?.websiteURL {
                            InfoRow(label: "Сайт") { Link(url.host() ?? url.absoluteString, destination: url) }
                        }
                        InfoRow(label: "Статус") {
                            if existing != nil { LiveBadge(text: "в наборе") } else { Text("в каталоге") }
                        }
                    }
                    .tint(Theme.ink)
                }
                .frame(width: 330)

                Panel(title: "Описание") {
                    Text(entry.summary.isEmpty ? "Описание не указано." : entry.summary)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let loadError {
                errorPanel(loadError)
            }
        }
    }

    private var installTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let existing {
                ClientsPanel(server: existing, installer: installer)
            } else {
                Panel(title: "Клиенты") {
                    HStack(spacing: 12) {
                        Text("Добавьте сервер в набор, и его можно будет поставить в любой клиент одной кнопкой.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        PillButton(title: "Добавить в набор", symbol: "plus", style: .primary) { addToShelf() }
                    }
                }
            }

            if let detail {
                if !detail.commands.isEmpty {
                    Panel(title: "Команды из README") {
                        VStack(spacing: 6) {
                            ForEach(detail.commands, id: \.self) { command in
                                CommandRow(command: command) {
                                    Clipboard.copy(command)
                                    installer.toast = ToastMessage(text: "Команда скопирована")
                                }
                            }
                        }
                    }
                }
                Panel(title: "Конфиг", trailing: detail.config == nil ? nil : "из README") {
                    if let config = detail.config {
                        CodeBlock(code: config) {
                            Clipboard.copy(config)
                            installer.toast = ToastMessage(text: "Конфиг скопирован")
                        }
                    } else {
                        Text("Готового блока mcpServers в README нет. После добавления в набор его можно вписать в редакторе.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Найдено на mcpservers.org. Перед запуском сверьте с первоисточником.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
            } else if let loadError {
                errorPanel(loadError)
            } else {
                loadingPanel
            }
        }
    }

    @ViewBuilder
    private var readmeTab: some View {
        if let blocks = detail?.blocks, !blocks.isEmpty {
            let visible = showFullReadme ? blocks : Array(blocks.prefix(18))
            Panel(title: "README", trailing: "\(blocks.count) блоков") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, block in
                        ReadmeBlockView(block: block)
                    }
                }
                .textSelection(.enabled)
                if blocks.count > 18 {
                    PillButton(title: showFullReadme ? "Свернуть" : "Показать полностью") {
                        withAnimation(.snappy) { showFullReadme.toggle() }
                    }
                }
            }
        } else if detail != nil {
            Panel(title: "README") {
                Text("У этого сервера нет README на mcpservers.org.").foregroundStyle(Theme.secondary)
            }
        } else if let loadError {
            errorPanel(loadError)
        } else {
            loadingPanel
        }
    }

    private var loadingPanel: some View {
        Panel {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Загружаю страницу сервера…").foregroundStyle(Theme.secondary)
            }
        }
    }

    private func errorPanel(_ message: String) -> some View {
        Panel(title: "Не получилось загрузить") {
            Text(message).foregroundStyle(Theme.secondary)
            PillButton(title: "Повторить", symbol: "arrow.clockwise") { Task { await loadDetail() } }
        }
    }

    // MARK: Actions

    private func loadDetail() async {
        loadError = nil
        do {
            detail = try await store.detail(for: entry)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func addToShelf() {
        let server = CatalogImporter.makeServer(entry: entry, detail: detail, fallback: fallback)
        context.insert(server)
        try? context.save()
        installer.toast = ToastMessage(text: "«\(entry.name)» в наборе", symbol: "plus")
    }
}

// MARK: - Pieces

private struct CommandRow: View {
    let command: String
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("$")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.tertiary)
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondary)
            .help("Скопировать")
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Theme.inset, in: .rect(cornerRadius: 10, style: .continuous))
    }
}

private struct ReadmeBlockView: View {
    let block: CatalogDetail.Block

    var body: some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 6)
        case .text:
            Text(block.text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        case .item:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 4, height: 4)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                Text(block.text)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .code:
            ScrollView(.horizontal, showsIndicators: false) {
                Text(JSONHighlighter.highlight(block.text))
                    .font(.system(size: 12, design: .monospaced))
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.codeBackground, in: .rect(cornerRadius: 10, style: .continuous))
        }
    }
}
