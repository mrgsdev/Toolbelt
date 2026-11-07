import SwiftUI
import SwiftData
import AppKit

@main
struct ToolbeltApp: App {
    let container: ModelContainer

    init() {
        do {
            let folder = Self.storeFolder
            Self.migrateLegacyStore(to: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(url: folder.appending(path: "Shelf.store"))
            container = try ModelContainer(for: MCPServer.self, configurations: configuration)
        } catch {
            fatalError("Не удалось открыть хранилище: \(error)")
        }
        Appearance.current.apply()
    }

    /// Moves the store from the app's previous name, if it is still there.
    private static func migrateLegacyStore(to folder: URL) {
        let legacy = URL.applicationSupportDirectory.appending(path: "MCPShelf", directoryHint: .isDirectory)
        let fm = FileManager.default
        guard ProcessInfo.processInfo.environment["TOOLBELT_STORE"] == nil,
              !fm.fileExists(atPath: folder.path), fm.fileExists(atPath: legacy.path) else { return }
        try? fm.moveItem(at: legacy, to: folder)
    }

    /// Where the set lives; `TOOLBELT_STORE` points it elsewhere for tests.
    static var storeFolder: URL {
        if let override = ProcessInfo.processInfo.environment["TOOLBELT_STORE"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return URL.applicationSupportDirectory.appending(path: "Toolbelt", directoryHint: .isDirectory)
    }

    var body: some Scene {
        WindowGroup("Toolbelt", id: "main") {
            RootView()
                .frame(minWidth: 1040, minHeight: 640)
        }
        .modelContainer(container)
        .defaultSize(width: 1380, height: 880)
        .windowToolbarStyle(.unified)
        .commands { AppCommands() }

        Window("Обновление Toolbelt", id: "update") {
            UpdateView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        // Opens by itself or from «Проверить обновления…».
        .commandsRemoved()

        Window("Горячие клавиши", id: "shortcuts") {
            ShortcutsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        // Opens from the Help menu.
        .commandsRemoved()

        Window("Отказ от ответственности и лицензии", id: "legal") {
            LegalView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        // Opens from the Help menu and Settings.
        .commandsRemoved()

        Settings {
            SettingsView()
                .modelContainer(container)
        }
    }
}

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .light

    private var router: Router { .shared }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("О программе Toolbelt") { AboutPanel.show() }
            Button("Проверить обновления…") { checkForUpdates() }
        }

        // No "New Window": a second window would share the first one's sidebar and catalog. The group
        // can't be empty either, or SwiftUI drops the whole File menu, and Close (⌘W) with it.
        CommandGroup(replacing: .newItem) {
            Button("Новый MCP-сервер") {
                showMainWindow()
                router.isAdding = true
            }
            .keyboardShortcut("n")
            Button("Главное окно") { showMainWindow() }
                .keyboardShortcut("0")
        }

        CommandGroup(after: .sidebar) {
            Button("Обновить") { refresh() }
                .keyboardShortcut("r")
            Divider()
            Picker("Оформление", selection: Binding(get: { appearance }, set: { Appearance.select($0) })) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
            }
            Button("Переключить светлую и тёмную") {
                let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                Appearance.select(isDark ? .light : .dark)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }

        CommandMenu("Разделы") {
            Button("Набор навыков") { open(.all) }.keyboardShortcut("1")
            Button("Избранное") { open(.favorites) }.keyboardShortcut("2")
            Button("Подключённые") { open(.installed) }.keyboardShortcut("3")
            Divider()
            Button("Каталог: Разработка") { open(.catalog(.development)) }.keyboardShortcut("4")
            Button("Каталог: Официальные") { open(.catalog(.official)) }.keyboardShortcut("5")
            Button("Весь каталог") { open(.catalog(.all)) }.keyboardShortcut("6")
            Divider()
            Button("Поиск") {
                showMainWindow()
                router.focusSearch()
            }
            .keyboardShortcut("f")
        }

        CommandMenu("Сервер") {
            Group {
                Button("Редактировать") { router.perform(.edit) }.keyboardShortcut("e")
                Button("В избранное или из него") { router.perform(.favorite) }.keyboardShortcut("d")
                Button("Установка в клиенты") { router.perform(.install) }.keyboardShortcut("i")
                Button("Скопировать конфиг") { router.perform(.copyConfig) }.keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Открыть сайт") { router.perform(.openSite) }.keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("Удалить из набора…") { router.perform(.delete) }.keyboardShortcut(.delete, modifiers: .command)
            }
            .disabled(!router.hasServerSelection)
        }

        // Instead of the system "Toolbelt Help", which only says there is none.
        CommandGroup(replacing: .help) {
            Button("Знакомство с Toolbelt") {
                showMainWindow()
                router.showsOnboarding = true
            }
            Button("Горячие клавиши") { openWindow(id: "shortcuts") }
                .keyboardShortcut("/")
            Divider()
            Button("Toolbelt на GitHub") { NSWorkspace.shared.open(AppLinks.repository) }
            Button("Сообщить о проблеме…") { NSWorkspace.shared.open(AppLinks.newIssue) }
            Divider()
            Button("Отказ от ответственности и лицензии") { openWindow(id: "legal") }
        }
    }
}

extension AppCommands {
    @MainActor
    private func open(_ item: SidebarItem) {
        showMainWindow()
        router.show(item)
    }

    @MainActor
    private func refresh() {
        Task {
            if router.catalogSection != nil { await CatalogStore.shared.reload() }
            await ClientRegistry.shared.refresh()
        }
    }

    @MainActor
    private func checkForUpdates() {
        openWindow(id: "update")
        Task { await Updater.shared.checkNow() }
    }

    /// Brings the main window forward, or opens it again after it was closed.
    @MainActor
    private func showMainWindow() {
        let window = NSApp.windows.first {
            $0.identifier?.rawValue.hasPrefix("main") == true && ($0.isVisible || $0.isMiniaturized)
        }
        guard let window else {
            openWindow(id: "main")
            return
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }
}

enum AppLinks {
    static let repository = URL(string: "https://github.com/mrgsdev/Toolbelt")!
    static let newIssue = URL(string: "https://github.com/mrgsdev/Toolbelt/issues/new")!
    static let developer = URL(string: "https://github.com/mrgsdev")!
    static let catalog = URL(string: "https://mcpservers.org/ru")!
}

enum AppInfo {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
}

enum AboutPanel {
    @MainActor
    static func show() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let credits = NSAttributedString(
            string: "Набор навыков для твоего агента: MCP-серверы, каталог и установка в один клик\nКаталог: mcpservers.org\nРазработчик: github.com/mrgsdev",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: style,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Toolbelt", .credits: credits])
        NSApp.activate()
    }
}
