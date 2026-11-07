import SwiftUI
import SwiftData

struct ServerDetailView: View {
    enum Tab: String, CaseIterable {
        case overview, install, notes

        var title: String {
            switch self {
            case .overview: "Обзор"
            case .install: "Установка"
            case .notes: "Заметки"
            }
        }
    }

    @Bindable var server: MCPServer
    var onDelete: () -> Void

    @Environment(ClientRegistry.self) private var registry
    @Environment(\.openURL) private var openURL
    @State private var tab: Tab = .overview
    @State private var installer = InstallController()
    @State private var isEditing = false
    @State private var confirmDelete = false
    private let router = Router.shared

    private var installedIn: [MCPClient] {
        registry.clients(containing: ConfigInstaller.serverNames(for: server))
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
                case .notes: notesTab
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 22)
            .padding(.bottom, 40)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .toolbar { toolbarContent }
        .sheet(isPresented: $isEditing) {
            ServerEditorView(server: server)
        }
        .confirmationDialog("Удалить «\(server.name)»?", isPresented: $confirmDelete) {
            Button("Удалить", role: .destructive, action: onDelete)
        } message: {
            Text("Сервер пропадёт из набора вместе с заметками. Конфиги клиентов не меняются.")
        }
        .modifier(PlaceholderAlert(server: server, installer: installer, registry: registry) { isEditing = true })
        .toast($installer.toast)
        .onChange(of: router.serverRequest) { _, request in
            if let request { perform(request.action) }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                IconTile(symbol: server.symbol, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.system(size: 28, weight: .regular))
                        .tracking(-0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(server.tagline)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                InstallButton(server: server, installer: installer)
                PillButton(title: "Сайт", symbol: "arrow.up.right") {
                    if let url = server.primaryURL { openURL(url) }
                }
                .disabled(server.primaryURL == nil)
                PillButton(title: "Конфиг", symbol: "doc.on.doc") {
                    Clipboard.copy(server.configJSON)
                    installer.toast = ToastMessage(text: "Конфиг скопирован")
                }
                .disabled(server.configJSON.isEmpty)
                PillButton(title: server.isFavorite ? "В избранном" : "В избранное",
                           symbol: server.isFavorite ? "star.fill" : "star") {
                    withAnimation(.snappy) { server.isFavorite.toggle() }
                }
            }
        }
    }

    // MARK: Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            MetricRow {
                MetricCard(value: "\(installedIn.count)",
                           title: "В клиентах",
                           note: installedIn.isEmpty ? "пока нигде" : installedIn.map(\.title).joined(separator: ", "),
                           dark: true)
                MetricCard(value: "\(server.rating)/5", title: "Моя оценка",
                           note: server.rating > 0 ? nil : "оцени во вкладке «Заметки»")
                MetricCard(value: "\(server.capabilities.count)", title: "Возможности",
                           note: server.capabilities.isEmpty ? "не описаны" : nil)
                MetricCard(value: server.createdAt.formatted(.dateTime.day().locale(Locale(identifier: "ru_RU"))),
                           title: "В наборе с",
                           note: server.createdAt.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "ru_RU"))))
            }

            HStack(alignment: .top, spacing: 16) {
                Panel(title: "Общая информация") {
                    VStack(spacing: 6) {
                        InfoRow(label: "Категория") { Text(server.category.title) }
                        InfoRow(label: "Цена") { Text(server.pricing.title) }
                        InfoRow(label: "Статус") {
                            if server.isInstalled { LiveBadge(text: "подключён") } else { Text("не подключён") }
                        }
                        InfoRow(label: "Источник") { Text(server.catalogPath.isEmpty ? "добавлен вручную" : "mcpservers.org") }
                        if let url = server.website {
                            InfoRow(label: "Сайт") { Link(url.host() ?? url.absoluteString, destination: url) }
                        }
                        if let url = server.repo {
                            InfoRow(label: "Репозиторий") { Link(repoLabel(url), destination: url) }
                        }
                        if let url = server.catalogURL {
                            InfoRow(label: "Каталог") { Link("mcpservers.org", destination: url) }
                        }
                    }
                    .tint(Theme.ink)
                }
                .frame(width: 330)

                Panel(title: "Описание") {
                    Text(server.summary.isEmpty ? "Описания пока нет, его можно добавить в редакторе." : server.summary)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .foregroundStyle(server.summary.isEmpty ? Theme.secondary : Theme.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if !server.pricingNote.isEmpty {
                        Text(server.pricingNote)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.inset, in: .rect(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if !server.capabilities.isEmpty {
                Panel(title: "Возможности", trailing: "\(server.capabilities.count)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16, alignment: .topLeading)],
                              alignment: .leading, spacing: 10) {
                        ForEach(Array(server.capabilities.enumerated()), id: \.offset) { _, item in
                            CapabilityRow(text: item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            if !server.examplePrompts.isEmpty {
                Panel(title: "Примеры запросов", trailing: "клик копирует запрос") {
                    VStack(spacing: 6) {
                        ForEach(Array(server.examplePrompts.enumerated()), id: \.offset) { _, prompt in
                            PromptRow(prompt: prompt) {
                                Clipboard.copy(prompt)
                                installer.toast = ToastMessage(text: "Запрос скопирован")
                            }
                        }
                    }
                }
            }

            if !server.tags.isEmpty {
                Panel(title: "Теги") {
                    FlowLayout {
                        ForEach(server.tags, id: \.self) { TagPill(text: $0) }
                    }
                }
            }
        }
    }

    // MARK: Install

    private var installTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            ClientsPanel(server: server, installer: installer)

            if !server.setupSteps.isEmpty {
                Panel(title: "Перед установкой") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(server.setupSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .frame(width: 22, height: 22)
                                    .overlay { Circle().strokeBorder(Theme.hairlineStrong) }
                                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                                Text(TextStyler.markdown(step))
                                    .font(.system(size: 13))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            Panel(title: "Конфиг", trailing: server.configJSON.isEmpty ? nil : "mcpServers") {
                if server.configJSON.isEmpty {
                    HStack {
                        Text("Конфига нет.").foregroundStyle(Theme.secondary)
                        PillButton(title: "Добавить в редакторе", symbol: "pencil") { isEditing = true }
                    }
                } else {
                    CodeBlock(code: server.configJSON) {
                        Clipboard.copy(server.configJSON)
                        installer.toast = ToastMessage(text: "Конфиг скопирован")
                    }
                }
            }
        }
    }

    // MARK: Notes

    private var notesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel(title: "Оценка") {
                RatingView(rating: $server.rating, size: 18)
            }
            Panel(title: "Мои заметки") {
                TextField("Как используешь, что настроил, какие грабли…", text: $server.notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .lineLimit(6...30)
            }
            Text("В наборе с \(server.createdAt.formatted(russianDate))")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Редактировать", systemImage: "pencil") { isEditing = true }
                .help("Редактировать (⌘E)")
        }
        ToolbarItem(placement: .primaryAction) {
            ShareLink(item: server.shareText) {
                Label("Поделиться", systemImage: "square.and.arrow.up")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Удалить", systemImage: "trash", role: .destructive) { confirmDelete = true }
                .help("Удалить из набора")
        }
    }

    /// «Сервер» menu: the same actions as the buttons on this screen.
    private func perform(_ action: ServerAction) {
        switch action {
        case .edit:
            isEditing = true
        case .favorite:
            withAnimation(.snappy) { server.isFavorite.toggle() }
            installer.toast = ToastMessage(text: server.isFavorite ? "В избранном" : "Убран из избранного",
                                           symbol: server.isFavorite ? "star.fill" : "star")
        case .install:
            tab = .install
        case .copyConfig:
            guard !server.configJSON.isEmpty else { return }
            Clipboard.copy(server.configJSON)
            installer.toast = ToastMessage(text: "Конфиг скопирован")
        case .openSite:
            if let url = server.primaryURL { openURL(url) }
        case .delete:
            confirmDelete = true
        }
    }

    private func repoLabel(_ url: URL) -> String {
        let path = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? (url.host() ?? url.absoluteString) : path
    }
}

// MARK: - Rows

private struct CapabilityRow: View {
    let text: String

    /// «tool: описание» (or the older «tool — описание») → name and description; plain text stays whole.
    static func split(_ text: String) -> [String] {
        for separator in [": ", " — "] {
            if let range = text.range(of: separator) {
                let name = String(text[..<range.lowerBound])
                if !name.contains(" ") { return [name, String(text[range.upperBound...])] }
            }
        }
        return [text]
    }

    var body: some View {
        let parts = CapabilityRow.split(text)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 5, height: 5)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            if parts.count > 1 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(parts[0])
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    Text(parts[1])
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
            } else {
                Text(text).font(.system(size: 13))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PromptRow: View {
    let prompt: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Text(prompt)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(isHovering ? Theme.ink : Theme.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovering ? Theme.inset : Theme.canvas.opacity(0.5),
                        in: .rect(cornerRadius: 10, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
