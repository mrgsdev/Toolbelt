import SwiftUI
import SwiftData

struct ServerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let server: MCPServer?
    private let onCreate: ((MCPServer) -> Void)?
    @State private var draft: ServerDraft

    init(server: MCPServer?, onCreate: ((MCPServer) -> Void)? = nil) {
        self.server = server
        self.onCreate = onCreate
        _draft = State(initialValue: ServerDraft(server: server))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    EditorPreview(draft: draft)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("Основное") {
                    TextField("Название", text: $draft.name)
                    TextField("Коротко: что делает", text: $draft.tagline, axis: .vertical)
                        .lineLimit(1...3)
                    Picker("Категория", selection: $draft.category) {
                        ForEach(MCPCategory.allCases) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                    Picker("Цена", selection: $draft.pricing) {
                        ForEach(Pricing.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    TextField("Детали тарифа (необязательно)", text: $draft.pricingNote, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Иконка") {
                    SymbolPicker(selection: $draft.symbol)
                }

                Section("Описание") {
                    TextField("Что умеет, зачем нужен, для каких задач", text: $draft.summary, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("Ссылки") {
                    urlField("Сайт или документация", text: $draft.websiteURL)
                    urlField("Репозиторий", text: $draft.repoURL)
                }

                Section {
                    TextField("Каждый шаг с новой строки. `код` в обратных кавычках", text: $draft.setupSteps, axis: .vertical)
                        .lineLimit(3...10)
                } header: {
                    Text("Шаги установки")
                }

                Section {
                    TextField(#"{ "mcpServers": { … } }"#, text: $draft.configJSON, axis: .vertical)
                        .font(.system(.callout, design: .monospaced))
                        .autocorrectionDisabled()
                        .lineLimit(4...16)
                    HStack {
                        PasteButton(payloadType: String.self) { strings in
                            Task { @MainActor in
                                draft.configJSON = strings.first ?? draft.configJSON
                            }
                        }
                        .labelStyle(.titleAndIcon)
                        Spacer()
                        if let status = draft.jsonStatus {
                            Label(status.title, systemImage: status.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(status.color)
                        }
                    }
                } header: {
                    Text("Конфиг")
                } footer: {
                    Text("JSON-блок для секции mcpServers: его можно скопировать или поставить в клиент одной кнопкой.")
                }

                Section {
                    TextField("По одной на строку. «tool: описание» выделит имя", text: $draft.capabilities, axis: .vertical)
                        .lineLimit(3...10)
                } header: {
                    Text("Возможности")
                }

                Section("Примеры запросов") {
                    TextField("По одному на строку", text: $draft.examplePrompts, axis: .vertical)
                        .lineLimit(2...8)
                }

                Section {
                    TextField("поиск, код, open source", text: $draft.tags)
                } header: {
                    Text("Теги")
                } footer: {
                    Text("Через запятую. Теги участвуют в поиске.")
                }

                Section("Статус") {
                    Toggle("В избранном", isOn: $draft.isFavorite)
                    Toggle("Подключён у меня", isOn: $draft.isInstalled)
                    HStack {
                        Text("Оценка")
                        Spacer()
                        RatingView(rating: $draft.rating, size: 13)
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: draft.category) { old, new in
                if draft.symbol == old.symbol { draft.symbol = new.symbol }
            }

            Divider()

            HStack {
                Text(server == nil ? "Новый MCP-сервер" : "Редактирование")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Сохранить") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.fill)
                    .disabled(!draft.isValid)
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: 640, height: 760)
    }

    private func urlField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .autocorrectionDisabled()
    }

    private func save() {
        if let server {
            draft.apply(to: server)
        } else {
            let created = MCPServer(name: draft.name.trimmed)
            draft.apply(to: created)
            context.insert(created)
            try? context.save()
            onCreate?(created)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Draft

struct ServerDraft {
    var name = ""
    var tagline = ""
    var summary = ""
    var symbol = MCPCategory.development.symbol
    var category: MCPCategory = .development
    var pricing: Pricing = .free
    var pricingNote = ""
    var websiteURL = ""
    var repoURL = ""
    var configJSON = ""
    var setupSteps = ""
    var capabilities = ""
    var examplePrompts = ""
    var tags = ""
    var isFavorite = false
    var isInstalled = false
    var rating = 0

    init(server: MCPServer?) {
        guard let server else { return }
        name = server.name
        tagline = server.tagline
        summary = server.summary
        symbol = server.symbol
        category = server.category
        pricing = server.pricing
        pricingNote = server.pricingNote
        websiteURL = server.websiteURL
        repoURL = server.repoURL
        configJSON = server.configJSON
        setupSteps = server.setupSteps.joined(separator: "\n")
        capabilities = server.capabilities.joined(separator: "\n")
        examplePrompts = server.examplePrompts.joined(separator: "\n")
        tags = server.tags.joined(separator: ", ")
        isFavorite = server.isFavorite
        isInstalled = server.isInstalled
        rating = server.rating
    }

    var isValid: Bool { !name.trimmed.isEmpty }

    var jsonStatus: (title: String, symbol: String, color: Color)? {
        let trimmed = configJSON.trimmed
        guard !trimmed.isEmpty else { return nil }
        if let data = trimmed.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return ("JSON валиден", "checkmark.circle", Theme.ink)
        }
        return ("Не похоже на JSON", "exclamationmark.triangle", Theme.danger)
    }

    func apply(to server: MCPServer) {
        server.name = name.trimmed
        server.tagline = tagline.trimmed
        server.summary = summary.trimmed
        server.symbol = symbol
        server.category = category
        server.pricing = pricing
        server.pricingNote = pricingNote.trimmed
        server.websiteURL = websiteURL.trimmed
        server.repoURL = repoURL.trimmed
        server.configJSON = configJSON.trimmed
        server.setupSteps = setupSteps.nonEmptyLines
        server.capabilities = capabilities.nonEmptyLines
        server.examplePrompts = examplePrompts.nonEmptyLines
        server.tags = tags.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
        server.isFavorite = isFavorite
        server.isInstalled = isInstalled
        server.rating = rating
    }
}

// MARK: - Editor pieces

private struct EditorPreview: View {
    let draft: ServerDraft

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: draft.symbol, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(draft.name.trimmed.isEmpty ? "Название" : draft.name)
                    .font(.system(size: 20, weight: .regular))
                    .tracking(-0.3)
                    .foregroundStyle(draft.name.trimmed.isEmpty ? Theme.tertiary : Theme.ink)
                    .lineLimit(1)
                Text(draft.tagline.trimmed.isEmpty ? "Короткое описание появится здесь" : draft.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(draft.category.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondary)
        }
        .padding(16)
    }
}

private struct SymbolPicker: View {
    @Binding var selection: String

    static let symbols = [
        "cube.transparent.fill", "checklist", "cursorarrow.click.2", "curlybraces.square.fill",
        "text.magnifyingglass", "point.3.connected.trianglepath.dotted", "square.grid.2x2.fill",
        "chevron.left.forwardslash.chevron.right", "puzzlepiece.extension.fill", "server.rack",
        "terminal.fill", "globe", "paintbrush.pointed.fill", "photo.fill", "doc.text.fill",
        "folder.fill", "cylinder.split.1x2.fill", "bubble.left.and.bubble.right.fill",
        "envelope.fill", "calendar", "chart.bar.xaxis", "brain.head.profile", "wand.and.stars",
        "bolt.fill", "lock.fill", "network", "cpu.fill", "music.note", "film.fill", "map.fill",
        "cart.fill", "hammer.fill"
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 8)], spacing: 8) {
            ForEach(Self.symbols, id: \.self) { symbol in
                let isSelected = selection == symbol
                Button {
                    withAnimation(.snappy(duration: 0.15)) { selection = symbol }
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? Theme.onFill : Theme.ink)
                        .frame(width: 38, height: 38)
                        .background(isSelected ? Theme.fill : Theme.inset,
                                    in: .rect(cornerRadius: 10, style: .continuous))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}
