import SwiftUI
import SwiftData
import AppKit

/// A tour of the app, shown once at first launch and again from Help. Each step shows a live piece
/// of the interface built from the app's own components, with three numbered points below it.
struct OnboardingView: View {
    enum Step: Int, CaseIterable, Identifiable {
        case welcome, set, catalog, install, keys, author

        var id: Int { rawValue }

        var tab: String {
            switch self {
            case .welcome: "Привет"
            case .set: "Набор"
            case .catalog: "Каталог"
            case .install: "Установка"
            case .keys: "Клавиши"
            case .author: "От автора"
            }
        }

        var title: String {
            switch self {
            case .welcome: "Toolbelt"
            case .set: "Набор навыков"
            case .catalog: "Каталог mcpservers.org"
            case .install: "Установка в клиенты"
            case .keys: "Клавиши и тема"
            case .author: "Пара слов от разработчика"
            }
        }

        var subtitle: String {
            switch self {
            case .welcome: "Ручки для твоего агента: MCP-серверы, их конфиги и установка в клиенты в одном окне."
            case .set: "Серверы, которые вы уже используете или хотите попробовать."
            case .catalog: "Живой каталог прямо в окне: разделы, поиск, README и конфиги."
            case .install: "Конфиг сервера записывается в файл клиента без ручного копирования."
            case .keys: "Почти всё делается с клавиатуры, а тема подстраивается под вас."
            case .author: "Я сделал Toolbelt для себя: постоянно подключаю агентам новые MCP-серверы и устал искать конфиги по README. Буду рад, если приложение пригодится и вам."
            }
        }

        var points: [(title: String, text: String)] {
            switch self {
            case .welcome: [
                ("Набор навыков", "Серверы, конфиги, шаги установки, заметки и оценки в одном месте."),
                ("Каталог", "Тысячи серверов mcpservers.org с README и командами установки."),
                ("Один клик", "Claude Code, Claude Desktop, Cursor, VS Code, Codex и другие клиенты."),
            ]
            case .set: [
                ("Поиск ⌘F", "По названию, тегам, описанию и заметкам, совпадения подсвечиваются."),
                ("Карточка", "Обзор, установка и заметки. Примеры запросов копируются кликом."),
                ("Свой сервер ⌘N", "Иконка, конфиг с проверкой JSON, теги, оценка."),
            ]
            case .catalog: [
                ("Разделы ⌘4…⌘6", "«Разработка», «Официальные», весь каталог и 14 тем."),
                ("Поиск по каталогу", "Наберите запрос в разделе каталога и нажмите Enter."),
                ("В набор", "Описание, ссылки, команды и конфиг переносятся сами."),
            ]
            case .install: [
                ("Одна кнопка", "«Установить в …» ставит в выбранный клиент, стрелка рядом выбирает другой."),
                ("Копия файла", "Перед записью рядом с конфигом сохраняется *.toolbelt.bak."),
                ("Заглушки", "Если в конфиге остался <YOUR_ID>, Toolbelt предупредит заранее."),
            ]
            case .keys: [
                ("Разделы и меню", "⌘1…⌘6 открывают разделы, действия с сервером есть в меню «Сервер»."),
                ("Все сочетания", "⌘/ открывает справку, это знакомство живёт в меню «Справка»."),
                ("Обновления", "Новые версии Toolbelt проверяет на GitHub сам."),
            ]
            case .author: []
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var context
    @Query private var servers: [MCPServer]
    @AppStorage("onboardingSeen") private var isSeen = false
    @State private var step: Step = .welcome
    @State private var isForward = true
    @State private var addedPicks = false
    /// Not saved anywhere: sample rows for the «Набор» step.
    @State private var samples = DeveloperPicks.all.prefix(2).map { $0.makeServer() }

    private var isLast: Bool { step == Step.allCases.last }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PillTabs(values: Step.allCases, selection: Binding(get: { step }, set: { go(to: $0) })) { $0.tab }
                Spacer()
                if !isLast {
                    Button("Пропустить", action: finish)
                        .buttonStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.secondary)
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            ZStack {
                page(step)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .offset(x: isForward ? 36 : -36).combined(with: .opacity),
                        removal: .offset(x: isForward ? -36 : 36).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()

            footer
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
        }
        .frame(width: 920, height: 640)
        .background(Theme.canvas)
    }

    // MARK: Page

    private func page(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                if step == .welcome {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.system(size: 30, weight: .regular))
                        .tracking(-0.5)
                    if step != .author {
                        Text(step.subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            preview(step)
                .frame(maxWidth: .infinity, minHeight: 250, maxHeight: 250, alignment: .topLeading)
                .padding(16)
                .background(Theme.inset, in: .rect(cornerRadius: 20, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline) }
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(step == .keys || step == .author)

            if !step.points.isEmpty {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(Array(step.points.enumerated()), id: \.offset) { index, point in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.tertiary)
                            Text(point.title)
                                .font(.system(size: 13.5, weight: .semibold))
                            Text(point.text)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }

    @ViewBuilder
    private func preview(_ step: Step) -> some View {
        switch step {
        case .welcome:
            MetricRow {
                MetricCard(value: "8", title: "MCP-клиентов", note: "Claude Code, Cursor, VS Code…", dark: true)
                MetricCard(value: "4 500+", title: "Серверов в каталоге", note: "mcpservers.org")
                MetricCard(value: "1", title: "Клик до установки", note: "с копией конфига")
            }
            .frame(maxHeight: .infinity, alignment: .center)

        case .set:
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 8) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { index, server in
                        ServerRow(server: server, isSelected: index == 1)
                    }
                }
                .frame(width: 400)
                if let selected = samples.dropFirst().first {
                    Panel(title: selected.name) {
                        VStack(spacing: 6) {
                            InfoRow(label: "Категория") { Text(selected.category.title) }
                            InfoRow(label: "Цена") { Text(selected.pricing.title) }
                            InfoRow(label: "Статус") { LiveBadge(text: "подключён") }
                        }
                        HStack(spacing: 6) {
                            ForEach(selected.tags.prefix(3), id: \.self) { TagPill(text: $0) }
                        }
                    }
                }
            }

        case .catalog:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondary)
                    Text("github").font(.system(size: 13))
                    Spacer()
                    KeyCap(key: "↩")
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Theme.card, in: .capsule)
                .overlay { Capsule().strokeBorder(Theme.hairlineStrong) }
                .frame(width: 400)
                HStack(alignment: .top, spacing: 10) {
                    CatalogRow(entry: Self.sampleEntries[0], isSelected: true)
                    CatalogRow(entry: Self.sampleEntries[1], isOnShelf: true)
                }
            }

        case .install:
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 0) {
                        Label("Установить в Claude Code", systemImage: "arrow.down.to.line")
                            .font(.system(size: 12.5, weight: .medium))
                            .padding(.leading, 14)
                            .padding(.trailing, 10)
                        Rectangle().fill(Theme.onFill.opacity(0.2)).frame(width: 1, height: 16)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 28)
                    }
                    .frame(height: 30)
                    .foregroundStyle(Theme.onFill)
                    .background(Theme.fill, in: .capsule)
                    Text("Главная кнопка в карточке сервера")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.tertiary)
                }
                .frame(width: 240, alignment: .leading)
                Panel(title: "Клиенты") {
                    VStack(spacing: 0) {
                        sampleClient("Claude Code", symbol: "terminal", path: "~/.claude.json", installed: true)
                        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46)
                        sampleClient("Cursor", symbol: "cursorarrow", path: "~/.cursor/mcp.json", installed: false)
                        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46)
                        sampleClient("Codex", symbol: "curlybraces", path: "~/.codex/config.toml", installed: false)
                    }
                }
            }

        case .keys:
            HStack(alignment: .top, spacing: 16) {
                Panel(title: "Клавиши") {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                              alignment: .leading, spacing: 10) {
                        keyRow(["⌘", "1"], "Набор навыков")
                        keyRow(["⌘", "4"], "Каталог")
                        keyRow(["⌘", "F"], "Поиск")
                        keyRow(["⌘", "N"], "Новый сервер")
                        keyRow(["⌘", "I"], "Установка")
                        keyRow(["⌘", "/"], "Все сочетания")
                    }
                }
                Panel(title: "Тема") {
                    ThemeSwitcher()
                    Text("Светлая, тёмная или как в системе. Попробуйте прямо здесь или нажмите ⇧⌘L.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 300)
            }

        case .author:
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(step.subtitle)
                        .font(.system(size: 13.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 14)
                        .overlay(alignment: .leading) { Capsule().fill(Theme.lime).frame(width: 3) }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(LegalView.disclaimer.prefix(3), id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Rectangle().fill(Theme.ink).frame(width: 4, height: 4)
                                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                                Text(line)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    PillButton(title: "Отказ от ответственности и лицензии…", symbol: "info.circle") {
                        openWindow(id: "legal")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Panel(title: "Рекомендация разработчика") {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(DeveloperPicks.all) { TagPill(text: $0.name) }
                    }
                    let missing = DeveloperPicks.missing(from: servers)
                    if addedPicks || missing.isEmpty {
                        LiveBadge(text: "уже в вашем наборе")
                    } else {
                        PillButton(title: "Добавить все (\(missing.count))", symbol: "plus", style: .primary) {
                            DeveloperPicks.add(missing, to: context)
                            addedPicks = true
                        }
                    }
                    Text("Её можно добавить и позже на главной или скрыть в Настройках.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 330)
            }
        }
    }

    private func sampleClient(_ title: String, symbol: String, path: String, installed: Bool) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
            }
            Spacer()
            if installed {
                LiveBadge(text: "установлен")
            } else {
                PillButton(title: "Установить", symbol: "arrow.down.to.line", style: .primary) {}
            }
        }
        .padding(.vertical, 7)
    }

    private func keyRow(_ keys: [String], _ title: String) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) { ForEach(keys, id: \.self) { KeyCap(key: $0) } }
                .frame(width: 62, alignment: .leading)
            Text(title).font(.system(size: 12.5))
        }
    }

    private static let sampleEntries = [
        CatalogEntry(path: "/sample/github", name: "GitHub MCP", category: "Контроль версий",
                     summary: "Официальный MCP-сервер GitHub для поиска репозиториев, задач и pull request'ов.",
                     source: "", official: true, sponsored: false),
        CatalogEntry(path: "/sample/blender", name: "Blender MCP", category: "Дизайн",
                     summary: "Агент собирает 3D-сцены в Blender по текстовому запросу.",
                     source: "", official: false, sponsored: false),
    ]

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Text("Шаг \(step.rawValue + 1) из \(Step.allCases.count)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(Theme.fill)
                        .frame(width: geo.size.width * CGFloat(step.rawValue + 1) / CGFloat(Step.allCases.count))
                }
            }
            .frame(width: 180, height: 4)
            .animation(.snappy, value: step)
            Spacer()
            if step != .welcome {
                PillButton(title: "Назад") { go(to: Step(rawValue: step.rawValue - 1) ?? .welcome) }
            }
            PillButton(title: isLast ? "Начать" : "Далее", style: .primary) {
                if isLast { finish() } else { go(to: Step(rawValue: step.rawValue + 1) ?? step) }
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func go(to target: Step) {
        guard target != step else { return }
        isForward = target.rawValue > step.rawValue
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { step = target }
    }

    private func finish() {
        isSeen = true
        dismiss()
    }
}
